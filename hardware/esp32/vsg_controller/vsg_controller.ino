/**
 * ==================================================================================
 *   Virtual Synchronous Generator (VSG) Pure Islanded (Grid-Forming) Controller
 * ==================================================================================
 * 
 * Target Hardware: ESP32 Dev Board + TI DRV8302 MOSFET Shield + AD7606 External ADC
 * Mode: Pure Islanded (Grid-Forming / Standalone / Standalone Black-Start)
 * 
 * Sized Ratings:
 * - Apparent Power Base (S_base) = 100 VA
 * - Line-to-Line RMS Voltage (V_base) = 24 V
 * - Phase-to-Neutral Peak Voltage (E_0) = 19.596 V
 * - Peak Phase Current Base (I_base_peak) = 3.40 A (Nominal RMS = 2.41 A)
 * - Nominal Grid Frequency (f_0) = 50.0 Hz (omega_0 = 314.159265 rad/s)
 * - Control Loop Rate = 10 kHz (T_s = 100 us)
 * 
 * Control Strategy:
 * 1. Black-Start (Soft-Start): Smoothly ramp the EMF reference (E) from 0V to 19.596V
 *    over 2.0 seconds at a constant 50.0 Hz to prevent capacitor charging inrush current.
 * 2. PLL-Free Operation: Integrate the virtual angle (theta) directly from the
 *    internal speed (omega) from the Tustin-discretized swing equation.
 * 3. Cascaded dq-Frame Controllers:
 *    - Outer Voltage Loop (100 Hz BW) tracks droop EMF and outputs reference currents.
 *    - Inner Current Loop (1 kHz BW) tracks reference currents and outputs command voltages.
 * 4. Space Vector PWM: Converts dq command voltages to duty cycles for DRV8302 gates.
 * 5. Multi-Layer Software Protection:
 *    - Redundant hardware fault input (nFAULT pin monitoring).
 *    - Instantaneous software overcurrent trip (I_trip = 5.1 A peak).
 *    - Thermal overload (I^2*t) accumulator trip.
 * 
 * Pin Remapping Note:
 * - DRV8302 EN_GATE is mapped to GPIO 22 to avoid conflict with HSPI MISO (GPIO 12).
 * 
 * Developed for Chinnawat (Napoleon), Suranaree University of Technology (SUT).
 * ==================================================================================
 */

#include <Arduino.h>
#include <SPI.h>
#include <esp_intr_alloc.h>
#include <driver/mcpwm.h>

// --- Pin Assignments ---
// AD7606 External ADC (HSPI Interface)
#define AD7606_CS_PIN      15
#define AD7606_CONVST_PIN  2
#define AD7606_BUSY_PIN    4
#define SPI_SCK_PIN        14
#define SPI_MISO_PIN       12
#define SPI_MOSI_PIN       13

// DRV8302 Gate Driver Pins
// EN_GATE remapped to 22 (Avoids GPIO 12 MISO pin conflict)
#define EN_GATE_PIN        22
#define DRV_nFAULT_PIN     34
#define DRV_nOCTW_PIN      39

// 3-Phase PWM Pins (MCPWM0)
// SimpleFOC standard or generic driver pins
#define PWM_A_PIN          25
#define PWM_B_PIN          26
#define PWM_C_PIN          27

// --- System & Control Parameters ---
const float Sb = 100.0f;            // Apparent Power Base (VA)
const float Vb = 24.0f;             // Line-to-Line RMS Base Voltage (V)
const float Vdc = 40.0f;            // DC Link Voltage (V) - Plentiful headroom for 24V RMS L-L output
const float f0 = 50.0f;             // Nominal Frequency (Hz)
const float omega0 = 314.159265f;   // Nominal Speed (rad/s)
const float Ts = 0.0001f;           // Control Period (100 microseconds, 10 kHz)

// --- AC LC Filter Parameters (Scaled to 0.08 pu and 0.05 pu) ---
const float Lf = 0.00147f;          // Filter Inductor (H)
const float Cf = 0.00002763f;       // Filter Capacitor (F)

