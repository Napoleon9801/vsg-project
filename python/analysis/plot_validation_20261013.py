"""Plot saved Stage 5e results without rerunning or implying hardware validation."""
from pathlib import Path
import json
import numpy as np
from scipy.io import loadmat
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

ROOT=Path(__file__).resolve().parents[2]
DATA=ROOT/'matlab/validation_outputs/stage5e'


def main():
    report=json.loads((DATA/'validation_stage5e.json').read_text(encoding='utf8'))
    fig,axes=plt.subplots(2,2,figsize=(12,7.5),layout='constrained')
    palette={'nominal':'#64748b','load_step':'#2563eb','source_limit':'#dc2626'}
    labels={'nominal':'Nominal','load_step':'Load step, 4 A source','source_limit':'Load step, 2.7 A source'}
    for name,color in palette.items():
        r=loadmat(DATA/(name+'.mat'),squeeze_me=True,struct_as_record=False)['result']
        t=np.asarray(r.time); y=np.asarray(r.data)
        assert len(t)==len(y) and np.isfinite(y).all()
        columns=[str(x) for x in r.columns]
        for ax,key in [(axes[0,0],'Vdc'),(axes[0,1],'vd'),(axes[1,0],'freq')]:
            ax.plot(t,y[:,columns.index(key)],color=color,lw=1.4,label=labels[name])
    r=loadmat(DATA/'overload.mat',squeeze_me=True,struct_as_record=False)['result']
    t=np.asarray(r.time); y=np.asarray(r.data); c=[str(x) for x in r.columns]
    axes[1,1].plot(t,np.hypot(y[:,c.index('id')],y[:,c.index('iq')]),color='#7c3aed',label='Overload dq current magnitude')
    trip=report['cases']['overload']['trip_time']
    if trip is not None:
        axes[1,1].axvline(trip,color='#b91c1c',ls='--',label=f'Modeled fault at {trip:.3f} s')
    for ax,title,unit in zip(axes.flat,['Finite DC bus','Output d-axis voltage','Virtual frequency','Sampled protection response'],['V','V','Hz','A']):
        ax.set_title(title,loc='left'); ax.set_xlabel('Time (s)'); ax.set_ylabel(unit)
        ax.grid(alpha=.22); ax.legend(fontsize=8,loc='best')
    fig.suptitle('Stage 5e averaged-model checks\nSource limiting causes degraded regulation; these are simulated results',fontsize=14)
    destination=ROOT/'docs/figures/stage5e_robustness_2026-10-13.png'
    fig.savefig(destination,dpi=160)
    print(destination)
    plt.close(fig)


if __name__=='__main__':
    main()
