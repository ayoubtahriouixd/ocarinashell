#include "view/vk.hpp"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <unistd.h>
#include <vulkan/vulkan_wayland.h>

namespace nk {

#define VKR(expr)                                                                          \
    do {                                                                                   \
        VkResult r_ = (expr);                                                              \
        if (r_ != VK_SUCCESS) {                                                            \
            std::fprintf(stderr, "nameraka view: %s → %d (%s:%d)\n", #expr, r_, __FILE__, __LINE__); \
            return false;                                                                  \
        }                                                                                  \
    } while (0)

namespace {
const char* kDeviceExts[] = {
    VK_KHR_SWAPCHAIN_EXTENSION_NAME,          VK_KHR_EXTERNAL_MEMORY_FD_EXTENSION_NAME,
    VK_EXT_EXTERNAL_MEMORY_DMA_BUF_EXTENSION_NAME, VK_EXT_IMAGE_DRM_FORMAT_MODIFIER_EXTENSION_NAME,
    VK_EXT_QUEUE_FAMILY_FOREIGN_EXTENSION_NAME,
};

void barrier(VkCommandBuffer cb, VkImage img, VkImageLayout from, VkImageLayout to, VkAccessFlags srcA,
             VkAccessFlags dstA, VkPipelineStageFlags srcS, VkPipelineStageFlags dstS,
             uint32_t srcFam = VK_QUEUE_FAMILY_IGNORED, uint32_t dstFam = VK_QUEUE_FAMILY_IGNORED) {
    VkImageMemoryBarrier b{VK_STRUCTURE_TYPE_IMAGE_MEMORY_BARRIER};
    b.srcAccessMask = srcA;
    b.dstAccessMask = dstA;
    b.oldLayout = from;
    b.newLayout = to;
    b.srcQueueFamilyIndex = srcFam;
    b.dstQueueFamilyIndex = dstFam;
    b.image = img;
    b.subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
    vkCmdPipelineBarrier(cb, srcS, dstS, 0, 0, nullptr, 0, nullptr, 1, &b);
}
} // namespace

bool Vk::init(wl_display* display) {
    display_ = display;
    VkApplicationInfo app{VK_STRUCTURE_TYPE_APPLICATION_INFO};
    app.pApplicationName = "nameraka";
    app.apiVersion = VK_API_VERSION_1_3;
    const char* exts[] = {VK_KHR_SURFACE_EXTENSION_NAME, VK_KHR_WAYLAND_SURFACE_EXTENSION_NAME};
    VkInstanceCreateInfo ci{VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO};
    ci.pApplicationInfo = &app;
    ci.enabledExtensionCount = 2;
    ci.ppEnabledExtensionNames = exts;
    VKR(vkCreateInstance(&ci, nullptr, &instance_));
    if (!pickDevice())
        return false;
    float prio = 1.0f;
    VkDeviceQueueCreateInfo q{VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO};
    q.queueFamilyIndex = family_;
    q.queueCount = 1;
    q.pQueuePriorities = &prio;
    VkDeviceCreateInfo dci{VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO};
    dci.queueCreateInfoCount = 1;
    dci.pQueueCreateInfos = &q;
    dci.enabledExtensionCount = sizeof kDeviceExts / sizeof *kDeviceExts;
    dci.ppEnabledExtensionNames = kDeviceExts;
    VKR(vkCreateDevice(phys_, &dci, nullptr, &device_));
    vkGetDeviceQueue(device_, family_, 0, &queue_);
    getMemoryFdProperties_ =
        reinterpret_cast<PFN_vkGetMemoryFdPropertiesKHR>(vkGetDeviceProcAddr(device_, "vkGetMemoryFdPropertiesKHR"));
    VkCommandPoolCreateInfo pci{VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO};
    pci.flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT;
    pci.queueFamilyIndex = family_;
    VKR(vkCreateCommandPool(device_, &pci, nullptr, &pool_));
    VkCommandBufferAllocateInfo ai{VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO};
    ai.commandPool = pool_;
    ai.level = VK_COMMAND_BUFFER_LEVEL_PRIMARY;
    ai.commandBufferCount = kFrames;
    VKR(vkAllocateCommandBuffers(device_, &ai, cmd_));
    for (int i = 0; i < kFrames; ++i) {
        VkFenceCreateInfo f{VK_STRUCTURE_TYPE_FENCE_CREATE_INFO};
        f.flags = VK_FENCE_CREATE_SIGNALED_BIT;
        VKR(vkCreateFence(device_, &f, nullptr, &fences_[i]));
        VkSemaphoreCreateInfo s{VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO};
        VKR(vkCreateSemaphore(device_, &s, nullptr, &acquired_[i]));
    }
    return true;
}

bool Vk::pickDevice() {
    uint32_t n = 0;
    vkEnumeratePhysicalDevices(instance_, &n, nullptr);
    std::vector<VkPhysicalDevice> devs(n);
    vkEnumeratePhysicalDevices(instance_, &n, devs.data());
    for (auto d : devs) {
        uint32_t ne = 0;
        vkEnumerateDeviceExtensionProperties(d, nullptr, &ne, nullptr);
        std::vector<VkExtensionProperties> ext(ne);
        vkEnumerateDeviceExtensionProperties(d, nullptr, &ne, ext.data());
        bool all = true;
        for (const char* want : kDeviceExts)
            all = all && std::any_of(ext.begin(), ext.end(), [&](auto& e) { return !std::strcmp(e.extensionName, want); });
        if (!all)
            continue;
        uint32_t nq = 0;
        vkGetPhysicalDeviceQueueFamilyProperties(d, &nq, nullptr);
        std::vector<VkQueueFamilyProperties> qs(nq);
        vkGetPhysicalDeviceQueueFamilyProperties(d, &nq, qs.data());
        for (uint32_t i = 0; i < nq; ++i) {
            if ((qs[i].queueFlags & VK_QUEUE_GRAPHICS_BIT)
                && vkGetPhysicalDeviceWaylandPresentationSupportKHR(d, i, display_)) {
                phys_ = d;
                family_ = i;
                VkPhysicalDeviceProperties p;
                vkGetPhysicalDeviceProperties(d, &p);
                std::fprintf(stderr, "nameraka view: GPU %s\n", p.deviceName);
                return true;
            }
        }
    }
    std::fprintf(stderr, "nameraka view: ninguna GPU con DMA-BUF + modificadores + Wayland\n");
    return false;
}

uint32_t Vk::memoryType(uint32_t bits, VkMemoryPropertyFlags flags) const {
    VkPhysicalDeviceMemoryProperties mp;
    vkGetPhysicalDeviceMemoryProperties(phys_, &mp);
    for (uint32_t i = 0; i < mp.memoryTypeCount; ++i)
        if ((bits & (1u << i)) && (mp.memoryTypes[i].propertyFlags & flags) == flags)
            return i;
    for (uint32_t i = 0; i < mp.memoryTypeCount; ++i)
        if (bits & (1u << i))
            return i;
    return 0;
}

bool Vk::createSwapchain(wl_surface* surface, int w, int h) {
    VkWaylandSurfaceCreateInfoKHR sci{VK_STRUCTURE_TYPE_WAYLAND_SURFACE_CREATE_INFO_KHR};
    sci.display = display_;
    sci.surface = surface;
    VKR(vkCreateWaylandSurfaceKHR(instance_, &sci, nullptr, &surface_));
    VkBool32 ok = VK_FALSE;
    vkGetPhysicalDeviceSurfaceSupportKHR(phys_, family_, surface_, &ok);
    if (!ok) {
        std::fprintf(stderr, "nameraka view: la cola no puede presentar en la superficie\n");
        return false;
    }
    VkSurfaceCapabilitiesKHR caps;
    VKR(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(phys_, surface_, &caps));
    uint32_t nf = 0;
    vkGetPhysicalDeviceSurfaceFormatsKHR(phys_, surface_, &nf, nullptr);
    std::vector<VkSurfaceFormatKHR> fmts(nf);
    vkGetPhysicalDeviceSurfaceFormatsKHR(phys_, surface_, &nf, fmts.data());
    VkSurfaceFormatKHR fmt = fmts.empty() ? VkSurfaceFormatKHR{VK_FORMAT_B8G8R8A8_UNORM, VK_COLOR_SPACE_SRGB_NONLINEAR_KHR}
                                          : fmts[0];
    for (auto& f : fmts)
        if (f.format == VK_FORMAT_B8G8R8A8_UNORM) {
            fmt = f;
            break;
        }
    format_ = fmt.format;
    extent_ = {static_cast<uint32_t>(w), static_cast<uint32_t>(h)};
    VkSwapchainCreateInfoKHR ci{VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR};
    ci.surface = surface_;
    ci.minImageCount = std::max(caps.minImageCount, 3u);
    if (caps.maxImageCount)
        ci.minImageCount = std::min(ci.minImageCount, caps.maxImageCount);
    ci.imageFormat = fmt.format;
    ci.imageColorSpace = fmt.colorSpace;
    ci.imageExtent = extent_;
    ci.imageArrayLayers = 1;
    ci.imageUsage = VK_IMAGE_USAGE_TRANSFER_DST_BIT | VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT;
    ci.imageSharingMode = VK_SHARING_MODE_EXCLUSIVE;
    ci.preTransform = VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR;
    // NOT opaque: with an opaque buffer niri treats the window below as occluded and throttles its frame callbacks
    // to ~1 Hz — Chrome then stops painting the video we capture (measured: 4 fps instead of 30). With an alpha
    // format and no opaque region the window keeps being "visible". niri's window casts carry alpha 255; even a
    // pixel that did not would only show the real window under it, which displays the same video.
    if (caps.supportedCompositeAlpha & VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR)
        ci.compositeAlpha = VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR;
    else if (caps.supportedCompositeAlpha & VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR)
        ci.compositeAlpha = VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR;
    else
        ci.compositeAlpha = VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR;
    ci.presentMode = VK_PRESENT_MODE_FIFO_KHR;
    ci.clipped = VK_TRUE;
    VKR(vkCreateSwapchainKHR(device_, &ci, nullptr, &swapchain_));
    uint32_t ni = 0;
    vkGetSwapchainImagesKHR(device_, swapchain_, &ni, nullptr);
    images_.resize(ni);
    vkGetSwapchainImagesKHR(device_, swapchain_, &ni, images_.data());
    released_.resize(ni);
    for (auto& s : released_) {
        VkSemaphoreCreateInfo sc{VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO};
        VKR(vkCreateSemaphore(device_, &sc, nullptr, &s));
    }
    std::fprintf(stderr, "nameraka view: swapchain %ux%u, %u imágenes, FIFO\n", extent_.width, extent_.height, ni);
    return true;
}

void Vk::destroySwapchain() {
    if (!device_)
        return;
    vkDeviceWaitIdle(device_);
    for (auto s : released_)
        vkDestroySemaphore(device_, s, nullptr);
    released_.clear();
    images_.clear();
    if (swapchain_)
        vkDestroySwapchainKHR(device_, swapchain_, nullptr);
    if (surface_)
        vkDestroySurfaceKHR(instance_, surface_, nullptr);
    swapchain_ = VK_NULL_HANDLE;
    surface_ = VK_NULL_HANDLE;
}

std::vector<uint64_t> Vk::modifiers() const {
    VkDrmFormatModifierPropertiesListEXT list{VK_STRUCTURE_TYPE_DRM_FORMAT_MODIFIER_PROPERTIES_LIST_EXT};
    VkFormatProperties2 fp{VK_STRUCTURE_TYPE_FORMAT_PROPERTIES_2};
    fp.pNext = &list;
    vkGetPhysicalDeviceFormatProperties2(phys_, VK_FORMAT_B8G8R8A8_UNORM, &fp);
    std::vector<VkDrmFormatModifierPropertiesEXT> props(list.drmFormatModifierCount);
    list.pDrmFormatModifierProperties = props.data();
    vkGetPhysicalDeviceFormatProperties2(phys_, VK_FORMAT_B8G8R8A8_UNORM, &fp);
    std::vector<uint64_t> out;
    for (auto& p : props)
        if (p.drmFormatModifierPlaneCount == 1 && (p.drmFormatModifierTilingFeatures & VK_FORMAT_FEATURE_TRANSFER_SRC_BIT))
            out.push_back(p.drmFormatModifier);
    return out;
}

bool Vk::import(int fd, uint32_t offset, uint32_t stride, uint64_t modifier, int w, int h, Imported& out) {
    VkSubresourceLayout plane{};
    plane.offset = offset;
    plane.rowPitch = stride;
    VkImageDrmFormatModifierExplicitCreateInfoEXT mod{VK_STRUCTURE_TYPE_IMAGE_DRM_FORMAT_MODIFIER_EXPLICIT_CREATE_INFO_EXT};
    mod.drmFormatModifier = modifier;
    mod.drmFormatModifierPlaneCount = 1;
    mod.pPlaneLayouts = &plane;
    VkExternalMemoryImageCreateInfo ext{VK_STRUCTURE_TYPE_EXTERNAL_MEMORY_IMAGE_CREATE_INFO};
    ext.pNext = &mod;
    ext.handleTypes = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT;
    VkImageCreateInfo ci{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
    ci.pNext = &ext;
    ci.imageType = VK_IMAGE_TYPE_2D;
    ci.format = VK_FORMAT_B8G8R8A8_UNORM;
    ci.extent = {static_cast<uint32_t>(w), static_cast<uint32_t>(h), 1};
    ci.mipLevels = 1;
    ci.arrayLayers = 1;
    ci.samples = VK_SAMPLE_COUNT_1_BIT;
    ci.tiling = VK_IMAGE_TILING_DRM_FORMAT_MODIFIER_EXT;
    ci.usage = VK_IMAGE_USAGE_TRANSFER_SRC_BIT;
    ci.sharingMode = VK_SHARING_MODE_EXCLUSIVE;
    ci.initialLayout = VK_IMAGE_LAYOUT_UNDEFINED;
    VKR(vkCreateImage(device_, &ci, nullptr, &out.image));
    VkMemoryFdPropertiesKHR fdp{VK_STRUCTURE_TYPE_MEMORY_FD_PROPERTIES_KHR};
    if (getMemoryFdProperties_)
        getMemoryFdProperties_(device_, VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT, fd, &fdp);
    VkMemoryRequirements req;
    vkGetImageMemoryRequirements(device_, out.image, &req);
    int dupFd = ::dup(fd);
    if (dupFd < 0) {
        vkDestroyImage(device_, out.image, nullptr);
        out.image = VK_NULL_HANDLE;
        return false;
    }
    VkMemoryDedicatedAllocateInfo ded{VK_STRUCTURE_TYPE_MEMORY_DEDICATED_ALLOCATE_INFO};
    ded.image = out.image;
    VkImportMemoryFdInfoKHR imp{VK_STRUCTURE_TYPE_IMPORT_MEMORY_FD_INFO_KHR};
    imp.pNext = &ded;
    imp.handleType = VK_EXTERNAL_MEMORY_HANDLE_TYPE_DMA_BUF_BIT_EXT;
    imp.fd = dupFd;
    VkMemoryAllocateInfo ai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    ai.pNext = &imp;
    ai.allocationSize = req.size;
    ai.memoryTypeIndex = memoryType(req.memoryTypeBits & (fdp.memoryTypeBits ? fdp.memoryTypeBits : ~0u), 0);
    VkResult r = vkAllocateMemory(device_, &ai, nullptr, &out.memory);
    if (r != VK_SUCCESS) {
        ::close(dupFd);                      // ownership passes to Vulkan only on success
        vkDestroyImage(device_, out.image, nullptr);
        out.image = VK_NULL_HANDLE;
        std::fprintf(stderr, "nameraka view: importar DMA-BUF → %d\n", r);
        return false;
    }
    VKR(vkBindImageMemory(device_, out.image, out.memory, 0));
    out.w = w;
    out.h = h;
    return true;
}

void Vk::release(Imported& img) {
    if (!device_)
        return;
    if (img.image)
        vkDestroyImage(device_, img.image, nullptr);
    if (img.memory)
        vkFreeMemory(device_, img.memory, nullptr);
    img = {};
}

bool Vk::makePattern() {
    const int w = static_cast<int>(extent_.width), h = static_cast<int>(extent_.height);
    VkImageCreateInfo ci{VK_STRUCTURE_TYPE_IMAGE_CREATE_INFO};
    ci.imageType = VK_IMAGE_TYPE_2D;
    ci.format = VK_FORMAT_B8G8R8A8_UNORM;
    ci.extent = {static_cast<uint32_t>(w), static_cast<uint32_t>(h), 1};
    ci.mipLevels = 1;
    ci.arrayLayers = 1;
    ci.samples = VK_SAMPLE_COUNT_1_BIT;
    ci.tiling = VK_IMAGE_TILING_OPTIMAL;
    ci.usage = VK_IMAGE_USAGE_TRANSFER_SRC_BIT | VK_IMAGE_USAGE_TRANSFER_DST_BIT;
    VKR(vkCreateImage(device_, &ci, nullptr, &pattern_.image));
    VkMemoryRequirements req;
    vkGetImageMemoryRequirements(device_, pattern_.image, &req);
    VkMemoryAllocateInfo ai{VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO};
    ai.allocationSize = req.size;
    ai.memoryTypeIndex = memoryType(req.memoryTypeBits, VK_MEMORY_PROPERTY_DEVICE_LOCAL_BIT);
    VKR(vkAllocateMemory(device_, &ai, nullptr, &patternMem_));
    VKR(vkBindImageMemory(device_, pattern_.image, patternMem_, 0));
    pattern_.memory = VK_NULL_HANDLE;   // owned through patternMem_
    pattern_.w = w;
    pattern_.h = h;
    // staging buffer, B G R A bytes
    VkBufferCreateInfo bci{VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO};
    bci.size = static_cast<VkDeviceSize>(w) * h * 4;
    bci.usage = VK_BUFFER_USAGE_TRANSFER_SRC_BIT;
    VkBuffer buf;
    VKR(vkCreateBuffer(device_, &bci, nullptr, &buf));
    vkGetBufferMemoryRequirements(device_, buf, &req);
    ai.allocationSize = req.size;
    ai.memoryTypeIndex = memoryType(req.memoryTypeBits, VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT);
    VkDeviceMemory bm;
    VKR(vkAllocateMemory(device_, &ai, nullptr, &bm));
    VKR(vkBindBufferMemory(device_, buf, bm, 0));
    uint8_t* p = nullptr;
    VKR(vkMapMemory(device_, bm, 0, bci.size, 0, reinterpret_cast<void**>(&p)));
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            uint8_t* px = p + (static_cast<size_t>(y) * w + x) * 4;
            uint8_t r, g, b;
            if (x < 240 && y < 240) {                 // 1-px black/white columns: any rescale shows as grey/moiré
                r = g = b = (x & 1) ? 255 : 0;
            } else if (x >= w - 240 && y < 240) {     // 1-px rows
                r = g = b = (y & 1) ? 255 : 0;
            } else if (x % 120 == 0 || y % 120 == 0) { // grid every 120 px (scrolls)
                r = 230; g = 0; b = 51;                // 紅
            } else {
                r = static_cast<uint8_t>(20 + 40 * x / w);
                g = static_cast<uint8_t>(16 + 30 * y / h);
                b = 28;
            }
            px[0] = b; px[1] = g; px[2] = r; px[3] = 255;
        }
    vkUnmapMemory(device_, bm);
    VkCommandBuffer cb = cmd_[0];
    vkWaitForFences(device_, 1, &fences_[0], VK_TRUE, UINT64_MAX);
    VkCommandBufferBeginInfo bi{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    bi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(cb, &bi);
    barrier(cb, pattern_.image, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 0,
            VK_ACCESS_TRANSFER_WRITE_BIT, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT);
    VkBufferImageCopy region{};
    region.imageSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
    region.imageExtent = {static_cast<uint32_t>(w), static_cast<uint32_t>(h), 1};
    vkCmdCopyBufferToImage(cb, buf, pattern_.image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &region);
    barrier(cb, pattern_.image, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL,
            VK_ACCESS_TRANSFER_WRITE_BIT, VK_ACCESS_TRANSFER_READ_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT,
            VK_PIPELINE_STAGE_TRANSFER_BIT);
    vkEndCommandBuffer(cb);
    vkResetFences(device_, 1, &fences_[0]);
    VkSubmitInfo si{VK_STRUCTURE_TYPE_SUBMIT_INFO};
    si.commandBufferCount = 1;
    si.pCommandBuffers = &cb;
    VKR(vkQueueSubmit(queue_, 1, &si, fences_[0]));
    vkWaitForFences(device_, 1, &fences_[0], VK_TRUE, UINT64_MAX);
    vkDestroyBuffer(device_, buf, nullptr);
    vkFreeMemory(device_, bm, nullptr);
    return true;
}

Vk::Result Vk::presentImage(const Imported& src) { return frame(&src, 0); }

Vk::Result Vk::presentPattern(int t) {
    if (!pattern_.image && !makePattern())
        return Result::Error;
    return frame(nullptr, t);
}

Vk::Result Vk::frame(const Imported* src, int scroll) {
    if (!swapchain_)
        return Result::Recreate;
    const int f = frameIdx_;
    frameIdx_ = (frameIdx_ + 1) % kFrames;
    vkWaitForFences(device_, 1, &fences_[f], VK_TRUE, UINT64_MAX);
    uint32_t idx = 0;
    VkResult r = vkAcquireNextImageKHR(device_, swapchain_, 1000000000ull, acquired_[f], VK_NULL_HANDLE, &idx);
    if (r == VK_ERROR_OUT_OF_DATE_KHR)
        return Result::Recreate;
    if (r != VK_SUCCESS && r != VK_SUBOPTIMAL_KHR) {
        std::fprintf(stderr, "nameraka view: acquire → %d\n", r);
        return r == VK_TIMEOUT ? Result::Recreate : Result::Error;
    }
    auto t0 = std::chrono::steady_clock::now();
    VkCommandBuffer cb = cmd_[f];
    vkResetCommandBuffer(cb, 0);
    VkCommandBufferBeginInfo bi{VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
    bi.flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT;
    vkBeginCommandBuffer(cb, &bi);
    VkImage dst = images_[idx];
    barrier(cb, dst, VK_IMAGE_LAYOUT_UNDEFINED, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 0, VK_ACCESS_TRANSFER_WRITE_BIT,
            VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT);
    const int W = static_cast<int>(extent_.width), H = static_cast<int>(extent_.height);
    if (src) {
        // acquire the buffer from niri (foreign queue); it was rendered and fenced before it was queued
        barrier(cb, src->image, VK_IMAGE_LAYOUT_GENERAL, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, 0,
                VK_ACCESS_TRANSFER_READ_BIT, VK_PIPELINE_STAGE_TOP_OF_PIPE_BIT, VK_PIPELINE_STAGE_TRANSFER_BIT,
                VK_QUEUE_FAMILY_FOREIGN_EXT, family_);
        VkImageCopy c{};
        c.srcSubresource = c.dstSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
        c.extent = {static_cast<uint32_t>(std::min(W, src->w)), static_cast<uint32_t>(std::min(H, src->h)), 1};
        if (src->w < W || src->h < H) {     // not covering the whole output: black around it
            VkClearColorValue black{};
            VkImageSubresourceRange rr{VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1};
            vkCmdClearColorImage(cb, dst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, &black, 1, &rr);
        }
        vkCmdCopyImage(cb, src->image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, dst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &c);
        barrier(cb, src->image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, VK_IMAGE_LAYOUT_GENERAL,
                VK_ACCESS_TRANSFER_READ_BIT, 0, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT,
                family_, VK_QUEUE_FAMILY_FOREIGN_EXT);
    } else {
        // the pattern scrolled horizontally, wrapped in two copies; the stripe blocks (≤ 240 px) stay where they are
        int s = ((scroll % W) + W) % W;
        VkImageCopy c[2]{};
        for (auto& x : c)
            x.srcSubresource = x.dstSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
        c[0].srcOffset = {0, 240, 0};
        c[0].dstOffset = {s, 240, 0};
        c[0].extent = {static_cast<uint32_t>(W - s), static_cast<uint32_t>(H - 240), 1};
        c[1].srcOffset = {W - s, 240, 0};
        c[1].dstOffset = {0, 240, 0};
        c[1].extent = {static_cast<uint32_t>(s), static_cast<uint32_t>(H - 240), 1};
        VkImageCopy top{};
        top.srcSubresource = top.dstSubresource = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 0, 1};
        top.extent = {static_cast<uint32_t>(W), 240, 1};
        vkCmdCopyImage(cb, pattern_.image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, dst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, 1, &top);
        vkCmdCopyImage(cb, pattern_.image, VK_IMAGE_LAYOUT_TRANSFER_SRC_OPTIMAL, dst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL,
                       s > 0 ? 2 : 1, c);
    }
    barrier(cb, dst, VK_IMAGE_LAYOUT_TRANSFER_DST_OPTIMAL, VK_IMAGE_LAYOUT_PRESENT_SRC_KHR, VK_ACCESS_TRANSFER_WRITE_BIT,
            0, VK_PIPELINE_STAGE_TRANSFER_BIT, VK_PIPELINE_STAGE_BOTTOM_OF_PIPE_BIT);
    vkEndCommandBuffer(cb);
    vkResetFences(device_, 1, &fences_[f]);
    VkPipelineStageFlags wait = VK_PIPELINE_STAGE_TRANSFER_BIT;
    VkSubmitInfo si{VK_STRUCTURE_TYPE_SUBMIT_INFO};
    si.waitSemaphoreCount = 1;
    si.pWaitSemaphores = &acquired_[f];
    si.pWaitDstStageMask = &wait;
    si.commandBufferCount = 1;
    si.pCommandBuffers = &cb;
    si.signalSemaphoreCount = 1;
    si.pSignalSemaphores = &released_[idx];
    if (vkQueueSubmit(queue_, 1, &si, fences_[f]) != VK_SUCCESS)
        return Result::Error;
    VkPresentInfoKHR pi{VK_STRUCTURE_TYPE_PRESENT_INFO_KHR};
    pi.waitSemaphoreCount = 1;
    pi.pWaitSemaphores = &released_[idx];
    pi.swapchainCount = 1;
    pi.pSwapchains = &swapchain_;
    pi.pImageIndices = &idx;
    r = vkQueuePresentKHR(queue_, &pi);
    // the source buffer goes back to niri only once our copy has finished
    if (src)
        vkWaitForFences(device_, 1, &fences_[f], VK_TRUE, UINT64_MAX);
    lastGpuMs_ = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - t0).count();
    if (r == VK_ERROR_OUT_OF_DATE_KHR || r == VK_SUBOPTIMAL_KHR)
        return Result::Recreate;
    return r == VK_SUCCESS ? Result::Ok : Result::Error;
}

void Vk::shutdown() {
    if (!device_)
        return;
    vkDeviceWaitIdle(device_);
    if (pattern_.image)
        vkDestroyImage(device_, pattern_.image, nullptr);
    if (patternMem_)
        vkFreeMemory(device_, patternMem_, nullptr);
    pattern_ = {};
    patternMem_ = VK_NULL_HANDLE;
    destroySwapchain();
    for (int i = 0; i < kFrames; ++i) {
        vkDestroyFence(device_, fences_[i], nullptr);
        vkDestroySemaphore(device_, acquired_[i], nullptr);
    }
    vkDestroyCommandPool(device_, pool_, nullptr);
    vkDestroyDevice(device_, nullptr);
    vkDestroyInstance(instance_, nullptr);
    device_ = VK_NULL_HANDLE;
    instance_ = VK_NULL_HANDLE;
}

} // namespace nk