// --- VSG Active & Reactive Loop Settings ---
const float J = 0.002027f;          // Virtual Inertia (kg*m^2)
const float Dp = 30.0f;             // Active Damping (W/(rad/s))
const float Dq = 0.009798f;         // Reactive Droop (V/VAR) - 5% drop at 100 VAR
const float E0 = 19.596f;           // Nominal Peak Phase Voltage (V) - 24V*sqrt(2)/sqrt(3)

// --- Discretized Swing Equation Coefficients (Tustin) ---
const float swing_a1 = 0.9953003f;
const float swing_b0 = 7.832924e-5f;
const float swing_b1 = 7.832924e-5f;

// --- Inner dq PI Control Loop Gains (Scaled) ---
// Inner Current Loop (1 kHz Bandwidth)
const float Kp_i = 14.976f;         // Proportional Gain (V/A)
const float Ki_i_Ts = 0.07128f;     // Integral Gain * Ts (V/A)
const float Vmax = 23.094f;         // Max Voltage Command Amplitude (Vdc/sqrt(3))

// Outer Voltage Loop (100 Hz Bandwidth)
const float Kp_v = 0.00972f;        // Proportional Gain (A/V)
const float Ki_v_Ts = 0.000611f;    // Integral Gain * Ts (A/V)
const float Iref_max = 4.08f;       // Max Current Reference Amplitude (1.2 * I_base_peak)

// --- Software Protection Limits ---
const float I_TRIP_LIMIT = 5.10f;   // Instantaneous Overcurrent Limit (1.5 * I_base_peak)
const float THERMAL_TAU = 10.0f;    // Thermal overload integration time constant (s)
const float THERMAL_TRIP = 17.34f;  // Thermal overload limit (I^2 * t)
const float LPF_CUTOFF_HZ = 5.0f;   // Power measurement low-pass filter cutoff (Hz)

// --- Mathematical Constants ---
const float SQRT3 = 1.7320508f;
const float INV_SQRT3 = 0.57735027f;
const float TWO_THIRDS = 0.66666667f;
const float ONE_THIRD = 0.33333333f;

// --- ADC Calibration Scales ---
// Voltage divider scales 40V max down to 10V input of AD7606
const float VOLTAGE_SCALE = 40.0f / 32768.0f;
// Current sensor ACS712-05B sensitivity is 185 mV/A. Centered at 2.5V (offset).
const float ACS712_SENSITIVITY = 0.185f; 

// --- Shared Inter-Core Telemetry Struct ---
struct TelemetryData {
    float ia, ib, ic;
    float va, vb, vc;
    float P, Q;
    float omega;
    float theta;
    float E;
    uint32_t execution_time_us;
    bool fault_state;
    const char* state_str;
};

volatile TelemetryData shared_telemetry;
portMUX_TYPE spinlock = portMUX_INITIALIZER_UNLOCKED;

// --- System State Machine ---
enum SystemState {
    STATE_INIT = 0,
    STATE_STANDBY,
    STATE_SOFT_START,
    STATE_RUNNING,
    STATE_FAULT
};
volatile SystemState current_state = STATE_INIT;

// --- Global Registers for Control Loops (Static in RAM) ---
float vsg_domega = 0.0f;
float vsg_domega_prev = 0.0f;
float vsg_theta = 0.0f;
float vsg_P_filt = 0.0f;
float vsg_Q_filt = 0.0f;
float vsg_P_err_prev = 0.0f;
float E_ramp = 0.0f;

// PI Integrators
float id_integrator = 0.0f;
float iq_integrator = 0.0f;
float vd_integrator = 0.0f;
float vq_integrator = 0.0f;

// Protection thermal accumulator
float thermal_accumulator = 0.0f;

// Hardware SPI instance pointer
SPIClass* hspi = nullptr;

// --- Forward Declarations ---
void trigger_hardware_trip();
void init_pwm();
void init_external_adc();
void init_gpio();
inline void read_external_adc(float &ia, float &ib, float &ic, float &va, float &vb, float &vc);

// --- Clarke / Park Transformations (Optimized Floating Point) ---
inline void clarke_transform(float a, float b, float c, float &alpha, float &beta) {
    alpha = TWO_THIRDS * a - ONE_THIRD * (b + c);
    beta = (b - c) * INV_SQRT3;
}

