// Vulkan side of the presenter (docs/01-ARQUITECTURA §19): a FIFO swapchain on the overlay surface; each captured
// DMA-BUF is imported once (VK_EXT_external_memory_dma_buf + VK_EXT_image_drm_format_modifier, explicit modifier) and
// copied 1:1 into the next swapchain image (never scaled: a half pixel left over is cropped). lsfg-vk, an implicit
// layer, hooks vkQueuePresentKHR of this process and inserts the generated frames.
#pragma once

#include <cstdint>
#include <vector>
#include <vulkan/vulkan.h>

struct wl_display;
struct wl_surface;

namespace nk {

struct Imported {
    VkImage image = VK_NULL_HANDLE;
    VkDeviceMemory memory = VK_NULL_HANDLE;
    int w = 0, h = 0;
};

class Vk {
public:
    bool init(wl_display* display);
    void shutdown();
    bool createSwapchain(wl_surface* surface, int w, int h);
    void destroySwapchain();
    bool hasSwapchain() const { return swapchain_ != VK_NULL_HANDLE; }

    // modifiers usable for a single-plane B8G8R8A8 DMA-BUF that we can copy from
    std::vector<uint64_t> modifiers() const;
    // import one DMA-BUF (fd is dup'ed); false if the driver refuses it
    bool import(int fd, uint32_t offset, uint32_t stride, uint64_t modifier, int w, int h, Imported& out);
    void release(Imported& img);

    enum class Result { Ok, Recreate, Error };
    // copy src (top-left aligned, cropped to the swapchain) and present
    Result presentImage(const Imported& src);
    // 滑 test pattern: 1-px stripes (scaling check) + a grid that scrolls t pixels
    Result presentPattern(int t);
    double lastGpuMs() const { return lastGpuMs_; }

private:
    bool pickDevice();
    bool makePattern();
    Result frame(const Imported* src, int scroll);
    uint32_t memoryType(uint32_t bits, VkMemoryPropertyFlags flags) const;

    VkInstance instance_ = VK_NULL_HANDLE;
    VkPhysicalDevice phys_ = VK_NULL_HANDLE;
    VkDevice device_ = VK_NULL_HANDLE;
    uint32_t family_ = 0;
    VkQueue queue_ = VK_NULL_HANDLE;
    wl_display* display_ = nullptr;
    VkSurfaceKHR surface_ = VK_NULL_HANDLE;
    VkSwapchainKHR swapchain_ = VK_NULL_HANDLE;
    VkFormat format_ = VK_FORMAT_B8G8R8A8_UNORM;
    VkExtent2D extent_{};
    std::vector<VkImage> images_;
    std::vector<VkSemaphore> released_;        // one per swapchain image: render done → present
    VkCommandPool pool_ = VK_NULL_HANDLE;
    static constexpr int kFrames = 3;
    VkCommandBuffer cmd_[kFrames]{};
    VkFence fences_[kFrames]{};
    VkSemaphore acquired_[kFrames]{};
    int frameIdx_ = 0;
    PFN_vkGetMemoryFdPropertiesKHR getMemoryFdProperties_ = nullptr;
    Imported pattern_;
    VkDeviceMemory patternMem_ = VK_NULL_HANDLE;
    double lastGpuMs_ = 0;
};

} // namespace nk
