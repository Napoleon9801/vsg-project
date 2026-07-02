/**
 * ==================================================================================
 *   Virtual Synchronous Generator (VSG) — Pure Islanded (Grid-Forming) Controller
 * ==================================================================================
 *
 *   DESIGN POINT: **Option A (sim-faithful)** — locked 2026-05-30
 *   Verified end-to-end against MATLAB/Simulink Stage 5c (phase5c_tuned.m).
 *
 *   ------------------------------------------------------------------------------
 *   REFACTOR 2026-07-02 — ISR-safety + protection hardening (pre-bench review):
 *     1. FPU-SAFE ARCHITECTURE: all float control math moved out of the timer ISR
 *        into a max-priority task pinned to Core 1 (ESP32 FPU is NOT usable in
 *        ISR context — the old design would panic with a Coprocessor exception).
 *        The ISR now only does vTaskNotifyGiveFromISR(); jitter cost is a few µs.
 *     2. IRAM-SAFETY: mcpwm_set_duty() / SPI transfers now run in task context.
 *     3. GPIO34 PULL-UP FIX: GPIO 34–39 are input-only with NO internal pull-up.
 *        pinMode(34, INPUT_PULLUP) silently does nothing. The LM393 output is
 *        open-collector → an EXTERNAL 10 kΩ pull-up to 3.3 V is REQUIRED on the
 *        board. (Added to wiring requirements; firmware uses plain INPUT.)
 *     4. HARDWARE OCP PATH: LM393 (active-LOW) now drives the MCPWM hardware
 *        fault input (one-shot, forces all PWM low in <1 µs, latched in silicon)
 *        — matching the <1 µs claim in power_stage_options.md. The software
 *        GPIO poll is kept as a backup layer.
 *     5. ACS712 AUTO-ZERO: per-channel current-sensor offsets are measured at
 *        boot (500 samples, gates disabled) instead of assuming exactly 2.5 V.
 *        Boot halts in FAULT if any offset deviates > ±0.3 V from nominal.
 *     6. SPI CLOCK: 20 MHz → 15 MHz. AD7606 max SCLK is specified lower at
 *        V_DRIVE = 3.3 V (ESP32 logic) than at 5 V — VERIFY against the AD7606
 *        datasheet timing table for your V_DRIVE; drop further if reads glitch.
 *     7. TOOLCHAIN PIN: compile-time guard requires arduino-esp32 core 2.x
 *        (legacy driver/mcpwm.h + old hw_timer API are removed in core 3.x).
 *        Tested against core 2.0.17.
 *
 *   DRY-RUN MODE (first flash on a bare ESP32, no power stage attached):
 *     Set DRY_RUN_NO_POWER_STAGE to 1. This (a) skips ACS712 calibration,
 *     (b) skips the MCPWM hardware-fault hookup (GPIO34 floats on a bare board
 *     and would instantly latch), (c) zeroes the measured i/v so the control
 *     math runs on clean inputs, and (d) KEEPS EN_GATE LOW at all times.
 *     Use it to verify loop timing (execution_time_us) and scope the PWM pins.
 *     >>> SET BACK TO 0 BEFORE CONNECTING THE POWER STAGE. <<<
 *   ------------------------------------------------------------------------------
 *
 *   Target Hardware @ 40 V — supports TWO power stages via POWER_STAGE #define:
 *     A) discrete 6× IRF540N (100 V) + 3× IR2104 (bootstrap, ~520 ns dead-time)
 *        + LM393 OCP comparator                              [budget default]
 *     B) TI DRV8302 shield (integrated buck / current-sense / OCP / UVLO / dead-time)
 *     Common to both: ESP32-WROOM-32D, AD7606 16-bit ADC (SPI),
 *        ACS712-20A current sensors (±20 A)   [NOT -05B: peak ~6.5 A]
 *     Full comparison: docs/notes/power_stage_options.md
 *
 *   ELECTRICAL DESIGN POINT (identical to verified sim):
 *     - DC bus            Vdc    = 40 V   (DRV8302 60 V max → 67 % derating, safe)
 *     - AC d-axis target  V_set  = 14 V peak/phase  (m = 14/(40/2) = 0.70, linear)
 *     - Rated power       P_base = 100 W  (3-phase)
 *     - Nominal freq      f0     = 50 Hz  (omega0 = 314.159265 rad/s)
 *     - Filter            Lf = 1.2 mH, Rf = 0.05 Ω, Cf = 10 µF  → f_res ≈ 1453 Hz
 *     - Damping resistor  Rd = 1 Ω (PHYSICAL, series with Cf — not in code)
 *     - Switching freq    f_sw   = 10 kHz  (carrier = control rate = 10 kHz)
 *     - Control rate      Ts     = 100 µs  (10 kHz task, pinned Core 1)
 *
 *   OUTER VSG LOOP (winner of Stage 5b H-D sweep):
 *     - H = 5 s, D = 0.5, R_p = 0.05 (P-f droop), R_q = 0.05 (Q-V droop)
 *     - Swing law (reverse-engineered + CSV-verified):
 *         inertia_coeff · dω/dt = [P_set_pu + (1 − ω/ω_s)/R_p] − P_e_pu − D·(ω − ω_s)
 *         inertia_coeff = 2H/ω_s = 0.0318310
 *       SS check (ΔP_pu=0.36): Δω_pu = −ΔP_pu/(1/R_p + D·ω_s) = −0.00203
 *       → Δf = −0.102 Hz → f_ss = 49.898 Hz  (CSV cell H5/D0.5 = 49.896 ✓)
 *
 *   CONTROL STRATEGY:
 *     1. Black-Start (Soft-Start): ramp EMF reference E from 0 → 14 V over 2.0 s
 *        at constant 50 Hz to avoid capacitor inrush.
 *     2. PLL-Free: integrate virtual angle θ directly from swing-equation ω.
 *     3. Cascaded dq control (matches Stage 5c):
 *        - Outer voltage PI (100 Hz BW) + cap-current decoupling → i_dq*
 *        - Inner current PI (1 kHz BW) + dq decoupling FF (∓ωLf·i) + load-V FF
 *     4. SPWM (sinusoidal) — matches the verified sim.
 *     5. Multi-layer protection:
 *          L0: MCPWM hardware fault (LM393 → F0, one-shot force-low, <1 µs)
 *          L1: software GPIO poll of the same line (backup, ≤100 µs)
 *          L2: software instantaneous OC trip
 *          L3: I²t thermal accumulator
 *
 *   POWER STAGE NOTE (3× IR2104, one per half-bridge leg):
 *     Drive 3 MCPWM A-channels only — one PWM into each IR2104 IN pin. Each
 *     IR2104 generates the complementary HO/LO pair with a fixed internal
 *     dead-time (~520 ns), so NO MCPWM dead-time is needed. IR2104 is a
 *     bootstrap (non-isolated) driver — acceptable at 40 V benchtop, but keep
 *     hands off live conductors. A common GATE_EN line ties the three SD pins.
 *
 *   FIRMWARE-vs-SIM VALIDATION:
 *     Control gains below are computed from the SAME formulas as phase5c_tuned.m.
 *     On first bench bring-up (Methodology Stage 5/6 = HIL), compare ω(t), P(t)
 *     against the sim's vsg_stage5c_out.mat under the same R_load step.
 *
 *   Pin mapping is a PROPOSED assignment — verify against your shield/wiring.
 *
 *   Developed for Chinnawat (Napoleon), Suranaree University of Technology (SUT).
 * ==================================================================================
 */