inline void park_transform(float alpha, float beta, float theta, float &d, float &q) {
    float cos_t = cosf(theta);
    float sin_t = sinf(theta);
    d = alpha * cos_t + beta * sin_t;
    q = -alpha * sin_t + beta * cos_t;
}

inline void inv_park_transform(float d, float q, float theta, float &alpha, float &beta) {
    float cos_t = cosf(theta);
    float sin_t = sinf(theta);
    alpha = d * cos_t - q * sin_t;
    beta = d * sin_t + q * cos_t;
}

// Space Vector PWM (Injects 3rd harmonic for maximum DC utilization)
inline void svpwm(float alpha, float beta, float Vdc, float &da, float &db, float &dc) {
    float va = alpha;
    float vb = -0.5f * alpha + (SQRT3 * 0.5f) * beta;
    float vc = -0.5f * alpha - (SQRT3 * 0.5f) * beta;
    
    float v_max = va;
    if (vb > v_max) v_max = vb;
    if (vc > v_max) v_max = vc;
    
    float v_min = va;
    if (vb < v_min) v_min = vb;
    if (vc < v_min) v_min = vc;
    
    float v_offset = 0.5f * (v_max + v_min);
    
    float va_mod = va - v_offset;
    float vb_mod = vb - v_offset;
    float vc_mod = vc - v_offset;
    
    // Scale to duty cycles [0.0, 1.0]
    da = (va_mod / (Vdc * 0.5f)) + 0.5f;
    db = (vb_mod / (Vdc * 0.5f)) + 0.5f;
    dc = (vc_mod / (Vdc * 0.5f)) + 0.5f;
    
    // Safety saturation clamping
    da = constrain(da, 0.02f, 0.98f);
    db = constrain(db, 0.02f, 0.98f);
    dc = constrain(dc, 0.02f, 0.98f);
}

