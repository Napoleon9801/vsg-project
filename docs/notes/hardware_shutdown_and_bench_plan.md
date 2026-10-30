# Independent shutdown and bench acceptance plan

Revision 2026-10-13 — functional design and acceptance requirements, not an inspected PCB or approved assembly drawing. The actual board, comparator circuit, sensor modules, transistor ratings and power supplies have not been measured in this session. No physical tests below are marked complete.

## Required functional circuit

The IR2104's active-low shutdown input disables both HO and LO when LOW. HIGH permits complementary switching. IN LOW with shutdown released can turn LO on; therefore forcing MCPWM LOW does not disable all gates. Polarity is verified from Figure 1/3 on page 5 of the [Infineon IR2104 datasheet](https://www.infineon.com/assets/row/public/documents/24/49/infineon-ir2104-ds-en.pdf). Verify the fitted part/module and any inversion before construction.

Use named signals, not guessed package pin numbers:

```text
OCP comparator FAULT_N ----+--> ESP32 GPIO34 / MCPWM F0
                          +--> asynchronous CLEAR of hardware permit latch
Power supervisor RESET_N ----> asynchronous CLEAR of hardware permit latch
DC-bus UV/OV interlock -------> asynchronous CLEAR of hardware permit latch
Manual ARM (debounced) -------> set permit ONLY with FAULT_N healthy,
                               supply healthy, MCU_REQUEST LOW

MCU_REQUEST GPIO22 -----------> AND ----> SD_PERMIT to all three IR2104 SD inputs
Latched HARDWARE_PERMIT ------> AND
```

The latch starts cleared, clears on fault or supervisor reset, and stays cleared after a transient fault disappears. A separate deliberate ARM action is required; it must not automatically restart when a held ARM switch survives a fault. Firmware reset alone must not energize the bridge. Pull GPIO22 and the final SD_PERMIT node LOW externally so an unpowered/reset controller or unpowered logic cannot request enable. The permit circuit must be healthy before the firmware real-power build is qualified.

| MCU request | Latched permit | SD permit | Result |
|---:|---:|---:|---|
| 0 | 0 | 0 | Both gates disabled |
| 0 | 1 | 0 | Both gates disabled |
| 1 | 0 | 0 | Both gates disabled |
| 1 | 1 | 1 | PWM permitted |

An asynchronous-clear D flip-flop such as [TI SN74LVC1G74](https://www.ti.com/lit/ds/symlink/sn74lvc1g74.pdf) with an AND function such as [TI SN74LVC1G08](https://www.ti.com/lit/ds/symlink/sn74lvc1g08.pdf) illustrates the logic. This is not a final component selection: verify logic-rail voltage and worst-case HIGH margin against IR2104's 3 V HIGH threshold, fanout, propagation delay, power sequencing, supervisor threshold, external pulls and input edges. A nominal 3.3 V signal has limited margin; do not assume a loaded output always meets 3 V. Use an appropriately rated buffer/level interface if required, without exposing ESP32 inputs to 5/12 V. Keep asynchronous preset inactive, avoid simultaneous preset/clear, and satisfy reset recovery timing.

FAULT_N from a verified open-collector comparator needs an external 10 kohm pull-up to 3.3 V on the ESP32 branch (GPIO34 has no internal pull). Never connect an open-collector fault output directly against GPIO22's push-pull output. Combine open-drain supervisor/comparator resets only when their ratings and inactive states permit it; otherwise use proper logic. Monitor the latch state in the fault path where the electrical interface permits, so firmware also reports a transient hardware trip.

Comparator threshold, shunt value, hysteresis/blanking and total measured trip delay remain design inputs. Derive the threshold from actual maximum operating current, inductor saturation and switch limits. Do not claim a sub-microsecond end-to-end trip from MCPWM's internal response alone. A DC-return shunt alone may miss some recirculating phase-current conditions; assess sensing coverage with the exact topology.

Include DC-bus undervoltage/overvoltage supervision in the independent shutdown design. The current firmware does not have a qualified Vdc sensing channel/scaling. Select thresholds and hysteresis from the reviewed source, capacitor, modulation and component operating ranges; do not invent them from nominal voltage alone. The averaged source-limit study at 2.7 A showed a bus collapse to approximately 16.8 V without the modeled current protection tripping. Its expected-sag test passing does not make that operating point acceptable. A UV/OV shutdown also does not absorb regenerated energy: an independently rated energy sink is still required for applicable tests.

## AD7606 module qualification

Use the actual module schematic plus [AD7606 documentation](https://www.analog.com/media/en/technical-documentation/data-sheets/AD7606_7606-6_7606-4.pdf). Record RESET source and power-up pulse, RANGE, OS straps, serial/parallel mode, VDRIVE, channel ordering, signed conversion scale and analog conditioning. A firmware BUSY timeout does not replace the required hardware reset. Verify both BUSY assertion after CONVST and completion; inject stuck HIGH and LOW using a suitable test fixture. Do not guess module header pins from the IC package pinout.

## Evidence required before enabling a power stage

| Test | Expected result | Evidence to save |
|---|---|---|
| Unpowered MCU / reset / disconnected USB | SD_PERMIT LOW; no automatic enable | SD, HO/LO captures with auxiliary supply only |
| Bare-board dry-run PWM | 10 kHz actual carrier; aligned phase carriers; gate request always LOW | Three PWM traces and firmware build settings |
| Control timing | Every measured cycle accounted for; worst-case below 100 us, sustained misses trigger fault | Execution max, missed-tick counters and timing pulse captures |
| ADC known voltages/zero current | Correct sign, scale, channel order and stable calibrated offsets | Calibration CSV and references used |
| ADC stuck HIGH/LOW | FAULT; gate request stays LOW through startup | Fault code plus GPIO capture |
| OCP pulse / MCU stalled | Independent latch clears; both HO and LO turn off; no spontaneous restart | Comparator, latch, SD, HO and LO time-correlated traces |
| Fault during standby/bootstrap | Startup cannot overwrite FAULT | State and gate-request capture |
| Logic supply loss while driver supply remains | Final driver input goes to shutdown | SD, logic rail and gate traces |
| DC-bus UV/OV threshold crossings | Independent shutdown remains latched; thresholds and hysteresis measured | Bus voltage, fault output and gate captures |
| Deliberate re-arm | Requires healthy inputs and explicit restart sequence | State/permit transitions |

Measure floating high-side gate voltage as HO-to-VS with appropriately rated differential/isolated equipment; do not place an earth-referenced oscilloscope ground clip on a switching node.

After these pass, proceed from a low-energy, current-limited setup to the documented operating point in stages. Record actual source voltage/current limit, load and thermal limits at each stage. Supply current limiting is supplemental and does not replace gate shutdown. Establish an energy absorption path before load rejection; characterize actual dead-time and switching overshoot before full-load testing. The historical ~136 W step requires separate overload qualification.

Use one evidence folder per run with firmware revision/configuration, toolchain, wiring revision, instruments, temperatures, raw CSV and oscilloscope files. Mark each row PASS/FAIL with a linked artifact; leave unperformed tests PENDING.
