/**
 * ==================================================================================
 *   Virtual Synchronous Generator (VSG) — Pure Islanded (Grid-Forming) Controller
 * ==================================================================================
 *
 *   DESIGN POINT: **Option A (sim-faithful)** — locked 2026-05-30
 *   Control equations derived from Stage 5c; hardware equivalence is NOT verified.
 *   Compare measured waveforms with the validated Stage 5d switching model.
 *
 *   HARDENING 2026-10-13 (software validation only; no flash / powered bench):
 *     - Explicit PWM generator restore, synchronized phase carriers.
 *     - Control-task-owned protected bootstrap; FAULT is absorbing until reset.
 *     - ADC BUSY assertion/completion handshake, SPI mode 2, deadline trips.
 *     - Real-power build locked pending documented board qualification.
 *   See docs/notes/firmware_validation_2026-10-13.md and
 *       docs/notes/hardware_shutdown_and_bench_plan.md.
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
 *     4. MCPWM OCP PATH: LM393 (active-LOW) drives the MCPWM fault input
 *        (one-shot, forces PWM IN low). This is a brake, NOT both-gates-off
 *        IR2104 shutdown. An independent latched /SD path is mandatory.
 *        End-to-end shutdown latency is unmeasured; no <1 us claim is made.
 *     5. ACS712 AUTO-ZERO: per-channel current-sensor offsets are measured at
 *        boot (500 samples, gates disabled) instead of assuming exactly 2.5 V.
 *        Boot halts in FAULT if any offset deviates > ±0.3 V from nominal.
 *     6. SPI CLOCK: 15 MHz nominal; qualify the actual AD7606 module and
 *        V_DRIVE against its datasheet timing and a logic-analyzer capture.
 *     7. TOOLCHAIN PIN: compile-time guard requires arduino-esp32 core 2.x
 *        (legacy driver/mcpwm.h + old hw_timer API are removed in core 3.x).
 *        Tested against core 2.0.17.
 *
 *   ------------------------------------------------------------------------------
 *   REVIEW 2026-07-02 -> FIXES 2026-07-26 (cross-model review: gpt-5.5 + Gemini):
 *     A. L3 THERMAL LIMIT WAS A GUARANTEED NUISANCE TRIP. The old accumulator
 *        integrated i_sq_avg itself with a TAU decay, settling at
 *        i_sq_avg*TAU = 11.34*10 ~ 113 A^2*s at RATED load, against a 30 A^2*s
 *        limit -> a healthy prototype tripped ~3.1 s after entering RUNNING.
 *        Now an OVERLOAD integral: only current squared IN EXCESS of rated
 *        accumulates, floored at zero, so rated load never accumulates.
 *     B. ADC BUSY TIMEOUT WAS IGNORED. read_ad7606_volts() spun up to ~200 µs
 *        (2 control periods) on an iteration counter and then read the SPI bus
 *        anyway, feeding garbage into the control math with no trip. Now a
 *        wall-clock timeout that returns false and forces FAULT.
 *     C. GATE-ENABLE SEQUENCING. EN_GATE went HIGH (+10 ms) BEFORE the control
 *        loop existed, with the generators still at the cmpr_a = 50 % init
 *        value -> open-loop switching on a live bus. Outputs are now parked LOW
 *        in init_pwm(), the control loop starts first (STANDBY writes no duty),
 *        the fault line is checked, and only then are the drivers enabled.
 *     D. SUB-100 µs FAULTS WERE INVISIBLE TO SOFTWARE. The silicon latches in
 *        <1 µs, but a comparator pulse shorter than one control period is gone
 *        by the next digitalRead() -> gates dead while the firmware still
 *        reported RUNNING and kept winding up its integrators. The one-shot
 *        latch is now read directly (operators[op].fh_status.fh_ost_on).
 *        The public legacy API has no status call; clearing that latch needs a
 *        posedge on fh_clr_ost, so mcpwm_set_duty() CANNOT clear it (verified
 *        against hal/esp32/mcpwm_ll.h in core 2.0.17).
 *     E. GPIO39 repeated the GPIO34 mistake: INPUT_PULLUP is a silent no-op on
 *        34-39. Now plain INPUT (DRV8302 branch only).
 *     F. Control-task creation is now checked; a failure halts with gates LOW
 *        instead of letting the ISR notify a null task handle.
 *   ------------------------------------------------------------------------------
 *
 *   DRY-RUN MODE (first flash on a bare ESP32, no power stage attached):
 *     Set DRY_RUN_NO_POWER_STAGE to 1. This (a) skips ACS712 calibration,
 *     (b) skips the MCPWM hardware-fault hookup (GPIO34 floats on a bare board
 *     and would instantly latch), (c) zeroes the measured i/v so the control
 *     math runs on clean inputs, and (d) KEEPS EN_GATE LOW at all times.
 *     Use it to verify loop timing (execution_time_us) and scope the PWM pins.
 *     Keep DRY_RUN=1 until ALL qualification gates and the bench plan pass.
 *     Setting DRY_RUN=0 alone intentionally fails compilation.
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
 *     - DC bus            Vdc    = 40 V nominal model input; NOT measured here.
 *       External UV/OV, source-return-energy and supply-limit protection required.
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
 *          L0: independent latched driver /SD shutdown (board qualification)
 *          L0b: MCPWM fault (LM393 → F0, one-shot force-low brake)
 *          L1: software GPIO poll of the same line (backup, ≤100 µs)
 *          L2: software instantaneous OC trip
 *          L3: I²t thermal accumulator
 *
 *   POWER STAGE NOTE (3× IR2104, one per half-bridge leg):
 *     Drive 3 MCPWM A-channels only — one PWM into each IR2104 IN pin. Each
 *     IR2104 generates the complementary HO/LO pair with a fixed internal
 *     dead-time (~520 ns), so NO MCPWM dead-time is needed. IR2104 is a
 *     bootstrap (non-isolated) driver — acceptable at 40 V benchtop, but keep
 *     hands off live conductors. GPIO22 requests an external latched permit;
 *     only the qualified AND/permit circuit drives the three active-LOW /SD pins.
 *
 *   FIRMWARE-vs-SIM VALIDATION:
 *     Control gains below are computed from the SAME formulas as phase5c_tuned.m.
 *     Compare actual bench ω(t), P(t), ripple and fault timing against Stage 5d
 *     using matched signals and bandwidth; synthetic tests are not HIL evidence.
 *
 *   Pin mapping is a PROPOSED assignment — verify against your shield/wiring.
 *
 *   Developed for Chinnawat (Napoleon), Suranaree University of Technology (SUT).
 * ==================================================================================
 */

