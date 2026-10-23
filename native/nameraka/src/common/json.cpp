#include "common/json.hpp"

#include <cmath>
#include <cstdio>

namespace nk {

namespace {

const Json kNull;
const std::string kEmpty;
const Json::Array kEmptyArray;
const Json::Object kEmptyObject;

struct Parser {
    std::string_view s;
    size_t i = 0;
    int depth = 0;

    void ws() {
        while (i < s.size() && (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r'))
            ++i;
    }
    bool lit(std::string_view w) {
        if (s.substr(i, w.size()) != w)
            return false;
        i += w.size();
        return true;
    }
    static void utf8(std::string& out, unsigned cp) {
        if (cp < 0x80) {
            out += static_cast<char>(cp);
        } else if (cp < 0x800) {
            out += static_cast<char>(0xC0 | (cp >> 6));
            out += static_cast<char>(0x80 | (cp & 0x3F));
        } else if (cp < 0x10000) {
            out += static_cast<char>(0xE0 | (cp >> 12));
            out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
            out += static_cast<char>(0x80 | (cp & 0x3F));
        } else {
            out += static_cast<char>(0xF0 | (cp >> 18));
            out += static_cast<char>(0x80 | ((cp >> 12) & 0x3F));
            out += static_cast<char>(0x80 | ((cp >> 6) & 0x3F));
            out += static_cast<char>(0x80 | (cp & 0x3F));
        }
    }
    bool hex4(unsigned& cp) {
        if (i + 4 > s.size())
            return false;
        cp = 0;
        for (int k = 0; k < 4; ++k) {
            char c = s[i++];
            cp <<= 4;
            if (c >= '0' && c <= '9') cp |= static_cast<unsigned>(c - '0');
            else if (c >= 'a' && c <= 'f') cp |= static_cast<unsigned>(c - 'a' + 10);
            else if (c >= 'A' && c <= 'F') cp |= static_cast<unsigned>(c - 'A' + 10);
            else return false;
        }
        return true;
    }
    std::optional<std::string> string() {
        if (i >= s.size() || s[i] != '"')
            return std::nullopt;
        ++i;
        std::string out;
        while (i < s.size()) {
            char c = s[i++];
            if (c == '"')
                return out;
            if (c != '\\') {
                out += c;
                continue;
            }
            if (i >= s.size())
                return std::nullopt;
            char e = s[i++];
            switch (e) {
            case '"': out += '"'; break;
            case '\\': out += '\\'; break;
            case '/': out += '/'; break;
            case 'b': out += '\b'; break;
            case 'f': out += '\f'; break;
            case 'n': out += '\n'; break;
            case 'r': out += '\r'; break;
            case 't': out += '\t'; break;
            case 'u': {
                unsigned cp;
                if (!hex4(cp))
                    return std::nullopt;
                if (cp >= 0xD800 && cp < 0xDC00 && lit("\\u")) {
                    unsigned lo;
                    if (!hex4(lo))
                        return std::nullopt;
                    cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                }
                utf8(out, cp);
                break;
            }
            default: return std::nullopt;
            }
        }
        return std::nullopt;
    }
    std::optional<Json> value() {
        if (++depth > 64)
            return std::nullopt;
        ws();
        if (i >= s.size())
            return std::nullopt;
        std::optional<Json> r;
        char c = s[i];
        if (c == '{') {
            ++i;
            Json::Object o;
            ws();
            if (i < s.size() && s[i] == '}') {
                ++i;
                r = Json(std::move(o));
            } else {
                while (true) {
                    ws();
                    auto k = string();
                    if (!k) return std::nullopt;
                    ws();
                    if (i >= s.size() || s[i++] != ':') return std::nullopt;
                    auto v = value();
                    if (!v) return std::nullopt;
                    o.insert_or_assign(std::move(*k), std::move(*v));
                    ws();
                    if (i < s.size() && s[i] == ',') { ++i; continue; }
                    if (i < s.size() && s[i] == '}') { ++i; break; }
                    return std::nullopt;
                }
                r = Json(std::move(o));
            }
        } else if (c == '[') {
            ++i;
            Json::Array a;
            ws();
            if (i < s.size() && s[i] == ']') {
                ++i;
            } else {
                while (true) {
                    auto v = value();
                    if (!v) return std::nullopt;
                    a.push_back(std::move(*v));
                    ws();
                    if (i < s.size() && s[i] == ',') { ++i; continue; }
                    if (i < s.size() && s[i] == ']') { ++i; break; }
                    return std::nullopt;
                }
            }
            r = Json(std::move(a));
        } else if (c == '"') {
            auto str = string();
            if (!str) return std::nullopt;
            r = Json(std::move(*str));
        } else if (lit("true")) {
            r = Json(true);
        } else if (lit("false")) {
            r = Json(false);
        } else if (lit("null")) {
            r = Json(nullptr);
        } else {
            size_t start = i;
            if (i < s.size() && (s[i] == '-' || s[i] == '+')) ++i;
            while (i < s.size() && ((s[i] >= '0' && s[i] <= '9') || s[i] == '.' || s[i] == 'e' || s[i] == 'E' || s[i] == '-' || s[i] == '+'))
                ++i;
            if (start == i) return std::nullopt;
            std::string num(s.substr(start, i - start));
            char* end = nullptr;
            double d = std::strtod(num.c_str(), &end);
            if (end != num.c_str() + num.size()) return std::nullopt;
            r = Json(d);
        }
        --depth;
        return r;
    }
};

void escape(std::string& out, const std::string& s) {
    out += '"';
    for (unsigned char c : s) {
        switch (c) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n"; break;
        case '\r': out += "\\r"; break;
        case '\t': out += "\\t"; break;
        default:
            if (c < 0x20) {
                char buf[8];
                std::snprintf(buf, sizeof buf, "\\u%04x", c);
                out += buf;
            } else {
                out += static_cast<char>(c);
            }
        }
    }
    out += '"';
}

void dumpTo(std::string& out, const Json& j) {
    if (j.isNull()) {
        out += "null";
    } else if (j.isBool()) {
        out += j.asBool() ? "true" : "false";
    } else if (j.isNumber()) {
        double d = j.asNumber();
        if (!std::isfinite(d)) {
            out += "null";
        } else if (d == std::floor(d) && std::fabs(d) < 1e15) {
            out += std::to_string(static_cast<long long>(d));
        } else {
            char buf[32];
            std::snprintf(buf, sizeof buf, "%.4g", d);
            out += buf;
        }
    } else if (j.isString()) {
        escape(out, j.asString());
    } else if (j.isArray()) {
        out += '[';
        bool first = true;
        for (const auto& v : j.array()) {
            if (!first) out += ',';
            first = false;
            dumpTo(out, v);
        }
        out += ']';
    } else {
        out += '{';
        bool first = true;
        for (const auto& [k, v] : j.object()) {
            if (!first) out += ',';
            first = false;
            escape(out, k);
            out += ':';
            dumpTo(out, v);
        }
        out += '}';
    }
}

} // namespace

std::optional<Json> Json::parse(std::string_view text) {
    Parser p{text};
    auto v = p.value();
    if (!v)
        return std::nullopt;
    p.ws();
    if (p.i != text.size())
        return std::nullopt;
    return v;
}

std::string Json::dump() const {
    std::string out;
    dumpTo(out, *this);
    return out;
}

const std::string& Json::asString() const {
    return isString() ? std::get<std::string>(v_) : kEmpty;
}
const Json::Array& Json::array() const {
    return isArray() ? *std::get<std::shared_ptr<Array>>(v_) : kEmptyArray;
}
const Json::Object& Json::object() const {
    return isObject() ? *std::get<std::shared_ptr<Object>>(v_) : kEmptyObject;
}
const Json& Json::operator[](std::string_view key) const {
    if (!isObject())
        return kNull;
    const auto& o = object();
    auto it = o.find(key);
    return it == o.end() ? kNull : it->second;
}
bool Json::has(std::string_view key) const {
    return isObject() && object().find(key) != object().end();
}
Json& Json::set(std::string key, Json value) {
    if (!isObject())
        v_ = std::make_shared<Object>();
    else if (std::get<std::shared_ptr<Object>>(v_).use_count() > 1)
        v_ = std::make_shared<Object>(object());     // copy on write
    std::get<std::shared_ptr<Object>>(v_)->insert_or_assign(std::move(key), std::move(value));
    return *this;
}

} // namespace nk