// --- High-Speed 10 kHz Control Loop ISR (Core 1) ---
void IRAM_ATTR onTimerInterrupt() {
    uint32_t start_time = esp_cpu_get_cycle_count();
    
    // nFAULT pin is active LOW. If low, shut down instantly.
    if (digitalRead(DRV_nFAULT_PIN) == LOW) {
        current_state = STATE_FAULT;
        trigger_hardware_trip();
        return;
    }
    
    if (current_state == STATE_FAULT) {
        trigger_hardware_trip();
        return;
    }
    
    // 1. Read simultaneous samples from the external AD7606 ADC
    float ia, ib, ic;
    float va, vb, vc;
    read_external_adc(ia, ib, ic, va, vb, vc);
    
    // 2. Multi-Layer Overcurrent Protection
    // Layer 1: Instantaneous Current Limit
    if (fabs(ia) > I_TRIP_LIMIT || fabs(ib) > I_TRIP_LIMIT || fabs(ic) > I_TRIP_LIMIT) {
        current_state = STATE_FAULT;
        trigger_hardware_trip();
        return;
    }
    
    // Layer 2: Thermal Overload (I^2 * t)
    float i_sq_avg = ONE_THIRD * (ia*ia + ib*ib + ic*ic);
    thermal_accumulator += Ts * (i_sq_avg - (thermal_accumulator / THERMAL_TAU));
    if (thermal_accumulator > THERMAL_TRIP) {
        current_state = STATE_FAULT;
        trigger_hardware_trip();
        return;
    }
    
    // --- Grid-Forming Control Algorithms ---
    if (current_state == STATE_SOFT_START || current_state == STATE_RUNNING) {
        // A. Transform currents and voltages to dq-frame
        float i_alpha, i_beta, id, iq;
        float v_alpha, v_beta, vd, vq;
        
        clarke_transform(ia, ib, ic, i_alpha, i_beta);
        park_transform(i_alpha, i_beta, vsg_theta, id, iq);
        
        clarke_transform(va, vb, vc, v_alpha, v_beta);
        park_transform(v_alpha, v_beta, vsg_theta, vd, vq);
        
        // B. Power Calculations and 5 Hz Filtering
        float P_raw = 1.5f * (vd * id + vq * iq);
        float Q_raw = 1.5f * (vq * id - vd * iq);
        
        // omega_c = 2*pi*f_c = 31.4159265 rad/s
        // K_lpf = (omega_c * Ts) / (1 + omega_c * Ts) = 0.00313176
        const float K_lpf = 0.00313176f;
        vsg_P_filt += K_lpf * (P_raw - vsg_P_filt);
        vsg_Q_filt += K_lpf * (Q_raw - vsg_Q_filt);
        
        float omega = omega0;
        float E = E0;
        
        // C. Standalone State Machine Control
        if (current_state == STATE_SOFT_START) {
            // Soft black-start ramp up from 0 to E0 over 2 seconds (20,000 steps)
            E_ramp += (E0 / 20000.0f);
            if (E_ramp >= E0) {
                E_ramp = E0;
                current_state = STATE_RUNNING; // Ramp completed, engage loops
            }
            E = E_ramp;
            omega = omega0; // Maintain exactly 50 Hz during ramp up
            vsg_domega = 0.0f;
            vsg_domega_prev = 0.0f;
        } 
        else if (current_state == STATE_RUNNING) {
            // Active Power Swing Loop (Tustin)
            // Under islanded mode, we set the virtual mechanical power Pref to 50.0 W to balance the local load.
            float P_err = 50.0f - vsg_P_filt;
            vsg_domega = swing_a1 * vsg_domega_prev + swing_b0 * P_err + swing_b1 * vsg_P_err_prev;
            
            vsg_domega_prev = vsg_domega;
            vsg_P_err_prev = P_err;
            
            omega = omega0 + vsg_domega;
            
            // Reactive Power Droop Loop
            E = E0 - Dq * vsg_Q_filt;
        }
        
        // D. Integrate Virtual Rotor Phase Angle (Trapezoidal Rule)
        vsg_theta += Ts * omega0 + 0.5f * Ts * (vsg_domega + vsg_domega_prev);
        if (vsg_theta >= 2.0f * M_PI) vsg_theta -= 2.0f * M_PI;
        else if (vsg_theta < 0.0f) vsg_theta += 2.0f * M_PI;
        
        // E. Outer Voltage PI Loop (dq-frame)
        float vd_ref = E;
        float vq_ref = 0.0f;
        
        float ev_d = vd_ref - vd;
        float ev_q = vq_ref - vq;
        
        // Decouple capacitor charging currents: i_cap_d = -omega*C_f*v_q, i_cap_q = omega*C_f*v_d
        float id_ref = Kp_v * ev_d + vd_integrator - (omega * Cf * vq);
        float iq_ref = Kp_v * ev_q + vq_integrator + (omega * Cf * vd);
        
        // Saturate current references to protect MOSFETs
        float I_ref_mag = sqrtf(id_ref*id_ref + iq_ref*iq_ref);
        bool volt_saturated = false;
        if (I_ref_mag > Iref_max) {
            volt_saturated = true;
            id_ref = id_ref * (Iref_max / I_ref_mag);
            iq_ref = iq_ref * (Iref_max / I_ref_mag);
        }
        
        // Update voltage integrators (Backward Euler with conditional clamping)
        if (!volt_saturated || (ev_d * vd_integrator < 0.0f)) {
            vd_integrator += Ki_v_Ts * ev_d;
        }
        if (!volt_saturated || (ev_q * vq_integrator < 0.0f)) {
            vq_integrator += Ki_v_Ts * ev_q;
        }
        
        // F. Inner Current PI Loop (dq-frame)
        float ed = id_ref - id;
        float eq = iq_ref - iq;
        
        float ud_pi = Kp_i * ed + id_integrator;
        float uq_pi = Kp_i * eq + iq_integrator;
        
        // Decouple inductive coupling and add voltage feedforward:
        // v_id = u_pi_d - omega*L_f*i_q + v_d
        // v_iq = u_pi_q + omega*L_f*i_d + v_q
        float decoupling_term = omega * Lf;
        float vd_cmd = ud_pi - decoupling_term * iq + vd;
        float vq_cmd = uq_pi + decoupling_term * id + vq;
        
        // Saturate command voltage to maximum linear SVPWM radius
        float V_cmd_mag = sqrtf(vd_cmd*vd_cmd + vq_cmd*vq_cmd);
        bool curr_saturated = false;
        if (V_cmd_mag > Vmax) {
            curr_saturated = true;
            vd_cmd = vd_cmd * (Vmax / V_cmd_mag);
            vq_cmd = vq_cmd * (Vmax / V_cmd_mag);
        }
        
        // Update current integrators (Conditional integration anti-windup)
        if (!curr_saturated || (ed * ud_pi < 0.0f)) {
            id_integrator += Ki_i_Ts * ed;
        }
        if (!curr_saturated || (eq * uq_pi < 0.0f)) {
            iq_integrator += Ki_i_Ts * eq;
        }
        
        // G. Inverse Park Transform and SVPWM duty cycles
        float v_cmd_alpha, v_cmd_beta;
        inv_park_transform(vd_cmd, vq_cmd, vsg_theta, v_cmd_alpha, v_cmd_beta);
        
        float duty_a, duty_b, duty_c;
        svpwm(v_cmd_alpha, v_cmd_beta, Vdc, duty_a, duty_b, duty_c);
        
        // H. Write duty cycles to hardware MCPWM channels
        mcpwm_set_duty(MCPWM_UNIT_0, MCPWM_TIMER_0, MCPWM_OPR_A, duty_a * 100.0f);
        mcpwm_set_duty(MCPWM_UNIT_0, MCPWM_TIMER_1, MCPWM_OPR_A, duty_b * 100.0f);
        mcpwm_set_duty(MCPWM_UNIT_0, MCPWM_TIMER_2, MCPWM_OPR_A, duty_c * 100.0f);
        
        // I. Share Downsampled Telemetry Data with Core 0 (at ~100 Hz rate)
        if (esp_cpu_get_cycle_count() % 100 == 0) {
            const char* state_name = "UNKNOWN";
            if (current_state == STATE_SOFT_START) state_name = "SOFT_START";
            else if (current_state == STATE_RUNNING) state_name = "RUNNING";
            
            portENTER_CRITICAL_ISR(&spinlock);
            shared_telemetry.ia = ia;
            shared_telemetry.ib = ib;
            shared_telemetry.ic = ic;
            shared_telemetry.va = va;
            shared_telemetry.vb = vb;
            shared_telemetry.vc = vc;
            shared_telemetry.P = vsg_P_filt;
            shared_telemetry.Q = vsg_Q_filt;
            shared_telemetry.omega = omega;
            shared_telemetry.theta = vsg_theta;
            shared_telemetry.E = E;
            shared_telemetry.execution_time_us = (esp_cpu_get_cycle_count() - start_time) / 240; // 240 MHz clock
            shared_telemetry.fault_state = false;
            shared_telemetry.state_str = state_name;
            portEXIT_CRITICAL_ISR(&spinlock);
        }
    }
}

