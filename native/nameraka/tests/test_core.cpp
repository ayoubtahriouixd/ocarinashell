// Unit tests of Nameraka's pure logic: base estimator, effective multiplier + warning, audio delay, state machine,
// lsfg.toml writer, JSON. No framework: each CHECK prints the failing expression; the exit code counts failures.
#include <cmath>
#include <cstdio>
#include <string>

#include "common/json.hpp"
#include "core/base_estimator.hpp"
#include "core/lsfg_toml.hpp"
#include "core/multiplier.hpp"
#include "core/state_machine.hpp"

static int failures = 0;
#define CHECK(expr)                                                              \
    do {                                                                         \
        if (!(expr)) {                                                           \
            std::fprintf(stderr, "%s:%d: CHECK(%s)\n", __FILE__, __LINE__, #expr); \
            ++failures;                                                          \
        }                                                                        \
    } while (0)
#define NEAR(a, b, eps) CHECK(std::fabs((a) - (b)) <= (eps))

using namespace nk;

static void feed(BaseEstimator& e, double& t, double fps, double seconds, double jitter = 0) {
    int n = static_cast<int>(seconds * fps);
    for (int i = 0; i < n; ++i) {
        t += 1.0 / fps + ((i % 2) ? jitter : -jitter);
        e.push(t);
    }
}

static void testBase() {
    BaseEstimator e;
    double t = 0;
    e.push(t);
    feed(e, t, 30, 0.2);
    CHECK(e.base() == 0);                       // fewer than 8 intervals
    feed(e, t, 30, 1, 0.002);                   // jitter ±2 ms
    NEAR(e.base(), 30, 1e-9);
    // 23.976 snaps to 23.976, not 24
    BaseEstimator f;
    double u = 0;
    f.push(u);
    feed(f, u, 23.976, 2);
    NEAR(f.base(), 23.976, 1e-9);
    // a change applies only after it lasts > 1 s
    feed(e, t, 60, 0.6);
    NEAR(e.base(), 30, 1e-9);
    feed(e, t, 60, 1.5);
    NEAR(e.base(), 60, 1e-9);
    // a pause (gap > 0.5 s) is not an interval
    t += 3.0;
    e.push(t);
    NEAR(e.base(), 60, 1e-9);
    NEAR(e.raw(), 60, 0.5);
    // unusual rates are kept as measured (2 decimals)
    NEAR(BaseEstimator::snap(37.123), 37.12, 1e-9);
    NEAR(BaseEstimator::snap(59.5), 59.94, 1e-9);
    NEAR(BaseEstimator::snap(29.985), 30, 1e-9);      // the tie between 29,97 and 30 goes to the whole rate
    NEAR(BaseEstimator::snap(29.972), 29.97, 1e-9);
    CHECK(BaseEstimator::snap(0) == 0);
}

static void testMultiplier() {
    // the table of §19 at 120 Hz
    struct Row { double base; int chosen; int m; bool perfect; };
    const Row rows[] = {
        {23.976, 2, 2, false}, {23.976, 4, 4, false}, {23.976, 6, 5, true}, {23.976, 0, 5, true},
        {25, 2, 2, false}, {25, 4, 4, false}, {25, 6, 4, false}, {25, 0, 4, false},
        {30, 2, 2, false}, {30, 4, 4, true}, {30, 6, 4, true}, {30, 0, 4, true},
        {60, 2, 2, true}, {60, 4, 2, true}, {60, 6, 2, true}, {60, 0, 2, true},
    };
    for (const auto& r : rows) {
        auto e = effective(r.chosen, 0, r.base, 120);
        if (e.m != r.m || e.perfect != r.perfect)
            std::fprintf(stderr, "  base %.3f chosen %d → m %d perfect %d (want %d %d)\n", r.base, r.chosen, e.m,
                         e.perfect, r.m, r.perfect);
        CHECK(e.m == r.m);
        CHECK(e.perfect == r.perfect);
    }
    CHECK(effective(6, 0, 30, 120).limited);     // «×6 → ×4 · 120 Hz»
    CHECK(!effective(4, 0, 30, 120).limited);
    // «A medida 60» with the panel at 60 Hz: 30 × 2 = 60, perfect
    auto e = effective(0, 60, 30, 60);
    CHECK(e.m == 2 && e.perfect);
    // A medida with a target below Hz: 24 fps, target 48 at 120 Hz → ×2, not perfect (48 ≠ 120)
    e = effective(0, 48, 24, 120);
    CHECK(e.m == 2 && !e.perfect);
    // 144 Hz monitor: 24 × 6 = 144
    e = effective(6, 0, 24, 144);
    CHECK(e.m == 6 && e.perfect);
    // content faster than the panel: pass-through
    e = effective(4, 0, 144, 120);
    CHECK(e.m == 1);
    CHECK(effective(4, 0, 0, 120).m == 1);
}

static void testAudio() {
    NEAR(audioDelayMs(30, 5, 120), 1000.0 / 30 + 5 + 12.5, 1e-9);
    CHECK(audioDelayMs(0, 5, 120) == 0);
    CHECK(!audioDelayChanged(50, 58));
    CHECK(audioDelayChanged(50, 61));
}

static Inputs ready() {
    Inputs in;
    in.wanted = in.targetExists = in.fullscreen = in.focused = in.workspaceVisible = in.presenterReady = true;
    return in;
}

static void testStates() {
    Machine m;
    Inputs in = ready();
    in.presenterReady = false;
    CHECK(m.step(in, 0) && m.state == State::Starting);
    CHECK(!m.step(in, 0.05) && m.state == State::Starting);
    in.presenterReady = true;
    CHECK(m.step(in, 0.1) && m.state == State::Active);
    // Alt+Tab to another window / overview / lock / screen off / shell pause → paused, and back
    for (int k = 0; k < 5; ++k) {
        Inputs p = in;
        if (k == 0) p.focused = false;
        if (k == 1) p.overview = true;
        if (k == 2) p.locked = true;
        if (k == 3) p.screenOff = true;
        if (k == 4) p.shellPause = true;
        CHECK(m.step(p, 1) && m.state == State::Paused);
        CHECK(m.step(in, 1.1) && m.state == State::Active);
    }
    // another workspace
    Inputs ws = in;
    ws.workspaceVisible = false;
    m.step(ws, 2);
    CHECK(m.state == State::Paused);
    // leaving full screen → arming; back within 60 s → starting → active
    Inputs nf = in;
    nf.fullscreen = false;
    m.step(nf, 3);
    CHECK(m.state == State::Arming);
    m.step(nf, 40);
    CHECK(m.state == State::Arming);
    m.step(in, 41);
    CHECK(m.state == State::Starting);
    m.step(in, 41.1);
    CHECK(m.state == State::Active);
    // arming times out after 60 s
    m.step(nf, 50);
    m.step(nf, 111);
    CHECK(m.state == State::Off);
    // switched on over a window that is not full screen: arming, cancelled after 60 s
    Machine a;
    a.step(nf, 0);
    CHECK(a.state == State::Arming);
    a.step(nf, 59);
    CHECK(a.state == State::Arming);
    a.step(nf, 60.5);
    CHECK(a.state == State::Off);
    // target closed → off at once; switched off → off
    Machine c;
    c.step(in, 0);
    c.step(in, 0.1);
    Inputs gone = in;
    gone.targetExists = false;
    CHECK(c.step(gone, 1) && c.state == State::Off);
    c.step(in, 2);
    Inputs off = in;
    off.wanted = false;
    c.step(off, 3);
    CHECK(c.state == State::Off);
    CHECK(stateName(State::Paused) == "paused");
}

static void testToml() {
    LsfgParams p;
    p.multiplier = 4;
    p.flowScale = 0.5;
    p.performance = true;
    std::string t = lsfgToml(p);
    CHECK(t.find("version = 2\n") != std::string::npos);
    CHECK(t.find("multiplier = 4\n") != std::string::npos);
    CHECK(t.find("flow_scale = 0.50\n") != std::string::npos);
    CHECK(t.find("performance_mode = true\n") != std::string::npos);
    CHECK(t.find("name = \"nameraka\"") != std::string::npos);
    CHECK(t.find("dll") == std::string::npos);
    p.flowScale = 3;
    p.multiplier = 0;
    p.dll = "/x/\"y\".dll";
    t = lsfgToml(p);
    CHECK(t.find("flow_scale = 1.00\n") != std::string::npos);
    CHECK(t.find("multiplier = 1\n") != std::string::npos);
    CHECK(t.find("dll = \"/x/\\\"y\\\".dll\"") != std::string::npos);
    char dir[] = "/tmp/nameraka-test-XXXXXX";
    if (mkdtemp(dir)) {
        std::string path = std::string(dir) + "/lsfg.toml";
        CHECK(writeLsfgToml(path, p));
        FILE* f = std::fopen(path.c_str(), "r");
        CHECK(f != nullptr);
        if (f) {
            std::fclose(f);
            std::remove(path.c_str());
        }
        std::remove(dir);
    }
}

static void testJson() {
    auto j = Json::parse(R"({"cmd":"start","window":42,"fps":0,"avSync":true,"t":"a\"bé","n":null,"a":[1,2,{"x":-1.5e1}]})");
    CHECK(j.has_value());
    if (j) {
        CHECK((*j)["cmd"].str() == "start");
        CHECK((*j)["window"].asInt() == 42);
        CHECK((*j)["avSync"].asBool());
        CHECK((*j)["t"].str() == "a\"b\xc3\xa9");
        CHECK((*j)["n"].isNull());
        CHECK((*j)["a"].array().size() == 3);
        NEAR((*j)["a"].array()[2]["x"].asNumber(), -15, 1e-9);
        CHECK((*j)["missing"]["deeper"].isNull());
    }
    CHECK(!Json::parse("{\"a\":}").has_value());
    CHECK(!Json::parse("[1,2").has_value());
    CHECK(!Json::parse("{} x").has_value());
    Json o;
    o.set("state", "active").set("m", 4).set("base", 29.97).set("ok", true);
    auto back = Json::parse(o.dump());
    CHECK(back && (*back)["m"].asInt() == 4 && (*back)["state"].str() == "active");
    NEAR((*back)["base"].asNumber(), 29.97, 1e-9);
    // niri-style nested event
    auto ev = Json::parse(R"({"WindowFocusChanged":{"id":7}})");
    CHECK(ev && (*ev)["WindowFocusChanged"]["id"].asInt() == 7);
}

int main() {
    testBase();
    testMultiplier();
    testAudio();
    testStates();
    testToml();
    testJson();
    if (failures)
        std::fprintf(stderr, "%d fallos\n", failures);
    else
        std::printf("core: todas las pruebas pasan\n");
    return failures ? 1 : 0;
}