#include <Arduino.h>
#include <SPI.h>
#include <esp_arduino_version.h>
#include <driver/mcpwm.h>

// ---- Toolchain guard: legacy MCPWM + hw_timer APIs used below exist only in 2.x
#if ESP_ARDUINO_VERSION < ESP_ARDUINO_VERSION_VAL(2, 0, 0) || \
    ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 0)
#error "This firmware requires arduino-esp32 core 2.x (tested on 2.0.17). Core 3.x removed driver/mcpwm.h and changed the hw_timer API."
#endif

// =================================================================================
//  BUILD MODE — see DRY-RUN note in the header
// =================================================================================
#define DRY_RUN_NO_POWER_STAGE  1   // 1 = bare-ESP32 timing test (gates NEVER enabled)
                                    // 0 = real power stage (calibration + HW fault armed)

// =================================================================================
//  POWER STAGE SELECTION
//  The control core is IDENTICAL for both stages — only the gate-driver semantics
//  differ. Both drive 3 MCPWM A-channels + 1 enable line + 1 fault input.
//  Full comparison: docs/notes/power_stage_options.md
// =================================================================================
#define POWER_STAGE_IR2104   1   // A: discrete 6x IRF540N + 3x IR2104 (budget)
#define POWER_STAGE_DRV8302  2   // B: TI DRV8302 shield (integrated protection)
#define POWER_STAGE  POWER_STAGE_IR2104     // <-- SELECT HERE (A or B)

// =================================================================================
//  PIN ASSIGNMENTS  (proposed — verify against your wiring / shield)
// =================================================================================
// AD7606 External ADC (HSPI Interface)
#define AD7606_CS_PIN      15
#define AD7606_CONVST_PIN  2
#define AD7606_BUSY_PIN    4
#define SPI_SCK_PIN        14
#define SPI_MISO_PIN       12
#define SPI_MOSI_PIN       13

// Gate driver control / status — works for BOTH power stages:
//   A (IR2104) : EN_GATE = common SD/enable of the 3 drivers; OCP_FAULT = LM393 output
//   B (DRV8302): EN_GATE = chip EN_GATE (active HIGH);        OCP_FAULT = chip nFAULT
// NOTE (A): verify IR2104 SD polarity vs datasheet (enable vs shutdown level).
// !! GPIO34 is input-only and has NO internal pull-up. LM393 output is
// !! open-collector → EXTERNAL 10 kΩ pull-up to 3.3 V is REQUIRED on the board.
#define EN_GATE_PIN        22   // gate-driver enable (remapped off GPIO12-MISO)
#define OCP_FAULT_PIN      34   // input-only, active LOW (IR2104: LM393 / DRV8302: nFAULT)
#if POWER_STAGE == POWER_STAGE_DRV8302
#define DRV_nOCTW_PIN      39   // DRV8302 overcurrent/temp warning (optional monitor)
#endif

// 3-Phase PWM (MCPWM0, A-channels only → DRV8302 3-PWM mode)
#define PWM_A_PIN          25
#define PWM_B_PIN          26
#define PWM_C_PIN          27