#include <Arduino.h>
#include <SPI.h>
#include <esp_arduino_version.h>
#include <esp_timer.h>
#include <driver/mcpwm.h>
#include <soc/mcpwm_struct.h>   // MCPWM0 register block — used to read the one-shot fault latch
#include "safety_policy.h"

#if !defined(CONFIG_IDF_TARGET_ESP32)
#error "This board mapping and MCPWM register path are qualified only for original ESP32."
#endif

// ---- Toolchain guard: legacy MCPWM + hw_timer APIs used below exist only in 2.x
#if ESP_ARDUINO_VERSION < ESP_ARDUINO_VERSION_VAL(2, 0, 0) || \
    ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 0)
#error "This firmware requires arduino-esp32 core 2.x (tested on 2.0.17). Core 3.x removed driver/mcpwm.h and changed the hw_timer API."
#endif

// =================================================================================
//  BUILD MODE — see DRY-RUN note in the header
// =================================================================================
#ifndef DRY_RUN_NO_POWER_STAGE
#define DRY_RUN_NO_POWER_STAGE  1   // Default: bare-ESP32, gate request ALWAYS LOW.
#endif

// These are evidence acknowledgements, not a substitute for the hardware.
// Keep them 0 until the exact assembled board passes the documented tests.
#ifndef VSG_EXTERNAL_SHUTDOWN_VERIFIED
#define VSG_EXTERNAL_SHUTDOWN_VERIFIED 0
#endif
#ifndef VSG_ADC_RESET_AND_STRAPS_VERIFIED
#define VSG_ADC_RESET_AND_STRAPS_VERIFIED 0
#endif
#ifndef VSG_BOARD_WIRING_VERIFIED
#define VSG_BOARD_WIRING_VERIFIED 0
#endif
#ifndef VSG_DC_BUS_PROTECTION_VERIFIED
#define VSG_DC_BUS_PROTECTION_VERIFIED 0
#endif
#if DRY_RUN_NO_POWER_STAGE != 0 && DRY_RUN_NO_POWER_STAGE != 1
#error "DRY_RUN_NO_POWER_STAGE must be 0 or 1."
#endif
#if !DRY_RUN_NO_POWER_STAGE && (!VSG_EXTERNAL_SHUTDOWN_VERIFIED || \
    !VSG_ADC_RESET_AND_STRAPS_VERIFIED || !VSG_BOARD_WIRING_VERIFIED || \
    !VSG_DC_BUS_PROTECTION_VERIFIED)
