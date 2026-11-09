"""Independent saved-data frequency/refinement checks for Stage 5i."""
from pathlib import Path
import json
import sys
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'python/.deps_stage5h'))
import h5py

FOLDER=ROOT/'matlab/validation_outputs/stage5i'
def signal(file,name):
    with h5py.File(file,'r') as h:
        t=np.asarray(h[f'signals/{name}/time']).ravel()
        y=np.asarray(h[f'signals/{name}/data'])
        y=y.T if y.ndim==2 else y.reshape(-1,1)
    assert y.shape[0]==len(t)
    return t,y

def main():
    nominal=FOLDER/'results_nominal.mat'
    refined=FOLDER/'results_refined.mat'
    old=ROOT/'matlab/validation_outputs/stage5h/results_nominal.mat'
    report={}
    checks=[]
    tn,fn=signal(nominal,'freq');tb,fb=signal(old,'freq')
    prefix=(tn<.5)
    difference=np.max(np.abs(fn[prefix,0]-np.interp(tn[prefix],tb,fb[:,0])))
    checks.append({'name':'before_enable_matches_saved_primary_frequency',
                   'max_abs_difference_Hz':float(difference),'threshold_Hz':1e-6,
                   'pass':bool(difference<=1e-6)})
    last=tn>=tn[-1]-1
    error=np.max(np.abs(fn[last,0]-50))
    checks.append({'name':'all_last_second_samples_within_50_plus_minus_0_005Hz',
                   'max_abs_error_Hz':float(error),'pass':bool(error<=.005)})
    t,d=signal(nominal,'sec_delta_P_pu')
    checks.append({'name':'correction_stays_in_declared_bounds',
                   'min_pu':float(d.min()),'max_pu':float(d.max()),
                   'pass':bool(d.min()>=-.5-1e-12 and d.max()<=.8+1e-12)})
    t,p=signal(nominal,'sec_P_ref_pu')
    err=float(np.max(np.abs(p-d-1)))
    checks.append({'name':'P_ref_equals_one_pu_plus_correction','max_abs_error_pu':err,'pass':err<1e-12})
    if refined.exists():
        tr,fr=signal(refined,'freq')
        grid=np.arange(0, min(tn[-1],tr[-1])+1e-8,1e-4)
        diff=np.max(np.abs(np.interp(grid,tn,fn[:,0])-np.interp(grid,tr,fr[:,0])))
        checks.append({'name':'halved_step_full_frequency_trace',
                       'max_abs_difference_Hz':float(diff),'threshold_Hz':.001,'pass':bool(diff<=.001)})
        nr=json.loads((FOLDER/'report_nominal.json').read_text())
        rr=json.loads((FOLDER/'report_refined.json').read_text())
        for key,tolerance in [('final_frequency_Hz',.0005),('final_sec_delta_P_pu',.005)]:
            diff=abs(nr[key]-rr[key]);checks.append({'name':'halved_step_'+key,
                'absolute_difference':diff,'threshold':tolerance,'pass':diff<=tolerance})
        for key in ['phase_voltage_rms_V','load_current_rms_A']:
            a=np.array(nr[key]);b=np.array(rr[key]);difference=float(np.max(np.abs(a-b)/np.maximum(np.abs(b),1e-12)))
            checks.append({'name':'halved_step_'+key,'max_relative_difference':difference,
                           'threshold':.01,'pass':difference<=.01})
        checks.append({'name':'both_full_run_reports_pass','pass':bool(nr['pass'] and rr['pass'])})
    report.update({'checks':checks,'refinement_available':refined.exists(),
                   'pass':all(c['pass'] for c in checks),
                   'scope':'Saved-data regression and numerical refinement; not physical hardware qualification.'})
    path=FOLDER/'independent_result_checks_2026-11-06.json'
    path.write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))
    assert report['pass']

if __name__=='__main__':main()