// =================================================================================
//  ELECTRICAL DESIGN POINT  (Option A — sim-faithful, locked 2026-05-30)
// =================================================================================
const float Sb     = 100.0f;        // Apparent power base (VA)
const float Vdc    = 40.0f;         // DC link voltage (V) — DRV8302 safe at 40 V
const float V_SET  = 14.0f;         // d-axis voltage setpoint, peak phase (V)
const float f0     = 50.0f;         // Nominal frequency (Hz)
const float omega0 = 314.159265f;   // Nominal speed (rad/s)
const float Ts     = 0.0001f;       // Control period = 100 µs (10 kHz)

// --- AC LC Filter (matches Stage 5c) ---
const float Lf     = 0.0012f;       // Filter inductor (H)   = 1.2 mH
const float Rf     = 0.05f;         // Filter/parasitic resistance (Ω)
const float Cf     = 0.000010f;     // Filter capacitor (F)  = 10 µF
// Rd = 1 Ω damping resistor is PHYSICAL (series with Cf); not represented in code.

// =================================================================================
//  OUTER VSG LOOP  (H-D sweep winner: H=5, D=0.5)
// =================================================================================
const float H_INERTIA   = 5.0f;     // Per-unit inertia constant (s)
const float D_DAMP      = 0.5f;     // Damping coefficient (multiplies ω−ω_s in rad/s)
const float R_P         = 0.05f;    // Active power (P-f) droop, 5 %
const float R_Q         = 0.05f;    // Reactive power (Q-V) droop, 5 %
const float P_BASE      = 100.0f;   // Rated 3-phase active power (W)
const float Q_BASE      = 100.0f;   // Rated 3-phase reactive power (VAR)
const float P_SET_PU    = 1.0f;     // Active power setpoint (pu) → 100 W baseline
const float INERTIA_COEFF = 2.0f * H_INERTIA / omega0;   // 2H/ω_s = 0.0318310
const float Dq          = R_Q * V_SET / Q_BASE;          // Q-V droop gain = 0.007 V/VAR

// =================================================================================
//  CASCADED dq PI GAINS  (computed identically to phase5c_tuned.m)
// =================================================================================
// Inner current loop (1 kHz BW): Kp_i = 2π·1000·Lf, Ki_i = Kp_i·Rf/Lf
const float Kp_i     = 7.5396f;     // = 6283 · Lf            (V/A)
const float Ki_i_Ts  = 0.0314150f;  // = (Kp_i·Rf/Lf) · Ts    (V/A)
const float Vmax     = 20.0f;       // SPWM linear limit = Vdc/2 (V)

// Outer voltage loop (100 Hz BW): Kp_v = 2·0.707·628·Cf, Ki_v = 628²·Cf
const float Kp_v     = 0.00887592f; // (A/V)
const float Ki_v_Ts  = 0.000394384f;// = (628²·Cf) · Ts       (A/V)
const float Iref_max = 10.0f;       // Max current reference amplitude (A)

// =================================================================================
//  SOFTWARE PROTECTION  (Option A current levels: I_d ≈ 4.76 A nom, ~6.5 A on step)
// =================================================================================
const float I_TRIP_LIMIT = 10.0f;   // Instantaneous OC limit (A) — below ±20 A sensor
const float THERMAL_TAU  = 10.0f;   // I²t integration time constant (s)
const float THERMAL_TRIP = 30.0f;   // I²t thermal limit (A²·s) — tune on bench
const float LPF_CUTOFF_HZ = 5.0f;   // Power-measurement LPF cutoff (Hz)

// --- Math constants ---
const float SQRT3      = 1.7320508f;
const float INV_SQRT3  = 0.57735027f;
const float TWO_THIRDS = 0.66666667f;
const float ONE_THIRD  = 0.33333333f;

// --- ADC calibration scales ---
// Voltage divider attenuates ×4 (R1=15k, R2=5k). AD7606 ±10 V range, 16-bit signed.
// actual_volt = raw · (10/32768) · 4 = raw · (40/32768)
const float ADC_LSB_VOLTS   = 10.0f / 32768.0f;   // AD7606 ±10 V range → volts at ADC pin
const float V_DIVIDER_GAIN  = 4.0f;               // precision divider on voltage channels
// ACS712-20A: 100 mV/A, biased at ~2.5 V (5 V VCC). [-05B was 185 mV/A — too small]
const float ACS712_SENSITIVITY   = 0.100f;        // V/A
const float ACS712_NOMINAL_BIAS  = 2.5f;          // V — replaced by boot auto-zero
const float ACS712_BIAS_TOLERANCE = 0.3f;         // V — halt if measured offset outside

// --- SPI clock: AD7606 max SCLK is lower at V_DRIVE = 3.3 V than at 5 V.
//     15 MHz is a margin pick — VERIFY against the datasheet timing table.
const uint32_t AD7606_SPI_HZ = 15000000;

// =================================================================================
//  SHARED INTER-CORE TELEMETRY
// =================================================================================
struct TelemetryData {
    float ia, ib, ic;
    float va, vb, vc;
    float P, Q;
    float omega;
    float theta;
    float E;
    uint32_t execution_time_us;
    uint32_t overrun_count;
    bool fault_state;
    const char* state_str;
};

TelemetryData shared_telemetry;     // guarded by spinlock (critical sections imply barriers)
portMUX_TYPE spinlock = portMUX_INITIALIZER_UNLOCKED;

