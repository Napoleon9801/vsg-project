#include "../vsg_controller/safety_policy.h"
#include <cassert>
#include <iostream>
#include <vector>

struct FakeAdc {
    uint32_t time = 0;
    uint32_t elapsed = 0;
    bool triggered = false;
    bool initially_busy = false;
    bool stuck_low = false;
    bool stuck_high = false;
    unsigned reads = 0;
    bool busy() {
        ++time;
        if (!triggered) return initially_busy;
        ++elapsed;
        return !stuck_low && elapsed >= 2 && (stuck_high || elapsed < 7);
    }
    uint32_t now_us() { return time; }
    void trigger() { triggered = true; }
    void read() { ++reads; }
};

struct FakePwm {
    std::vector<int> events;
    int fail_event = -1;
    bool write_duty(unsigned channel, float duty) {
        assert(duty >= 0.03f && duty <= 0.97f);
        events.push_back(static_cast<int>(channel));
        return fail_event != static_cast<int>(channel);
    }
    bool restore_mode(unsigned channel) {
        int event = static_cast<int>(channel) + 3;
        events.push_back(event);
        return fail_event != event;
    }
};

int main() {
    // A trip at ANY startup stage is absorbing; late startup calls cannot enable
    // or restart PWM, and subsequent faults retain the first diagnostic reason.
    for (int phase = 0; phase < 5; ++phase) {
        SafetySupervisor state;
        if (phase >= 1) state.initialize();
        if (phase >= 2) assert(state.advance_startup(100) == STARTUP_ENABLE_REQUEST);
        if (phase >= 3) assert(state.advance_startup(10100) == STARTUP_BEGIN_PWM);
        if (phase >= 4) state.finish_soft_start();
        state.trip(FAULT_ADC_TIMEOUT);
        state.initialize();
        assert(state.advance_startup(50000) == STARTUP_NONE);
        state.finish_soft_start();
        state.trip(FAULT_HARDWARE);
        assert(state.state() == STATE_FAULT);
        assert(state.reason() == FAULT_ADC_TIMEOUT);
    }
    SafetySupervisor state;
    state.initialize();
    const uint32_t start = UINT32_MAX - 5000;
    assert(state.advance_startup(start) == STARTUP_ENABLE_REQUEST);
    assert(state.advance_startup(start + 9999U) == STARTUP_NONE);
    assert(state.advance_startup(start + 10000U) == STARTUP_BEGIN_PWM);
    assert(state.advance_startup(start + 20000U) == STARTUP_NONE);
    state.finish_soft_start();
    assert(state.state() == STATE_RUNNING);
    std::cout << "PASS: startup, fault absorption, first reason, timer wrap\n";

    FakeAdc healthy;
    assert(acquire_adc(healthy, 5, 50) == FAULT_NONE);
    assert(healthy.triggered && healthy.reads == 1);
    FakeAdc prebusy;
    prebusy.initially_busy = true;
    assert(acquire_adc(prebusy, 5, 50) == FAULT_ADC_NOT_IDLE);
    assert(!prebusy.triggered && prebusy.reads == 0);
    FakeAdc low;
    low.stuck_low = true;
    assert(acquire_adc(low, 5, 50) == FAULT_ADC_NOT_STARTED);
    assert(low.reads == 0 && low.elapsed <= 6);
    FakeAdc high;
    high.stuck_high = true;
    assert(acquire_adc(high, 5, 50) == FAULT_ADC_TIMEOUT);
    assert(high.reads == 0 && high.elapsed <= 55);
    FakeAdc wrapped;
    wrapped.time = UINT32_MAX - 2;
    wrapped.stuck_high = true;
    assert(acquire_adc(wrapped, 5, 50) == FAULT_ADC_TIMEOUT);
    assert(wrapped.reads == 0);
    std::cout << "PASS: ADC normal/prebusy/stuck-low/stuck-high/wrap, no stale read\n";

    assert(deadline_ok(1, 89, 90));
    assert(!deadline_ok(1, 90, 90));
    assert(!deadline_ok(1, 100, 90));
    assert(!deadline_ok(2, 30, 90));
    assert(!deadline_ok(0, 30, 90));
    assert(!deadline_ok(1, 70 + 25, 90)); // short execution, but late task dispatch
    std::cout << "PASS: missed notifications, late wake, response budget boundary\n";

    const float duties[3] = {0.5f, 0.4f, 0.6f};
    FakePwm pwm;
    bool released = false;
    assert(apply_pwm(pwm, duties, released));
    assert(released && pwm.events == std::vector<int>({0, 1, 2, 3, 4, 5}));
    pwm.events.clear();
    assert(apply_pwm(pwm, duties, released));
    assert(pwm.events == std::vector<int>({0, 1, 2}));
    for (int fail = 0; fail < 6; ++fail) {
        FakePwm broken;
        broken.fail_event = fail;
        released = false;
        assert(!apply_pwm(broken, duties, released));
        assert(!released);
        assert(broken.events.size() == static_cast<unsigned>(fail + 1));
    }
    std::cout << "PASS: three compares precede release; no release on write failure\n";
}