#error "REAL POWER LOCKED: qualify latched shutdown, ADC reset/straps, board wiring, and independent DC-bus protection."
#endif

// =================================================================================
//  POWER STAGE SELECTION
//  The control core is IDENTICAL for both stages — only the gate-driver semantics
//  differ. Both drive 3 MCPWM A-channels + 1 enable line + 1 fault input.
//  Full comparison: docs/notes/power_stage_options.md
// =================================================================================
#define POWER_STAGE_IR2104   1   // A: discrete 6x IRF540N + 3x IR2104 (budget)
#define POWER_STAGE_DRV8302  2   // B: TI DRV8302 shield (integrated protection)
#ifndef POWER_STAGE
#define POWER_STAGE  POWER_STAGE_IR2104     // Default A; explicit build override allowed.
#endif
#if POWER_STAGE != POWER_STAGE_IR2104 && POWER_STAGE != POWER_STAGE_DRV8302
#error "Unsupported POWER_STAGE: select POWER_STAGE_IR2104 or POWER_STAGE_DRV8302."
#endif

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
// IR2104 /SD is ACTIVE LOW: LOW disables BOTH HO/LO (datasheet p5, Figs 1/3).
// GPIO22 is only a REQUEST into an external fault-latched permit/AND circuit.
// It must never bypass the comparator shutdown or drive against its output.
// !! GPIO34 is input-only and has NO internal pull-up. LM393 output is
// !! open-collector → EXTERNAL 10 kΩ pull-up to 3.3 V is REQUIRED on the board.
#define EN_GATE_PIN        22   // gate-driver enable (remapped off GPIO12-MISO)
#define OCP_FAULT_PIN      34   // input-only, active LOW (IR2104: LM393 / DRV8302: nFAULT)
const uint8_t GATE_DISABLED = LOW;
const uint8_t GATE_REQUESTED = HIGH;
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
const float Vdc    = 40.0f;         // Nominal model value; no runtime Vdc sensor exists.
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
// L3 is an OVERLOAD integral, not an absolute I²t. It accumulates only the current
// squared IN EXCESS of rated, so a healthy machine never accumulates at all.
//   rated per-phase peak  I_pk = P_BASE/(1.5·V_SET) = 100/(1.5·14) = 4.762 A
//   mean of squares at rated   = I_pk²/2            = 11.34 A²
// The previous form integrated i_sq_avg itself with a TAU decay and settled at
// i_sq_avg·TAU ≈ 113 A²·s at rated, tripping a 30 A²·s limit ~3.1 s into RUNNING.
const float I_SQ_RATED   = 11.34f;  // A² — mean of squares of the 3 phases at rated load
const float THERMAL_TRIP = 20.0f;   // A²·s of EXCESS energy above rated — tune on bench
                                    //   1.5× rated current → trip in ~1.4 s
                                    //   2.0× rated current → trip in ~0.6 s
                                    // (L2 catches anything above 10 A instantly)
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

// BUSY-wait ceiling for one conversion. The AD7606 finishes in a few µs — VERIFY
// t_CONV in the datasheet for your oversampling setting. 50 µs is half the 100 µs
// control period, so hitting it means the ADC is absent or wedged, not merely slow.
const uint32_t ADC_BUSY_TIMEOUT_US = 50;
const uint32_t ADC_ASSERT_TIMEOUT_US = 5;
const uint32_t CONTROL_BUDGET_US = 90; // 10 us reserved within the 100 us period.

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
    uint32_t max_execution_time_us;
    uint32_t max_response_time_us;
    uint32_t overrun_count;
    FaultReason fault_reason;
    bool fault_state;
    const char* state_str;
};

TelemetryData shared_telemetry;     // guarded by spinlock (critical sections imply barriers)
portMUX_TYPE spinlock = portMUX_INITIALIZER_UNLOCKED;

// Before scheduling: setup may initialize/trip. Afterwards: control task ONLY.
SafetySupervisor safety;
bool pwm_released = false;
FaultReason adc_fault_reason = FAULT_NONE;

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
uint32_t overrun_count = 0;         // missed queued ticks / deadline violations
uint32_t max_execution_time_us = 0;
uint32_t max_response_time_us = 0;

// Keep the OLDEST pending release; a later interrupt must not hide a late wake.
portMUX_TYPE release_spinlock = portMUX_INITIALIZER_UNLOCKED;
volatile uint32_t oldest_release_us = 0;
volatile bool release_pending = false;

// Hardware SPI instance
SPIClass* hspi = nullptr;