// --- System state machine ---
enum SystemState {
    STATE_INIT = 0,
    STATE_STANDBY,
    STATE_SOFT_START,
    STATE_RUNNING,
    STATE_FAULT
};
volatile SystemState current_state = STATE_INIT;

// =================================================================================
//  CONTROLLER STATE (persistent in RAM — touched ONLY by the control task)
// =================================================================================
float vsg_omega = 314.159265f;      // Virtual rotor speed (rad/s), init at ω_s
float vsg_theta = 0.0f;             // Virtual rotor angle (rad)
float vsg_P_filt = 0.0f;            // Filtered active power (W)
float vsg_Q_filt = 0.0f;            // Filtered reactive power (VAR)
float E_ramp = 0.0f;                // Soft-start EMF ramp (V)

// PI integrators
float id_integrator = 0.0f;
float iq_integrator = 0.0f;
float vd_integrator = 0.0f;
float vq_integrator = 0.0f;

// Protection
float thermal_accumulator = 0.0f;

// ACS712 per-channel bias, measured at boot (auto-zero); nominal until calibrated
float i_bias_v[3] = { ACS712_NOMINAL_BIAS, ACS712_NOMINAL_BIAS, ACS712_NOMINAL_BIAS };

// Loop bookkeeping
uint32_t loop_counter = 0;
uint32_t overrun_count = 0;         // timer ticks missed while control step was late

// Hardware SPI instance
SPIClass* hspi = nullptr;

// Control task handle — the timer ISR notifies this task every 100 µs
TaskHandle_t control_task_handle = nullptr;

// --- Forward declarations ---
void trigger_hardware_trip();
void init_pwm();
void init_external_adc();
void init_gpio();
bool calibrate_current_offsets();
inline void read_ad7606_volts(float ch_volts[6]);
inline void read_measurements(float &ia, float &ib, float &ic, float &va, float &vb, float &vc);

// =================================================================================
//  CLARKE / PARK TRANSFORMS (amplitude-invariant)
// =================================================================================
inline void clarke_transform(float a, float b, float c, float &alpha, float &beta) {
    alpha = TWO_THIRDS * a - ONE_THIRD * (b + c);
    beta  = (b - c) * INV_SQRT3;
}

inline void park_transform(float alpha, float beta, float theta, float &d, float &q) {
    float cos_t = cosf(theta);
    float sin_t = sinf(theta);
    d =  alpha * cos_t + beta * sin_t;
    q = -alpha * sin_t + beta * cos_t;
}

inline void inv_park_transform(float d, float q, float theta, float &alpha, float &beta) {
    float cos_t = cosf(theta);
    float sin_t = sinf(theta);
    alpha = d * cos_t - q * sin_t;
    beta  = d * sin_t + q * cos_t;
}

// =================================================================================
//  SPWM (sinusoidal) — matches verified sim. Linear range |v_phase| ≤ Vdc/2.
// =================================================================================
inline void spwm(float v_alpha, float v_beta, float vdc, float &da, float &db, float &dc) {
    // Inverse Clarke → phase voltage references
    float va = v_alpha;
    float vb = -0.5f * v_alpha + (SQRT3 * 0.5f) * v_beta;
    float vc = -0.5f * v_alpha - (SQRT3 * 0.5f) * v_beta;

    // SPWM duty: duty = 0.5 + v_phase / Vdc
    da = 0.5f + va / vdc;
    db = 0.5f + vb / vdc;
    dc = 0.5f + vc / vdc;

    // Safety clamp (keeps off the rails; m=0.70 design stays well inside)
    da = constrain(da, 0.03f, 0.97f);
    db = constrain(db, 0.03f, 0.97f);
    dc = constrain(dc, 0.03f, 0.97f);
}

// =================================================================================
//  10 kHz TIMER ISR — notify-only (FPU-safe: NO float math, NO flash calls here)
// =================================================================================
void IRAM_ATTR onControlTimer() {
    BaseType_t hp_task_woken = pdFALSE;
    vTaskNotifyGiveFromISR(control_task_handle, &hp_task_woken);
    if (hp_task_woken == pdTRUE) portYIELD_FROM_ISR();
}