// --- Emergency Safe Hardware Shutdown ---
void trigger_hardware_trip() {
    // 1. Immediately disable MCPWM outputs
    mcpwm_set_signal_low(MCPWM_UNIT_0, MCPWM_TIMER_0, MCPWM_OPR_A);
    mcpwm_set_signal_low(MCPWM_UNIT_0, MCPWM_TIMER_1, MCPWM_OPR_A);
    mcpwm_set_signal_low(MCPWM_UNIT_0, MCPWM_TIMER_2, MCPWM_OPR_A);
    
    // 2. Shut off DRV8302 Gate Drivers physically via EN_GATE pin
    digitalWrite(EN_GATE_PIN, LOW); 
    
    // 3. Update status
    current_state = STATE_FAULT;
    
    portENTER_CRITICAL_ISR(&spinlock);
    shared_telemetry.fault_state = true;
    shared_telemetry.state_str = "FAULT";
    portEXIT_CRITICAL_ISR(&spinlock);
}

// --- Hardware Initialization Functions ---

void init_gpio() {
    // DRV8302 control and indicator pins
    pinMode(EN_GATE_PIN, OUTPUT);
    digitalWrite(EN_GATE_PIN, LOW); // Hold in safe disabled mode on boot
    
    pinMode(DRV_nFAULT_PIN, INPUT_PULLUP);
    pinMode(DRV_nOCTW_PIN, INPUT_PULLUP);
}