// Control task handle — the timer ISR notifies this task every 100 µs
TaskHandle_t control_task_handle = nullptr;

// --- Forward declarations ---
void trigger_hardware_trip(FaultReason reason);
bool init_pwm();
void init_external_adc();
void init_gpio();
bool calibrate_current_offsets();
inline bool read_ad7606_volts(float ch_volts[6]);
inline bool read_measurements(float &ia, float &ib, float &ic, float &va, float &vb, float &vc);

// =================================================================================
//  L0 STATUS READ — is the MCPWM one-shot fault latch currently asserted?
//  The public legacy API (mcpwm_fault_init / _set_oneshot_mode / _set_cyc_mode /
//  _deinit) has NO status call, but the latch is just a register bit. Clearing it
//  requires a posedge on fh_clr_ost (see mcpwm_ll_fault_clear_ost in
//  hal/esp32/mcpwm_ll.h), so mcpwm_set_duty() cannot clear it — checked against
//  core 2.0.17. Operators 0-2 correspond to MCPWM_TIMER_0-2.
// =================================================================================
inline bool mcpwm_ost_latched() {
    return MCPWM0.operators[0].fh_status.fh_ost_on ||
           MCPWM0.operators[1].fh_status.fh_ost_on ||
           MCPWM0.operators[2].fh_status.fh_ost_on;
}

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
    // esp_timer_get_time is the IRAM LAC timebase on original ESP32 IDF4.4;
    // calling it directly avoids Arduino micros()' optional IRAM wrapper.
    uint32_t now_us = (uint32_t)esp_timer_get_time();
    portENTER_CRITICAL_ISR(&release_spinlock);
    if (!release_pending) {
        oldest_release_us = now_us;
        release_pending = true;
    }
    portEXIT_CRITICAL_ISR(&release_spinlock);
    BaseType_t hp_task_woken = pdFALSE;
    vTaskNotifyGiveFromISR(control_task_handle, &hp_task_woken);
    if (hp_task_woken == pdTRUE) portYIELD_FROM_ISR();
}