// =================================================================================
//  CONTROL STEP — runs in the max-priority Core-1 task, once per timer tick
// =================================================================================
void control_step() {
    uint32_t start_cycles = ESP.getCycleCount();
    loop_counter++;

    // L1 backup poll of the OCP line (L0 = MCPWM hardware fault, already armed).
    // Active LOW: LM393 (A) / nFAULT (B). Requires the external pull-up (GPIO34!).
#if !DRY_RUN_NO_POWER_STAGE
    if (digitalRead(OCP_FAULT_PIN) == LOW) {
        current_state = STATE_FAULT;
        trigger_hardware_trip();
        return;
    }
#endif
    if (current_state == STATE_FAULT) {
        trigger_hardware_trip();
        return;
    }

    // 1. Simultaneous AD7606 sample
    float ia, ib, ic;
    float va, vb, vc;
    read_measurements(ia, ib, ic, va, vb, vc);

    // 2. Protection — L2: instantaneous overcurrent
    if (fabsf(ia) > I_TRIP_LIMIT || fabsf(ib) > I_TRIP_LIMIT || fabsf(ic) > I_TRIP_LIMIT) {
        current_state = STATE_FAULT;
        trigger_hardware_trip();
        return;
    }
    // Protection — L3: I²t thermal accumulator
    float i_sq_avg = ONE_THIRD * (ia*ia + ib*ib + ic*ic);
    thermal_accumulator += Ts * (i_sq_avg - (thermal_accumulator / THERMAL_TAU));
    if (thermal_accumulator > THERMAL_TRIP) {
        current_state = STATE_FAULT;
        trigger_hardware_trip();
        return;
    }

    if (current_state == STATE_SOFT_START || current_state == STATE_RUNNING) {
        // A. Transform measured i_abc, v_abc → dq (using virtual angle θ)
        float i_alpha, i_beta, id, iq;
        float v_alpha, v_beta, vd, vq;
        clarke_transform(ia, ib, ic, i_alpha, i_beta);
        park_transform(i_alpha, i_beta, vsg_theta, id, iq);
        clarke_transform(va, vb, vc, v_alpha, v_beta);
        park_transform(v_alpha, v_beta, vsg_theta, vd, vq);

        // B. Power calc (amplitude-invariant Park → 3/2 factor) + 5 Hz LPF
        float P_raw = 1.5f * (vd * id + vq * iq);
        float Q_raw = 1.5f * (vq * id - vd * iq);
        // K_lpf = (ω_c·Ts)/(1+ω_c·Ts), ω_c = 2π·5 = 31.4159 → K_lpf = 0.00313176
        const float K_lpf = 0.00313176f;
        vsg_P_filt += K_lpf * (P_raw - vsg_P_filt);
        vsg_Q_filt += K_lpf * (Q_raw - vsg_Q_filt);

        float omega = omega0;
        float E = V_SET;

        // C. State machine: soft-start ramp vs running VSG dynamics
        if (current_state == STATE_SOFT_START) {
            // Ramp E from 0 → V_SET over 2.0 s (20,000 steps) at constant 50 Hz
            E_ramp += (V_SET / 20000.0f);
            if (E_ramp >= V_SET) {
                E_ramp = V_SET;
                current_state = STATE_RUNNING;
            }
            E = E_ramp;
            omega = omega0;
            vsg_omega = omega0;     // hold rotor at synchronous during ramp
        }
        else { // STATE_RUNNING
            // --- VSG swing equation + P-f droop (forward Euler, 10 kHz) ---
            // inertia_coeff·dω/dt = [P_set_pu + (1−ω/ω_s)/R_p] − P_e_pu − D·(ω−ω_s)
            float Pe_pu = vsg_P_filt / P_BASE;
            float w_pu  = vsg_omega / omega0;
            float Pm_pu = P_SET_PU + (1.0f - w_pu) / R_P;          // primary freq response
            float dwdt  = (Pm_pu - Pe_pu - D_DAMP * (vsg_omega - omega0)) / INERTIA_COEFF;
            vsg_omega  += dwdt * Ts;
            omega = vsg_omega;

            // --- Q-V droop ---
            E = V_SET - Dq * vsg_Q_filt;
        }

        // D. Integrate virtual rotor angle (forward Euler at 10 kHz)
        vsg_theta += omega * Ts;
        if (vsg_theta >= 2.0f * M_PI) vsg_theta -= 2.0f * M_PI;
        else if (vsg_theta < 0.0f)    vsg_theta += 2.0f * M_PI;

        // E. Outer voltage PI (dq) + capacitor-current decoupling
        float vd_ref = E;
        float vq_ref = 0.0f;
        float ev_d = vd_ref - vd;
        float ev_q = vq_ref - vq;
        // i_cap decoupling: i_cap_d = −ω·Cf·v_q, i_cap_q = +ω·Cf·v_d
        float id_ref = Kp_v * ev_d + vd_integrator - (omega * Cf * vq);
        float iq_ref = Kp_v * ev_q + vq_integrator + (omega * Cf * vd);

        // Saturate current reference (protect MOSFETs)
        float I_ref_mag = sqrtf(id_ref*id_ref + iq_ref*iq_ref);
        bool volt_saturated = false;
        if (I_ref_mag > Iref_max) {
            volt_saturated = true;
            id_ref *= (Iref_max / I_ref_mag);
            iq_ref *= (Iref_max / I_ref_mag);
        }
        // Voltage integrators — conditional anti-windup
        if (!volt_saturated || (ev_d * vd_integrator < 0.0f)) vd_integrator += Ki_v_Ts * ev_d;
        if (!volt_saturated || (ev_q * vq_integrator < 0.0f)) vq_integrator += Ki_v_Ts * ev_q;

        // F. Inner current PI (dq) + dq decoupling FF + load-voltage FF (Stage 5c)
        float ed = id_ref - id;
        float eq = iq_ref - iq;
        float ud_pi = Kp_i * ed + id_integrator;
        float uq_pi = Kp_i * eq + iq_integrator;
        // v_inv_d = u_pi_d − ω·Lf·i_q + v_load_d
        // v_inv_q = u_pi_q + ω·Lf·i_d + v_load_q
        float decouple = omega * Lf;
        float vd_cmd = ud_pi - decouple * iq + vd;
        float vq_cmd = uq_pi + decouple * id + vq;

        // Saturate command voltage to linear SPWM radius
        float V_cmd_mag = sqrtf(vd_cmd*vd_cmd + vq_cmd*vq_cmd);
        bool curr_saturated = false;
        if (V_cmd_mag > Vmax) {
            curr_saturated = true;
            vd_cmd *= (Vmax / V_cmd_mag);
            vq_cmd *= (Vmax / V_cmd_mag);
        }
        // Current integrators — conditional anti-windup
        if (!curr_saturated || (ed * ud_pi < 0.0f)) id_integrator += Ki_i_Ts * ed;
        if (!curr_saturated || (eq * uq_pi < 0.0f)) iq_integrator += Ki_i_Ts * eq;

        // G. Inverse Park → SPWM duty cycles
        float v_cmd_alpha, v_cmd_beta;
        inv_park_transform(vd_cmd, vq_cmd, vsg_theta, v_cmd_alpha, v_cmd_beta);
        float duty_a, duty_b, duty_c;
        spwm(v_cmd_alpha, v_cmd_beta, Vdc, duty_a, duty_b, duty_c);

        // H. Write duty to MCPWM (A-channels → DRV8302 3-PWM mode)
        mcpwm_set_duty(MCPWM_UNIT_0, MCPWM_TIMER_0, MCPWM_OPR_A, duty_a * 100.0f);
        mcpwm_set_duty(MCPWM_UNIT_0, MCPWM_TIMER_1, MCPWM_OPR_A, duty_b * 100.0f);
        mcpwm_set_duty(MCPWM_UNIT_0, MCPWM_TIMER_2, MCPWM_OPR_A, duty_c * 100.0f);

        // I. Publish telemetry snapshot (~100 Hz: every 100th step)
        if (loop_counter % 100 == 0) {
            const char* state_name = (current_state == STATE_SOFT_START) ? "SOFT_START" : "RUNNING";
            portENTER_CRITICAL(&spinlock);
            shared_telemetry.ia = ia; shared_telemetry.ib = ib; shared_telemetry.ic = ic;
            shared_telemetry.va = va; shared_telemetry.vb = vb; shared_telemetry.vc = vc;
            shared_telemetry.P = vsg_P_filt;
            shared_telemetry.Q = vsg_Q_filt;
            shared_telemetry.omega = omega;
            shared_telemetry.theta = vsg_theta;
            shared_telemetry.E = E;
            shared_telemetry.execution_time_us = (ESP.getCycleCount() - start_cycles) / 240;
            shared_telemetry.overrun_count = overrun_count;
            shared_telemetry.fault_state = false;
            shared_telemetry.state_str = state_name;
            portEXIT_CRITICAL(&spinlock);
        }
    }
}

