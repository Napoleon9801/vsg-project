#pragma once

#include <stdint.h>

// Hardware-independent policies shared by the sketch and native regression tests.
enum SystemState {
    STATE_INIT, STATE_STANDBY, STATE_BOOTSTRAP, STATE_SOFT_START,
    STATE_RUNNING, STATE_FAULT
};

enum FaultReason {
    FAULT_NONE, FAULT_HARDWARE, FAULT_ADC_NOT_IDLE, FAULT_ADC_NOT_STARTED,
    FAULT_ADC_TIMEOUT, FAULT_OVERCURRENT, FAULT_OVERLOAD, FAULT_DEADLINE,
    FAULT_INITIALIZATION, FAULT_CALIBRATION, FAULT_PWM
};

enum StartupAction { STARTUP_NONE, STARTUP_ENABLE_REQUEST, STARTUP_BEGIN_PWM };

class SafetySupervisor {
public:
    SystemState state() const { return state_; }
    FaultReason reason() const { return reason_; }

    void initialize() {
        if (state_ == STATE_INIT) state_ = STATE_STANDBY;
    }

    void trip(FaultReason reason) {
        if (state_ != STATE_FAULT) reason_ = reason;
        state_ = STATE_FAULT;
    }

    // Called only after this tick's ADC and protection checks passed.
    StartupAction advance_startup(uint32_t now_us) {
        if (state_ == STATE_STANDBY) {
            bootstrap_start_us_ = now_us;
            state_ = STATE_BOOTSTRAP;
            return STARTUP_ENABLE_REQUEST;
        }
        if (state_ == STATE_BOOTSTRAP &&
            static_cast<uint32_t>(now_us - bootstrap_start_us_) >= 10000U) {
            state_ = STATE_SOFT_START;
            return STARTUP_BEGIN_PWM;
        }
        return STARTUP_NONE;
    }

    void finish_soft_start() {
        if (state_ == STATE_SOFT_START) state_ = STATE_RUNNING;
    }

private:
    SystemState state_ = STATE_INIT;
    FaultReason reason_ = FAULT_NONE;
    uint32_t bootstrap_start_us_ = 0;
};

inline bool deadline_ok(uint32_t notifications, uint32_t response_us,
                        uint32_t budget_us) {
    return notifications == 1U && response_us < budget_us;
}

// Initialize every compare value before restoring ANY generator from force-low.
// Hardware fault latches are never cleared here.
template <class Pwm>
bool apply_pwm(Pwm& pwm, const float duty[3], bool& released) {
    for (unsigned channel = 0; channel < 3; ++channel)
        if (!pwm.write_duty(channel, duty[channel])) return false;
    if (!released) {
        for (unsigned channel = 0; channel < 3; ++channel)
            if (!pwm.restore_mode(channel)) return false;
        released = true;
    }
    return true;
}

// Io supplies busy(), now_us(), trigger(), and read(). A BUSY pulse must be
// observed for EACH conversion. No SPI read is allowed after either timeout.
template <class Io>
FaultReason acquire_adc(Io& io, uint32_t assertion_timeout_us,
                        uint32_t completion_timeout_us) {
    if (io.busy()) return FAULT_ADC_NOT_IDLE;
    io.trigger();
    const uint32_t assertion_start = io.now_us();
    while (!io.busy()) {
        if (static_cast<uint32_t>(io.now_us() - assertion_start) >= assertion_timeout_us)
            return FAULT_ADC_NOT_STARTED;
    }
    const uint32_t completion_start = io.now_us();
    while (io.busy()) {
        if (static_cast<uint32_t>(io.now_us() - completion_start) >= completion_timeout_us)
            return FAULT_ADC_TIMEOUT;
    }
    io.read();
    return FAULT_NONE;
}