// =================================================================================
//  CONTROL STEP — runs in the max-priority Core-1 task, once per timer tick
// =================================================================================
void control_step() {
    loop_counter++;

    // L1 backup poll of the OCP line (L0 = MCPWM hardware fault, already armed).
    // Active LOW: LM393 (A) / nFAULT (B). Requires the external pull-up (GPIO34!).
#if !DRY_RUN_NO_POWER_STAGE
    // The level poll ALONE misses any fault shorter than one control period: the
    // silicon latches in <1 µs, but a 5 µs comparator pulse is already gone by the
    // next digitalRead() — gates dead, firmware still in RUNNING, no alert. Reading
    // the one-shot latch closes that window; the poll stays as the backup layer.
    if (mcpwm_ost_latched() || digitalRead(OCP_FAULT_PIN) == LOW) {
        trigger_hardware_trip(FAULT_HARDWARE);
        return;
    }
#endif
    if (safety.state() == STATE_FAULT) {
        trigger_hardware_trip(safety.reason());
        return;
    }

    // 1. Simultaneous AD7606 sample
    float ia, ib, ic;
    float va, vb, vc;
    if (!read_measurements(ia, ib, ic, va, vb, vc)) {
        // Conversion never completed → feedback is unknown. Never keep switching
        // on stale/garbage measurements.
        trigger_hardware_trip(adc_fault_reason);
        return;
    }

    // 2. Protection — L2: instantaneous overcurrent
    if (fabsf(ia) > I_TRIP_LIMIT || fabsf(ib) > I_TRIP_LIMIT || fabsf(ic) > I_TRIP_LIMIT) {
        trigger_hardware_trip(FAULT_OVERCURRENT);
        return;
    }
    // Protection — L3: overload integral. Only current in EXCESS of rated
    // accumulates; a negative excess cools it back down, floored at zero so it
    // cannot bank credit during light load.
    float i_sq_avg = ONE_THIRD * (ia*ia + ib*ib + ic*ic);
    thermal_accumulator += Ts * (i_sq_avg - I_SQ_RATED);
    if (thermal_accumulator < 0.0f) thermal_accumulator = 0.0f;
    if (thermal_accumulator > THERMAL_TRIP) {
        trigger_hardware_trip(FAULT_OVERLOAD);
        return;
    }

    // The same task that checks protection owns gate enable and every transition.
    // No setup() write can overwrite a fault during the bootstrap interval.
    StartupAction startup = safety.advance_startup(micros());
    if (startup == STARTUP_ENABLE_REQUEST) {
#if !DRY_RUN_NO_POWER_STAGE
        digitalWrite(EN_GATE_PIN, GATE_REQUESTED);
#endif
    }

    if (safety.state() == STATE_SOFT_START || safety.state() == STATE_RUNNING) {
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
        if (safety.state() == STATE_SOFT_START) {
            // Ramp E from 0 → V_SET over 2.0 s (20,000 steps) at constant 50 Hz
            E_ramp += (V_SET / 20000.0f);
            if (E_ramp >= V_SET) {
                E_ramp = V_SET;
                safety.finish_soft_start();
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
        struct PwmWriter {
            bool write_duty(unsigned channel, float duty) {
                return mcpwm_set_duty(MCPWM_UNIT_0, (mcpwm_timer_t)channel,
                                      MCPWM_OPR_A, duty * 100.0f) == ESP_OK;
            }
            bool restore_mode(unsigned channel) {
                return mcpwm_set_duty_type(MCPWM_UNIT_0, (mcpwm_timer_t)channel,
                                           MCPWM_OPR_A, MCPWM_DUTY_MODE_0) == ESP_OK;
            }
        } pwm;
        const float duty[3] = {duty_a, duty_b, duty_c};
        if (!apply_pwm(pwm, duty, pwm_released)) {
            trigger_hardware_trip(FAULT_PWM);
            return;
        }

        // I. Publish telemetry snapshot (~100 Hz: every 100th step)
        if (loop_counter % 100 == 0) {
            const char* state_name = (safety.state() == STATE_SOFT_START) ? "SOFT_START" : "RUNNING";
            portENTER_CRITICAL(&spinlock);
            shared_telemetry.ia = ia; shared_telemetry.ib = ib; shared_telemetry.ic = ic;
            shared_telemetry.va = va; shared_telemetry.vb = vb; shared_telemetry.vc = vc;
            shared_telemetry.P = vsg_P_filt;
            shared_telemetry.Q = vsg_Q_filt;
            shared_telemetry.omega = omega;
            shared_telemetry.theta = vsg_theta;
            shared_telemetry.E = E;
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
        uint32_t start_us = micros();
        portENTER_CRITICAL(&release_spinlock);
        uint32_t release_us = oldest_release_us;
        release_pending = false;
        portEXIT_CRITICAL(&release_spinlock);
        uint32_t wake_delay_us = start_us - release_us;
        bool late_on_wake = !deadline_ok(notif_count, wake_delay_us, CONTROL_BUDGET_US);
        if (late_on_wake) {
            overrun_count += (notif_count > 1) ? (notif_count - 1) : 1;
            trigger_hardware_trip(FAULT_DEADLINE);
        } else {
            control_step();
        }
        uint32_t elapsed_us = micros() - start_us;
        uint32_t response_us = micros() - release_us;
        if (elapsed_us > max_execution_time_us) max_execution_time_us = elapsed_us;
        if (response_us > max_response_time_us) max_response_time_us = response_us;
        if (!deadline_ok(notif_count, response_us, CONTROL_BUDGET_US)) {
            if (response_us >= CONTROL_BUDGET_US && !late_on_wake) ++overrun_count;
            trigger_hardware_trip(FAULT_DEADLINE);
        }
        // Every step contributes to the maximum, including startup and fault paths.
        // Wall-clock timing avoids assuming a 240 MHz CPU clock.
        portENTER_CRITICAL(&spinlock);
        shared_telemetry.execution_time_us = elapsed_us;
        shared_telemetry.max_execution_time_us = max_execution_time_us;
        shared_telemetry.max_response_time_us = max_response_time_us;
        shared_telemetry.overrun_count = overrun_count;
        portEXIT_CRITICAL(&spinlock);
    }
}

// =================================================================================
//  EMERGENCY SAFE SHUTDOWN  (task context)
// =================================================================================
void trigger_hardware_trip(FaultReason reason) {
    // Disable gate request FIRST. The external shutdown latch independently
    // removes physical permission even if this task never executes.
    digitalWrite(EN_GATE_PIN, GATE_DISABLED);
    // 0. (already done in silicon if L0 tripped: MCPWM one-shot fault latched low)
    // 1. Force all MCPWM outputs low
    mcpwm_set_signal_low(MCPWM_UNIT_0, MCPWM_TIMER_0, MCPWM_OPR_A);
    mcpwm_set_signal_low(MCPWM_UNIT_0, MCPWM_TIMER_1, MCPWM_OPR_A);
    mcpwm_set_signal_low(MCPWM_UNIT_0, MCPWM_TIMER_2, MCPWM_OPR_A);
    pwm_released = false;
    // 3. Latch fault
    safety.trip(reason);
    portENTER_CRITICAL(&spinlock);
    shared_telemetry.fault_reason = safety.reason();
    shared_telemetry.fault_state = true;
    shared_telemetry.state_str = "FAULT";
    portEXIT_CRITICAL(&spinlock);
}

// =================================================================================
//  HARDWARE INIT
// =================================================================================
void init_gpio() {
    pinMode(EN_GATE_PIN, OUTPUT);
    digitalWrite(EN_GATE_PIN, GATE_DISABLED);          // gate drivers disabled on boot (verify SD polarity for IR2104)
    // GPIO34 is input-only, NO internal pull-up exists — plain INPUT.
    // The required 10 kΩ pull-up to 3.3 V must be ON THE BOARD (LM393 is open-collector).
    pinMode(OCP_FAULT_PIN, INPUT);
#if POWER_STAGE == POWER_STAGE_DRV8302
    // GPIO39, like GPIO34, is input-only with NO internal pull-up: INPUT_PULLUP is
    // a silent no-op here (the exact trap fix #3 above was about). The pull-up for
    // nOCTW must be on the board.
    pinMode(DRV_nOCTW_PIN, INPUT);
#endif
}

bool init_pwm() {
    // MCPWM0 A-channels only → one PWM per IR2104 (each makes complement + ~520ns dead-time)
    if (mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM0A, PWM_A_PIN) != ESP_OK ||
        mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM1A, PWM_B_PIN) != ESP_OK ||
        mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM2A, PWM_C_PIN) != ESP_OK) return false;

    mcpwm_config_t pwm_config;
    // Installed 2.0.17 explicitly halves this argument in UP_DOWN mode.
    pwm_config.frequency    = 20000;                  // nominal 10 kHz carrier
    pwm_config.cmpr_a       = 50.0;                   // 50 % initial duty
    pwm_config.cmpr_b       = 50.0;
    pwm_config.counter_mode = MCPWM_UP_DOWN_COUNTER;  // center-aligned (symmetric)
    pwm_config.duty_mode    = MCPWM_DUTY_MODE_0;      // active-high

    for (int channel = 0; channel < 3; ++channel) {
        if (mcpwm_init(MCPWM_UNIT_0, (mcpwm_timer_t)channel, &pwm_config) != ESP_OK)
            return false;
    }
    // Increase resolution from legacy 1 MHz default. At 80 MHz, the legacy
    // period-minus-one arithmetic gives ~10002.5 Hz (0.025% from nominal),
    // instead of ~10204 Hz at 1 MHz. Verify actual frequency and duty on scope.
    if (mcpwm_group_set_resolution(MCPWM_UNIT_0, 80000000) != ESP_OK) return false;
    for (int channel = 0; channel < 3; ++channel) {
        mcpwm_timer_t timer = (mcpwm_timer_t)channel;
        if (mcpwm_timer_set_resolution(MCPWM_UNIT_0, timer, 80000000) != ESP_OK ||
            mcpwm_set_frequency(MCPWM_UNIT_0, timer, 20000) != ESP_OK) return false;
    }

    // Phase carriers share timer0's ZERO event; these APIs exist in core2.0.17.
    mcpwm_sync_config_t sync_config = {};
    sync_config.sync_sig = MCPWM_SELECT_TIMER0_SYNC;
    sync_config.timer_val = 0;
    sync_config.count_direction = MCPWM_TIMER_DIRECTION_UP;
    if (mcpwm_set_timer_sync_output(MCPWM_UNIT_0, MCPWM_TIMER_0,
                                   MCPWM_SWSYNC_SOURCE_TEZ) != ESP_OK ||
        mcpwm_sync_configure(MCPWM_UNIT_0, MCPWM_TIMER_1, &sync_config) != ESP_OK ||
        mcpwm_sync_configure(MCPWM_UNIT_0, MCPWM_TIMER_2, &sync_config) != ESP_OK)
        return false;

    // Park the outputs LOW until the control loop owns them. Without this the
    // generators sit at the cmpr_a = 50 % init value, so enabling the gate drivers
    // before the first mcpwm_set_duty() switches the bridge open-loop on a live bus.
    // With physical permission, parked LOW turns on the three IR2104 low sides
    // to charge bootstrap capacitors during the protected 10 ms BOOTSTRAP state.
    // Duty writes ALONE do not restore the generator:
    // apply_pwm() loads all duties then restores MCPWM_DUTY_MODE_0 explicitly.
    for (int channel = 0; channel < 3; ++channel)
        if (mcpwm_set_signal_low(MCPWM_UNIT_0, (mcpwm_timer_t)channel,
                                 MCPWM_OPR_A) != ESP_OK) return false;

#if !DRY_RUN_NO_POWER_STAGE
    // L0 HARDWARE FAULT: LM393/nFAULT (active LOW) → MCPWM fault F0.
    // One-shot mode: on trigger, silicon forces all outputs LOW and LATCHES
    // until reboot (mcpwm_fault_deinit would clear it — we deliberately don't).
    // This is a secondary brake, NOT both-gates-off shutdown for IR2104.
    // End-to-end comparator-to-HO/LO latency must be MEASURED on the board.
    if (mcpwm_gpio_init(MCPWM_UNIT_0, MCPWM_FAULT_0, OCP_FAULT_PIN) != ESP_OK ||
        mcpwm_fault_init(MCPWM_UNIT_0, MCPWM_LOW_LEVEL_TGR, MCPWM_SELECT_F0) != ESP_OK)
        return false;
    for (int channel = 0; channel < 3; ++channel)
        if (mcpwm_fault_set_oneshot_mode(MCPWM_UNIT_0, (mcpwm_timer_t)channel,
             MCPWM_SELECT_F0, MCPWM_ACTION_FORCE_LOW, MCPWM_ACTION_FORCE_LOW) != ESP_OK)
            return false;
#endif
    return true;
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
    // AD7606 Rev.G serial diagram: idle HIGH, MSB available after CS falling,
    // subsequent bits change on SCLK rising; sample on falling (SPI mode 2).
    hspi->beginTransaction(SPISettings(AD7606_SPI_HZ, MSBFIRST, SPI_MODE2));
}