// =================================================================================
//  CONTROL TASK — Core 1, max priority; woken by the 10 kHz timer ISR
// =================================================================================
void controlTask(void* parameter) {
    while (true) {
        // Blocks until the ISR notifies. A count > 1 means we missed tick(s).
        uint32_t notif_count = ulTaskNotifyTake(pdTRUE, portMAX_DELAY);
        if (notif_count > 1) overrun_count += (notif_count - 1);
        control_step();
    }
}

// =================================================================================
//  EMERGENCY SAFE SHUTDOWN  (task context)
// =================================================================================
void trigger_hardware_trip() {
    // 0. (already done in silicon if L0 tripped: MCPWM one-shot fault latched low)
    // 1. Force all MCPWM outputs low
    mcpwm_set_signal_low(MCPWM_UNIT_0, MCPWM_TIMER_0, MCPWM_OPR_A);
    mcpwm_set_signal_low(MCPWM_UNIT_0, MCPWM_TIMER_1, MCPWM_OPR_A);
    mcpwm_set_signal_low(MCPWM_UNIT_0, MCPWM_TIMER_2, MCPWM_OPR_A);
    // 2. Physically disable all IR2104 gate drivers (common SD/enable line)
    digitalWrite(EN_GATE_PIN, LOW);
    // 3. Latch fault
    current_state = STATE_FAULT;
    portENTER_CRITICAL(&spinlock);
    shared_telemetry.fault_state = true;
    shared_telemetry.state_str = "FAULT";
    portEXIT_CRITICAL(&spinlock);
}

// =================================================================================
//  HARDWARE INIT
// =================================================================================
void init_gpio() {
    pinMode(EN_GATE_PIN, OUTPUT);
    digitalWrite(EN_GATE_PIN, LOW);          // gate drivers disabled on boot (verify SD polarity for IR2104)
    // GPIO34 is input-only, NO internal pull-up exists — plain INPUT.
    // The required 10 kΩ pull-up to 3.3 V must be ON THE BOARD (LM393 is open-collector).
    pinMode(OCP_FAULT_PIN, INPUT);
#if POWER_STAGE == POWER_STAGE_DRV8302
    pinMode(DRV_nOCTW_PIN, INPUT_PULLUP);    // GPIO39 also has no internal pull-up — external required too
#endif
}

