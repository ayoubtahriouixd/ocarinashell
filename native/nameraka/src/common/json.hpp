// Minimal JSON value, parser and writer for the control protocol (one object per line) and niri's IPC event stream.
// Numbers are doubles; objects keep insertion order irrelevant (std::map). No exceptions escape parse(): it returns
// std::nullopt on malformed input.
#pragma once

#include <map>
#include <memory>
#include <optional>
#include <string>
#include <string_view>
#include <variant>
#include <vector>

namespace nk {

class Json {
public:
    using Array = std::vector<Json>;
    using Object = std::map<std::string, Json, std::less<>>;

    Json() = default;
    Json(std::nullptr_t) {}
    Json(bool b) : v_(b) {}
    Json(double d) : v_(d) {}
    Json(int i) : v_(static_cast<double>(i)) {}
    Json(long i) : v_(static_cast<double>(i)) {}
    Json(long long i) : v_(static_cast<double>(i)) {}
    Json(unsigned i) : v_(static_cast<double>(i)) {}
    Json(unsigned long i) : v_(static_cast<double>(i)) {}
    Json(unsigned long long i) : v_(static_cast<double>(i)) {}
    Json(const char* s) : v_(std::string(s)) {}
    Json(std::string s) : v_(std::move(s)) {}
    Json(std::string_view s) : v_(std::string(s)) {}
    Json(Array a) : v_(std::make_shared<Array>(std::move(a))) {}
    Json(Object o) : v_(std::make_shared<Object>(std::move(o))) {}

    static std::optional<Json> parse(std::string_view text);
    std::string dump() const;

    bool isNull() const { return std::holds_alternative<std::monostate>(v_); }
    bool isBool() const { return std::holds_alternative<bool>(v_); }
    bool isNumber() const { return std::holds_alternative<double>(v_); }
    bool isString() const { return std::holds_alternative<std::string>(v_); }
    bool isArray() const { return std::holds_alternative<std::shared_ptr<Array>>(v_); }
    bool isObject() const { return std::holds_alternative<std::shared_ptr<Object>>(v_); }

    bool asBool(bool def = false) const { return isBool() ? std::get<bool>(v_) : def; }
    double asNumber(double def = 0) const { return isNumber() ? std::get<double>(v_) : def; }
    long long asInt(long long def = 0) const { return isNumber() ? static_cast<long long>(std::get<double>(v_)) : def; }
    const std::string& asString() const;
    std::string str(std::string def = {}) const { return isString() ? std::get<std::string>(v_) : def; }
    const Array& array() const;
    const Object& object() const;

    // object access; missing keys (or a non-object) give a null value
    const Json& operator[](std::string_view key) const;
    bool has(std::string_view key) const;
    // building objects
    Json& set(std::string key, Json value);

private:
    std::variant<std::monostate, bool, double, std::string, std::shared_ptr<Array>, std::shared_ptr<Object>> v_;
};

} // namespace nk