void init_pwm() {
    // Bind MCPWM0 to hardware driver pins
    mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM0A, PWM_A_PIN);
    mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM1A, PWM_B_PIN);
    mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM2A, PWM_C_PIN);
    
    mcpwm_config_t pwm_config;
    pwm_config.frequency = 20000;                      // 20 kHz switching frequency
    pwm_config.cmpr_a = 50.0;                          // 50% initial duty cycle
    pwm_config.cmpr_b = 50.0;
    pwm_config.counter_mode = MCPWM_UP_DOWN_COUNTER;   // Symmetric center-aligned PWM
    pwm_config.duty_mode = MCPWM_DUTY_MODE_0;          // Active-high duty cycle
    
    mcpwm_init(MCPWM_UNIT_0, MCPWM_TIMER_0, &pwm_config);
    mcpwm_init(MCPWM_UNIT_0, MCPWM_TIMER_1, &pwm_config);
    mcpwm_init(MCPWM_UNIT_0, MCPWM_TIMER_2, &pwm_config);
}

void init_external_adc() {
    pinMode(AD7606_CS_PIN, OUTPUT);
    pinMode(AD7606_CONVST_PIN, OUTPUT);
    pinMode(AD7606_BUSY_PIN, INPUT);
    
    digitalWrite(AD7606_CS_PIN, HIGH);
    digitalWrite(AD7606_CONVST_PIN, HIGH);
    
    // Initialize HSPI on defined pins
    hspi = new SPIClass(HSPI);
    hspi->begin(SPI_SCK_PIN, SPI_MISO_PIN, SPI_MOSI_PIN, AD7606_CS_PIN);
    hspi->beginTransaction(SPISettings(20000000, MSBFIRST, SPI_MODE0)); // 20 MHz SPI Clock
}

// Optimized AD7606 simultaneous conversion and SPI read routine
inline void read_external_adc(float &ia, float &ib, float &ic, float &va, float &vb, float &vc) {
    // 1. Pulse CONVST LOW to trigger conversion across all 8 channels
    digitalWrite(AD7606_CONVST_PIN, LOW);
    asm volatile("nop; nop; nop;"); // Minimal pulse width
    digitalWrite(AD7606_CONVST_PIN, HIGH);
    
    // 2. Wait for BUSY to go low (completed). Includes timeout for safety
    int timeout = 1000;
    while (digitalRead(AD7606_BUSY_PIN) == HIGH && timeout > 0) {
        timeout--;
    }
    
    // 3. Read 6 registers (Channels 1-6) via SPI (12 bytes total)
    uint8_t raw_bytes[12] = {0};
    digitalWrite(AD7606_CS_PIN, LOW);
    hspi->transferBytes(nullptr, raw_bytes, 12); // Null output, read 12 bytes
    digitalWrite(AD7606_CS_PIN, HIGH);
    
    // 4. Map raw 16-bit signed integer values (assembled MSB-first)
    int16_t raw_ch1 = (int16_t)((raw_bytes[0] << 8) | raw_bytes[1]);
    int16_t raw_ch2 = (int16_t)((raw_bytes[2] << 8) | raw_bytes[3]);
    int16_t raw_ch3 = (int16_t)((raw_bytes[4] << 8) | raw_bytes[5]);
    int16_t raw_ch4 = (int16_t)((raw_bytes[6] << 8) | raw_bytes[7]);
    int16_t raw_ch5 = (int16_t)((raw_bytes[8] << 8) | raw_bytes[9]);
    int16_t raw_ch6 = (int16_t)((raw_bytes[10] << 8) | raw_bytes[11]);
    
    // Phase Currents (ACS712 current sensors centered at 2.5V bias offset)
    float v_ch1 = (float)raw_ch1 * (10.0f / 32768.0f);
    float v_ch2 = (float)raw_ch2 * (10.0f / 32768.0f);
    float v_ch3 = (float)raw_ch3 * (10.0f / 32768.0f);
    
    ia = (v_ch1 - 2.5f) / ACS712_SENSITIVITY;
    ib = (v_ch2 - 2.5f) / ACS712_SENSITIVITY;
    ic = (v_ch3 - 2.5f) / ACS712_SENSITIVITY;
    
    // Capacitor/Load AC Voltages (attenuated by 4 using precision dividers)
    va = (float)raw_ch4 * VOLTAGE_SCALE;
    vb = (float)raw_ch5 * VOLTAGE_SCALE;
    vc = (float)raw_ch6 * VOLTAGE_SCALE;
}