void init_pwm() {
    // MCPWM0 A-channels only → one PWM per IR2104 (each makes complement + ~520ns dead-time)
    mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM0A, PWM_A_PIN);
    mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM1A, PWM_B_PIN);
    mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM2A, PWM_C_PIN);

    mcpwm_config_t pwm_config;
    pwm_config.frequency    = 10000;                  // 10 kHz switching (matches sim)
    // NOTE: verify actual frequency on a scope — some IDF releases halve the
    // output frequency in up-down (center-aligned) mode. If you measure 5 kHz,
    // set frequency = 20000.
    pwm_config.cmpr_a       = 50.0;                   // 50 % initial duty
    pwm_config.cmpr_b       = 50.0;
    pwm_config.counter_mode = MCPWM_UP_DOWN_COUNTER;  // center-aligned (symmetric)
    pwm_config.duty_mode    = MCPWM_DUTY_MODE_0;      // active-high

    mcpwm_init(MCPWM_UNIT_0, MCPWM_TIMER_0, &pwm_config);
    mcpwm_init(MCPWM_UNIT_0, MCPWM_TIMER_1, &pwm_config);
    mcpwm_init(MCPWM_UNIT_0, MCPWM_TIMER_2, &pwm_config);

#if !DRY_RUN_NO_POWER_STAGE
    // L0 HARDWARE FAULT: LM393/nFAULT (active LOW) → MCPWM fault F0.
    // One-shot mode: on trigger, silicon forces all outputs LOW and LATCHES
    // until reboot (mcpwm_fault_deinit would clear it — we deliberately don't).
    // Latency <1 µs, no CPU involvement — matches power_stage_options.md.
    mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM_FAULT_0, OCP_FAULT_PIN);
    mcpwm_fault_init(MCPWM_UNIT_0, MCPWM_LOW_LEVEL_TGR, MCPWM_SELECT_F0);
    mcpwm_fault_set_oneshot_mode(MCPWM_UNIT_0, MCPWM_TIMER_0, MCPWM_SELECT_F0,
                                 MCPWM_ACTION_FORCE_LOW, MCPWM_ACTION_FORCE_LOW);
    mcpwm_fault_set_oneshot_mode(MCPWM_UNIT_0, MCPWM_TIMER_1, MCPWM_SELECT_F0,
                                 MCPWM_ACTION_FORCE_LOW, MCPWM_ACTION_FORCE_LOW);
    mcpwm_fault_set_oneshot_mode(MCPWM_UNIT_0, MCPWM_TIMER_2, MCPWM_SELECT_F0,
                                 MCPWM_ACTION_FORCE_LOW, MCPWM_ACTION_FORCE_LOW);
#endif
}

void init_external_adc() {
    pinMode(AD7606_CS_PIN, OUTPUT);
    pinMode(AD7606_CONVST_PIN, OUTPUT);
    pinMode(AD7606_BUSY_PIN, INPUT);
    digitalWrite(AD7606_CS_PIN, HIGH);
    digitalWrite(AD7606_CONVST_PIN, HIGH);

    hspi = new SPIClass(HSPI);
    hspi->begin(SPI_SCK_PIN, SPI_MISO_PIN, SPI_MOSI_PIN, AD7606_CS_PIN);
    // Bus is exclusive to the AD7606 → hold the transaction open permanently.
    hspi->beginTransaction(SPISettings(AD7606_SPI_HZ, MSBFIRST, SPI_MODE0));
}

// AD7606 simultaneous conversion + SPI read → volts AT THE ADC PIN for ch 1-6
// (channels 1-3 = ACS712 outputs, channels 4-6 = divided phase voltages)
inline void read_ad7606_volts(float ch_volts[6]) {
    // 1. Trigger conversion on all 8 channels (CONVST low pulse)
    digitalWrite(AD7606_CONVST_PIN, LOW);
    asm volatile("nop; nop; nop;");
    digitalWrite(AD7606_CONVST_PIN, HIGH);

    // 2. Wait for BUSY low (with timeout)
    int timeout = 1000;
    while (digitalRead(AD7606_BUSY_PIN) == HIGH && timeout > 0) timeout--;

    // 3. Read 6 channels (12 bytes, MSB-first)
    uint8_t raw_bytes[12] = {0};
    digitalWrite(AD7606_CS_PIN, LOW);
    hspi->transferBytes(nullptr, raw_bytes, 12);
    digitalWrite(AD7606_CS_PIN, HIGH);

    for (int ch = 0; ch < 6; ch++) {
        int16_t raw = (int16_t)((raw_bytes[2*ch] << 8) | raw_bytes[2*ch + 1]);
        ch_volts[ch] = (float)raw * ADC_LSB_VOLTS;
    }
}

// Scaled measurements: phase currents (A) with per-channel auto-zeroed bias,
// phase voltages (V) through the ×4 divider.
inline void read_measurements(float &ia, float &ib, float &ic, float &va, float &vb, float &vc) {
    float v[6];
    read_ad7606_volts(v);

    ia = (v[0] - i_bias_v[0]) / ACS712_SENSITIVITY;
    ib = (v[1] - i_bias_v[1]) / ACS712_SENSITIVITY;
    ic = (v[2] - i_bias_v[2]) / ACS712_SENSITIVITY;

    va = v[3] * V_DIVIDER_GAIN;
    vb = v[4] * V_DIVIDER_GAIN;
    vc = v[5] * V_DIVIDER_GAIN;

#if DRY_RUN_NO_POWER_STAGE
    // Bare-board timing test: SPI read above keeps the timing realistic,
    // but feed the control math clean zeros instead of floating-pin garbage.
    ia = ib = ic = 0.0f;
    va = vb = vc = 0.0f;
#endif
}