// AD7606 simultaneous conversion + SPI read → volts AT THE ADC PIN for ch 1-6
// (channels 1-3 = ACS712 outputs, channels 4-6 = divided phase voltages)
// Returns false if the conversion never completed — the caller MUST treat that as
// a fault instead of using the buffer.
inline bool read_ad7606_volts(float ch_volts[6]) {
    uint8_t raw_bytes[12] = {0};
    struct AdcIo {
        uint8_t* bytes;
        bool busy() { return digitalRead(AD7606_BUSY_PIN) == HIGH; }
        uint32_t now_us() { return micros(); }
        void trigger() {
            // CONVST A/B must be tied together on the qualified module.
            digitalWrite(AD7606_CONVST_PIN, LOW);
            delayMicroseconds(1); // exceeds the specified minimum low pulse
            digitalWrite(AD7606_CONVST_PIN, HIGH);
        }
        void read() {
            // Covers BUSY falling -> valid output-data delay with ample margin.
            delayMicroseconds(1);
            digitalWrite(AD7606_CS_PIN, LOW);
            hspi->transferBytes(nullptr, bytes, 12);
            digitalWrite(AD7606_CS_PIN, HIGH);
        }
    } io = {raw_bytes};
    adc_fault_reason = acquire_adc(io, ADC_ASSERT_TIMEOUT_US, ADC_BUSY_TIMEOUT_US);
    if (adc_fault_reason != FAULT_NONE) return false;

    for (int ch = 0; ch < 6; ch++) {
        int16_t raw = (int16_t)((raw_bytes[2*ch] << 8) | raw_bytes[2*ch + 1]);
        ch_volts[ch] = (float)raw * ADC_LSB_VOLTS;
    }
    return true;
}

