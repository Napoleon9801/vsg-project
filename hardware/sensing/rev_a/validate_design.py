"""Analytical checks for the proposed sensing Rev A; not SPICE or hardware proof.

Run with Python's standard library. Outputs stay beside this script.
"""
from pathlib import Path
import cmath
import csv
import itertools
import json
import math

ROOT = Path(__file__).resolve().parent


def coefficients(frequency, rp=40000., rn=40000., rg=10000., rf=10000., cg=1e-9, cf=1e-9):
    s = complex(0, 2 * math.pi * frequency)
    zg = rg / (1 + s * rg * cg)
    zf = rf / (1 + s * rf * cf)
    a = (1 + zf / rn) * zg / (rp + zg)
    b = -zf / rn
    return a, b


def main():
    checks = []
    def check(name, passed, details):
        checks.append(dict(name=name, passed=bool(passed), details=details))

    dc_a, dc_b = coefficients(0)
    check('dc_transfer', abs(dc_a - .25) < 1e-12 and abs(dc_b + .25) < 1e-12,
          {'out_coefficient': dc_a.real, 'neutral_coefficient': dc_b.real})
    max_normal_output = 0.
    max_normal_input_node = -float('inf')
    min_normal_input_node = float('inf')
    for out_v in range(-2, 51):
        for neutral_v in range(-2, 51):
            if abs(out_v - neutral_v) <= 24:
                max_normal_output = max(max_normal_output, abs((out_v-neutral_v)/4))
                max_normal_input_node = max(max_normal_input_node, out_v/5)
                min_normal_input_node = min(min_normal_input_node, out_v/5)
    check('selected_normal_envelope', max_normal_output <= 6 and max_normal_input_node < 11.4,
          {'max_adc_output_V': max_normal_output, 'opamp_input_min_V': min_normal_input_node,
           'opamp_input_max_V': max_normal_input_node, 'minimum_positive_rail_V': 11.4})

    response = []
    for f in (0, 50, 100, 1000, 5000, 10000, 20000):
        a, b = coefficients(f)
        expected = .25 / complex(1, 2*math.pi*f*10000*1e-9)
        check(f'ideal_transfer_{f}Hz', abs(a-expected) < 1e-12 and abs(a+b) < 1e-12,
              'Ideal matched components; opamp bandwidth and ADC filter excluded.')
        response.append(dict(frequency_Hz=f, relative_gain=abs(a)/.25,
                             attenuation_dB=20*math.log10(abs(a)/.25),
                             phase_deg=math.degrees(cmath.phase(a))))

    corners = []
    for temp_delta in (0, 25):
        tolerance = .0001 + 5e-6 * temp_delta
        maximum_cm = 0.
        maximum_phase_error = 0.
        for signs in itertools.product((-1, 1), repeat=4):
            rp, rn, rg, rf = [v*(1+sign*tolerance) for v, sign in zip((40000,40000,10000,10000), signs)]
            a, b = coefficients(0, rp, rn, rg, rf)
            maximum_cm = max(maximum_cm, abs(a+b))
            for neutral in (0, 20, 40):
                for differential in (-14, 0, 14):
                    out = neutral + differential
                    if -2 <= out <= 50:
                        reconstructed = 4*(a*out+b*neutral).real
                        maximum_phase_error = max(maximum_phase_error, abs(reconstructed-differential))
        corners.append(dict(temperature_delta_C=temp_delta, aggregate_resistor_tolerance=tolerance,
                            max_cm_gain_V_per_V=maximum_cm,
                            max_phase_error_V=maximum_phase_error,
                            note='Independent worst-sign tolerances; thermal tracking NOT assumed; opamp/ADC excluded.'))
    check('room_temperature_resistor_error_budget', corners[0]['max_phase_error_V'] < .02, corners[0])

    ac_cm = []
    for f in (50, 1000, 10000):
        worst_cm = 0.
        # Pair ratio <=0.1%, absolute C tolerance represented separately by common factor.
        for cap_scale in (.99, 1.01):
            for mismatch_sign in (-1, 1):
                cg = 1e-9*cap_scale
                cf = cg*(1+mismatch_sign*.001)
                for signs in itertools.product((-1,1), repeat=4):
                    rp,rn,rg,rf = [v*(1+sign*.0001) for v,sign in zip((40000,40000,10000,10000),signs)]
                    a,b=coefficients(f,rp,rn,rg,rf,cg,cf)
                    worst_cm=max(worst_cm,abs(a+b))
        ac_cm.append(dict(frequency_Hz=f,max_cm_gain=worst_cm,
                          phase_equivalent_error_for_20Vpeak_cm_V=4*20*worst_cm))

    injected = 6*60/(40000*.9999) + 60/(90000*.9999)
    bleed_power = 12.6**2/990
    check('bounded_dc_injection', injected < 12/1010 and 60/(40000*.9999) < .010,
          {'total_upper_bound_A': injected, 'bleeder_sink_at_12V_A': 12/1010,
           'off_rail_upper_bound_V': injected*1010,
           'warning': 'Not zero volts. No dynamic, protection-diode, partial-power or surge qualification.'})
    check('bleeder_power', bleed_power < .5, {'worst_selected_rail_power_W': bleed_power, 'rating_W': .5})
    input_resistor_power=(60/(40000*.9999))**2*(10000*1.0001)
    check('individual_input_resistor_power', input_resistor_power < .25,
          {'conservative_10k_power_W': input_resistor_power, 'rating_W': .25})

    # A balanced three-wire pole set projects onto the zero-sequence-free subspace.
    # This is an ideal algebra check, not a switching/filter simulation.
    max_projection_error = 0.
    for step in range(360):
        theta=math.radians(step)
        phases=[14*math.sin(theta+k*2*math.pi/3) for k in range(3)]
        for common_mode in (0,20,40):
            poles=[p+common_mode for p in phases]
            neutral=sum(poles)/3
            reconstructed=[p-neutral for p in poles]
            max_projection_error=max(max_projection_error,max(abs(a-b) for a,b in zip(phases,reconstructed)))
    check('balanced_neutral_algebra',max_projection_error<1e-12,{'max_error_V':max_projection_error})

    report=dict(status='ANALYTICAL_CHECKS_ONLY',checks=checks,
                all_checks_passed=all(x['passed'] for x in checks),
                phase_fc_Hz=1/(2*math.pi*10000*1e-9),
                bus_fc_Hz=1/(2*math.pi*9000*10e-9),
                nominal_neutral_loading_A=3*(20-20/5)/40000,
                nominal_phase_loading_A=3*20/50000,
                frequency_response=response,resistor_corners=corners,ac_common_mode_corners=ac_cm,
                exclusions=['Real opamp loop/settling','ADC/module network','Alias rejection',
                            'Relay contact/release/bounce','ADC rail-loss hold-up','S05 circuit',
                            'PWM common-mode parasitics','PCB ERC/DRC','Physical testing'])
    (ROOT/'analytical_results.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    with (ROOT/'frequency_response.csv').open('w',newline='',encoding='utf-8') as file:
        writer=csv.DictWriter(file,fieldnames=list(response[0]))
        writer.writeheader();writer.writerows(response)
    print(json.dumps(report,indent=2))
    if not report['all_checks_passed']:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
