# VSG Design-Point Reconciliation — Decision Memo

> **Created:** 2026-05-30 (autonomous, overnight) — for Napoleon to decide
> **Why this exists:** While drafting Chapter 5 I found the DC bus voltage and the
> LC filter values disagree across four sources. This blocks hardware purchasing and
> makes the thesis internally inconsistent. This memo lays out the conflict, two
> *coherent* options with real numbers, a recommendation, and exactly what I will
> update once you pick. **I did NOT silently rewrite anything — this is your call.**

---

## 1. The conflict (what disagrees)

| Parameter | Sim (Stage 5c, **verified**) | Safety Handbook | Ch.3 BoM (advisor docx) | Firmware `.ino` |
|---|---|---|---|---|
| DC bus | **48 V** | 24 V base | 24 V (48 V contingency) | `Vdc = 40 V` |
| AC target | `V_set` = 14 V peak/phase | 24 V L-L RMS (19.6 V pk L-N) | 24 V L-L | `E_0` = 19.6 V pk |
| `L_f` | **1.2 mH** | 1.47 mH | 1.5 mH | 1.47 mH |
| `C_f` | **10 µF** | 27.63 µF | 30 µF (15×2) | 27.63 µF |
| `f_res` (LC) | **1453 Hz** | 790 Hz | ~750 Hz | 790 Hz |
| Power stage | ideal bridge | DRV8302 (60 V max) | DRV8302 | DRV8302 |

**Key realization:** the simulation's "48 V pivot" did two things at once — it raised the
DC bus (24→48 V) *and* lowered the AC target (to 14 V peak), giving modulation index
**m = 14/24 = 0.58** (safe). The handbook/firmware path instead targets 24 V L-L (19.6 V
peak) which at `Vdc = 40 V` is **m ≈ 0.98** — dangerously close to overmodulation, the
exact failure Stage 5a caught. So the two paths are *not* just different numbers; they
encode different voltage philosophies.

**Also:** `C_f` differs by ~2.8× (10 vs 27.6 µF), which moves the filter resonance from
1453 Hz to 790 Hz. That changes `R_d` damping design and the output THD. They cannot both
be right.

---

## 2. Two coherent options

### Option A — "Sim-faithful, 48 V" ✅ RECOMMENDED

Keep exactly what Stage 5a–5c already verified.

| Item | Value |
|---|---|
| DC bus | 48 V (4×12 V LiFePO4) |
| AC target `V_set` | 14 V peak/phase (≈9.9 V RMS phase, ≈17.1 V L-L RMS) |
| Modulation index | 0.58 (comfortable linear range) |
| `L_f` / `C_f` | 1.2 mH / 10 µF → `f_res` = 1453 Hz (well-placed at ~f_sw/7) |
| `R_d` | 1 Ω (ζ ≈ 0.046, from Stage 5c) |
| Power stage | **100 V-class MOSFET (IRF540N) + isolated UCC21520** (DRV8302's 60 V max is too close at a 48 V bus) |
| Battery / TVS | 48 V LiFePO4 + P6KE60A TVS |

- **Pros:** already simulated and verified end-to-end; stays ≤60 V scope; huge modulation margin; filter resonance sits correctly above the control bandwidth and below f_sw.
- **Cons:** AC output is low (17 V L-L) — fine for a benchtop proof, but the **pu base must be redefined at the real operating voltage** (the handbook's 24 V-base pu-scaling no longer matches). Small re-derivation, no re-sim of control needed.
- **Re-sim needed?** No — the control was verified at exactly these values. Only the pu-base table in the handbook needs recomputing.

### Option B — "Handbook 24 V-class"

Keep the handbook/firmware voltage, fix the DC bus and re-sim.

| Item | Value |
|---|---|
| DC bus | 48 V (to get m ≈ 0.82 at 19.6 V peak — 40 V would be unsafe at m≈0.98) |
| AC target | 24 V L-L RMS (19.6 V peak L-N) |
| `L_f` / `C_f` | 1.47 mH / 27.6 µF → `f_res` = 790 Hz |
| Power stage | same 100 V MOSFET + UCC21520 concern at 48 V |

- **Pros:** higher, more "realistic" AC output (24 V L-L); pu-scaling already worked out in handbook at 24 V base; firmware constants already match.
- **Cons:** **the control loops were never simulated at 1.47 mH / 27.6 µF** — must re-run Stage 5a/5c to re-verify (PI gains depend on `L_f`, `C_f`). `f_res` = 790 Hz is close to the 100 Hz voltage-loop / 1 kHz current-loop bandwidth — needs a stability re-check. More expensive components (27 µF film caps are bulky/pricey).

---

## 3. Recommendation

**Go with Option A (48 V, sim-faithful).** Rationale:
1. It is the only option already **verified end-to-end** in Chapters 4 — zero re-sim risk.
2. m = 0.58 gives the largest safety margin against the overmodulation failure mode.
3. `f_res` = 1453 Hz is correctly placed (above 1 kHz current loop, below 10 kHz switching).
4. The only homework is re-deriving the pu base at the true operating voltage — cheap.

The single honest trade-off: a 17 V L-L benchtop output looks less "grid-like" than 24 V.
For a *dynamic-equivalence* proof (which is the thesis contribution), absolute voltage is
irrelevant — only the pu dynamics matter, and those are identical. So this costs nothing
scientifically.

---

## 4. What I will update once you decide (one word: "A" or "B")

Pick A or B and I will, in one session, make all four sources agree:
1. **`hardware_safety_handbook.md`** — recompute the pu base table + `L_f/C_f/R_d` at the chosen point.
2. **`vsg_controller.ino`** — set `Vdc`, `Vb`, `Lf`, `Cf`, `E_0` to the chosen point; re-derive PI constants.
3. **Ch.3 BoM (`66AOS02-แก้.docx`)** — Table 2 R3 battery + `L_f/C_f` rows (this is the advisor doc — I'll show you the diff before saving).
4. **Ch.5 §5.10** — collapse the open-decision table into the final locked design point.
5. **(Option B only)** re-run Stage 5a/5c at the new filter values and refresh Chapter 4 numbers.

Plus the still-open power-stage decision: **DRV8302 alone vs. discrete 100 V MOSFET + UCC21520.**
At 48 V I recommend the discrete path (per research report §3.2) — confirm and I'll finalize the BoM.

---

## 5. Quick-decide checklist

- [ ] DC bus: **48 V** (rec.) or 24/40 V?
- [ ] Design point: **Option A** (rec.) or Option B?
- [ ] Power stage: **discrete 100 V + UCC21520** (rec. at 48 V) or DRV8302 shield?
- [ ] Once decided → tell me "A" / "B" and the power-stage choice; I propagate everything.