// =================================================================================
//  ACS712 AUTO-ZERO — measure per-channel bias at boot (gates disabled, I = 0)
// =================================================================================
bool calibrate_current_offsets() {
    const int N_SAMPLES = 500;
    float sum[3] = { 0.0f, 0.0f, 0.0f };

    for (int k = 0; k < N_SAMPLES; k++) {
        float v[6];
        read_ad7606_volts(v);
        sum[0] += v[0];
        sum[1] += v[1];
        sum[2] += v[2];
        delayMicroseconds(200);     // ~5 kHz sampling → 100 ms total
    }

    bool ok = true;
    for (int ch = 0; ch < 3; ch++) {
        i_bias_v[ch] = sum[ch] / (float)N_SAMPLES;
        Serial.printf("  ACS712 ch%d bias = %.4f V (nominal %.1f V)\n",
                      ch + 1, i_bias_v[ch], ACS712_NOMINAL_BIAS);
        if (fabsf(i_bias_v[ch] - ACS712_NOMINAL_BIAS) > ACS712_BIAS_TOLERANCE) {
            Serial.printf("  !! ch%d bias out of range (±%.1f V) — sensor missing/miswired?\n",
                          ch + 1, ACS712_BIAS_TOLERANCE);
            ok = false;
        }
    }
    return ok;
}

// =================================================================================
//  CORE 0 TELEMETRY TASK (10 Hz print rate; snapshot updated at 100 Hz)
// =================================================================================
void telemetryTask(void* parameter) {
    while (true) {
        TelemetryData local_data;
        portENTER_CRITICAL(&spinlock);
        local_data = shared_telemetry;
        portEXIT_CRITICAL(&spinlock);

#if DRY_RUN_NO_POWER_STAGE
        Serial.println("[DRY-RUN] Gates disabled, protection bypassed — DO NOT connect a power stage.");
#endif
        if (local_data.fault_state) {
            Serial.println("!!! [EMERGENCY TRIP] OVERCURRENT / HARDWARE FAULT LATCHED !!!");
            Serial.println("Action: power down DC bus, check load + star grounding, then reset.");
        } else {
            Serial.printf("State: %s | P: %.2f W | Q: %.2f VAR | Freq: %.3f Hz | E: %.2f V\n",
                          local_data.state_str ? local_data.state_str : "INIT",
                          local_data.P, local_data.Q,
                          local_data.omega / (2.0f * M_PI), local_data.E);
            Serial.printf("  V_abc: [%.2f, %.2f, %.2f] V | I_abc: [%.3f, %.3f, %.3f] A | step: %u us | overruns: %u\n",
                          local_data.va, local_data.vb, local_data.vc,
                          local_data.ia, local_data.ib, local_data.ic,
                          local_data.execution_time_us, local_data.overrun_count);
        }
        vTaskDelay(pdMS_TO_TICKS(100));   // 10 Hz
    }
}

// =================================================================================
//  SETUP
// =================================================================================
hw_timer_t* ctrl_timer = nullptr;

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.println("==========================================================");
    Serial.println("  ESP32 Grid-Forming VSG — Option A (40V / 14V / 1.2mH-10uF)");
    Serial.println("  Refactor 2026-07-02: task-based control, HW MCPWM fault");
#if DRY_RUN_NO_POWER_STAGE
    Serial.println("  *** DRY-RUN BUILD — gates disabled, no protection armed ***");
#endif
    Serial.println("==========================================================");

    init_gpio();
    init_pwm();
    init_external_adc();

    current_state = STATE_STANDBY;
    Serial.println("STANDBY — settling power rails...");
    delay(2000);

#if !DRY_RUN_NO_POWER_STAGE
    // Auto-zero the current sensors while the gates are still disabled (I = 0)
    Serial.println("Calibrating ACS712 offsets (gates disabled)...");
    if (!calibrate_current_offsets()) {
        current_state = STATE_FAULT;
        Serial.println("CALIBRATION FAILED — halting in FAULT. Fix sensing, then reset.");
        while (true) vTaskDelay(pdMS_TO_TICKS(1000));
    }
#endif

    // Telemetry task → Core 0
    xTaskCreatePinnedToCore(telemetryTask, "TelemetryTask", 4096, NULL, 1, NULL, 0);

    // Control task → Core 1, max priority. MUST exist before the timer starts.
    xTaskCreatePinnedToCore(controlTask, "VSGControl", 8192, NULL,
                            configMAX_PRIORITIES - 1, &control_task_handle, 1);

#if !DRY_RUN_NO_POWER_STAGE
    // Enable IR2104 gate drivers (common SD/enable; verify polarity)
    digitalWrite(EN_GATE_PIN, HIGH);
    delay(10);   // let bootstrap caps charge
#endif

    current_state = STATE_SOFT_START;
    Serial.println("BLACK-START: 2-second soft EMF ramp (0 -> 14 V) at 50 Hz...");

    // 10 kHz hardware timer (1 MHz tick, alarm every 100 ticks = 100 µs).
    // setup() runs on Core 1 → the timer ISR is allocated on Core 1.
    ctrl_timer = timerBegin(0, 80, true);
    timerAttachInterrupt(ctrl_timer, &onControlTimer, true);
    timerAlarmWrite(ctrl_timer, 100, true);
    timerAlarmEnable(ctrl_timer);
}

void loop() {
    // Core 1: timer ISR → VSGControl task (prio 24). Core 0: telemetry. Idle here.
    vTaskDelay(portMAX_DELAY);
}