// Scaled measurements: phase currents (A) with per-channel auto-zeroed bias,
// phase voltages (V) through the ×4 divider.
// Returns false only when the ADC failed to convert (never in DRY-RUN — see below).
inline bool read_measurements(float &ia, float &ib, float &ic, float &va, float &vb, float &vc) {
#if DRY_RUN_NO_POWER_STAGE
    // Synthetic timing fixture: deterministic conversion delay + SPI transfer.
    // No floating BUSY polling; this does NOT validate a connected ADC's timing.
    uint8_t discarded[12];
    delayMicroseconds(5);
    digitalWrite(AD7606_CS_PIN, LOW);
    hspi->transferBytes(nullptr, discarded, sizeof(discarded));
    digitalWrite(AD7606_CS_PIN, HIGH);
    ia = ib = ic = 0.0f;
    va = vb = vc = 0.0f;
    return true;
#else
    float v[6];
    if (!read_ad7606_volts(v)) return false;

    ia = (v[0] - i_bias_v[0]) / ACS712_SENSITIVITY;
    ib = (v[1] - i_bias_v[1]) / ACS712_SENSITIVITY;
    ic = (v[2] - i_bias_v[2]) / ACS712_SENSITIVITY;

    va = v[3] * V_DIVIDER_GAIN;
    vb = v[4] * V_DIVIDER_GAIN;
    vc = v[5] * V_DIVIDER_GAIN;
    return true;
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
        if (!read_ad7606_volts(v)) {
            Serial.println("  !! AD7606 BUSY timeout during calibration — ADC missing or miswired.");
            return false;
        }
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
            Serial.printf("FAULT latched: reason=%u | max step=%u us | max response=%u us | overruns=%u\n",
                          (unsigned)local_data.fault_reason, local_data.max_execution_time_us,
                          local_data.max_response_time_us, local_data.overrun_count);
            Serial.println("Action: power down DC bus, check load + star grounding, then reset.");
        } else {
            Serial.printf("State: %s | P: %.2f W | Q: %.2f VAR | Freq: %.3f Hz | E: %.2f V\n",
                          local_data.state_str ? local_data.state_str : "INIT",
                          local_data.P, local_data.Q,
                          local_data.omega / (2.0f * M_PI), local_data.E);
            Serial.printf("  V_abc: [%.2f, %.2f, %.2f] V | I_abc: [%.3f, %.3f, %.3f] A | step: %u us | max: %u us | response max: %u us | overruns: %u\n",
                          local_data.va, local_data.vb, local_data.vc,
                          local_data.ia, local_data.ib, local_data.ic,
                          local_data.execution_time_us, local_data.max_execution_time_us,
                          local_data.max_response_time_us, local_data.overrun_count);
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
    if (!init_pwm()) {
        digitalWrite(EN_GATE_PIN, GATE_DISABLED);
        safety.trip(FAULT_INITIALIZATION);
        Serial.println("PWM INITIALIZATION FAILED - gates disabled.");
        while (true) vTaskDelay(pdMS_TO_TICKS(1000));
    }
    init_external_adc();

    safety.initialize();
    Serial.println("STANDBY — settling power rails...");
    delay(2000);

#if !DRY_RUN_NO_POWER_STAGE
    // Auto-zero the current sensors while the gates are still disabled (I = 0)
    Serial.println("Calibrating ACS712 offsets (gates disabled)...");
    if (!calibrate_current_offsets()) {
        safety.trip(FAULT_CALIBRATION);
        Serial.println("CALIBRATION FAILED — halting in FAULT. Fix sensing, then reset.");
        while (true) vTaskDelay(pdMS_TO_TICKS(1000));
    }
#endif

    // Telemetry task → Core 0
    xTaskCreatePinnedToCore(telemetryTask, "TelemetryTask", 4096, NULL, 1, NULL, 0);

    // Control task → Core 1, max priority. MUST exist before the timer starts, or
    // the ISR notifies a null handle and panics — so the result is checked.
    BaseType_t ctrl_created = xTaskCreatePinnedToCore(controlTask, "VSGControl", 8192, NULL,
                                                      configMAX_PRIORITIES - 1,
                                                      &control_task_handle, 1);
    if (ctrl_created != pdPASS || control_task_handle == nullptr) {
        digitalWrite(EN_GATE_PIN, GATE_DISABLED);
        safety.trip(FAULT_INITIALIZATION);
        Serial.println("FATAL: control task creation failed — halted with gates disabled.");
        while (true) vTaskDelay(pdMS_TO_TICKS(1000));
    }

    // From now on, controlTask owns safety state and gate request. setup never
    // enables gates or writes SOFT_START. First valid sample + protection pass
    // permits bootstrap; each bootstrap tick still checks protection.
    ctrl_timer = timerBegin(0, 80, true);
    if (ctrl_timer == nullptr) {
        // No timer exists, therefore the control task cannot have executed.
        digitalWrite(EN_GATE_PIN, GATE_DISABLED);
        safety.trip(FAULT_INITIALIZATION);
        Serial.println("TIMER INITIALIZATION FAILED - gates disabled.");
        while (true) vTaskDelay(pdMS_TO_TICKS(1000));
    }
    timerAttachInterrupt(ctrl_timer, &onControlTimer, true);
    timerAlarmWrite(ctrl_timer, 100, true);
    timerAlarmEnable(ctrl_timer);
    Serial.println("Control task owns protected bootstrap and 2-second soft start.");
}

void loop() {
    // Core 1: timer ISR → VSGControl task (prio 24). Core 0: telemetry. Idle here.
    vTaskDelay(portMAX_DELAY);
}