// --- Core 0 Telemetry & Monitoring Task (10 Hz) ---
void telemetryTask(void* parameter) {
    while (true) {
        TelemetryData local_data;
        
        // Retrieve double-buffered telemetry safely
        portENTER_CRITICAL(&spinlock);
        local_data = shared_telemetry;
        portEXIT_CRITICAL(&spinlock);
        
        if (local_data.fault_state) {
            Serial.println("!!! [EMERGENCY TRIP] CRITICAL HARDWARE OR SOFTWARE OVERCURRENT FAULT LATCHED !!!");
            Serial.println("Action Required: Power down DC bus, check load connections, verify star grounding.");
        } else {
            Serial.printf("State: %s | P: %.2f W | Q: %.2f VAR | Freq: %.3f Hz | EMF (E): %.2f V\n",
                          local_data.state_str, local_data.P, local_data.Q,
                          local_data.omega / (2.0f * M_PI), local_data.E);
            Serial.printf("  V_abc: [%.2f, %.2f, %.2f] V | I_abc: [%.3f, %.3f, %.3f] A | Execution Time: %d us\n",
                          local_data.va, local_data.vb, local_data.vc,
                          local_data.ia, local_data.ib, local_data.ic,
                          local_data.execution_time_us);
        }
        
        vTaskDelay(pdMS_TO_TICKS(100)); // 100 ms (10 Hz rate)
        // Wait, let's keep watchdog happy
        yield();
    }
}

// --- High-Speed Timer ISR wrapper for ESP32 ---
hw_timer_t* ctrl_timer = nullptr;
void IRAM_ATTR onTimerWrapper() {
    onTimerInterrupt();
}

// --- Main Arduino Setup ---
void setup() {
    Serial.begin(115200);
    delay(1000); // Startup settle delay
    Serial.println("==========================================================");
    Serial.println("  ESP32 Grid-Forming VSG Standalone Controller Initialized ");
    Serial.println("==========================================================");
    
    // Initialize GPIOs, PWM outputs, and SPI AD7606
    init_gpio();
    init_pwm();
    init_external_adc();
    
    // Pin Telemetry Task to Core 0 (Low Priority UI/Serial monitoring)
    xTaskCreatePinnedToCore(
        telemetryTask,
        "TelemetryTask",
        4096,
        NULL,
        1,
        NULL,
        0 // Pin to Core 0
    );
    
    // Safe transition into Standby State
    current_state = STATE_STANDBY;
    Serial.println("System in STANDBY state. Waiting to initiate soft black-start...");
    delay(2000); // Hold in standby briefly to let power settle
    
    // Enable Gate Drivers physically via EN_GATE pin
    digitalWrite(EN_GATE_PIN, HIGH);
    delay(10); // Let gate driver charge internal charge pumps
    
    // Set state to Soft-Start
    current_state = STATE_SOFT_START;
    Serial.println("Initiating Black-Start: 2-second soft-voltage ramping started...");
    
    // --- Configure 10 kHz Hardware Timer Interrupt on Core 1 ---
    ctrl_timer = timerBegin(0, 80, true); // Timer 0, Pre-scaler 80 (80 MHz / 80 = 1 MHz tick)
    timerAttachInterrupt(ctrl_timer, &onTimerWrapper, true);
    timerAlarmWrite(ctrl_timer, 100, true); // Trigger every 100 ticks = 100 us (10 kHz)
    timerAlarmEnable(ctrl_timer); // Start the control loop
}

void loop() {
    // Loop is left empty. Core 1 runs the 10 kHz ISR, and Core 0 runs background FreeRTOS tasks.
    vTaskDelay(portMAX_DELAY);
}
