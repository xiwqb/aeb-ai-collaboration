"""Independent Python evaluation of the archived simplified CCRs kernel.

The reference stopping gap is a comparison value, never an output assignment.
"""
from pathlib import Path
import json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
g=9.81;dt=.001;v=30/3.6;s=60.;t=0.;on=False;rows=[]
while v>1e-6 and t<20:
    ttc=s/v
    if ttc<=2:on=True
    a=0.
    if on:
        level=.27 if ttc>1.6 else (.52 if ttc>.7 else .80)
        a=-level*g
    rows.append([t,v,s,a/g,ttc])
    vn=v+a*dt
    s=s-v*dt-.5*a*dt**2
    v=max(vn,0.);t+=dt
y=np.array(rows)
archived=np.loadtxt(ROOT/'data/reproduction/signals.csv',delimiter=',')
assert y.shape==archived.shape
assert np.max(np.abs(y-archived))<1e-8
metrics={'trigger_time_s':float(y[np.flatnonzero(y[:,3]<0)[0],0]),
    'gap_last_saved_sample_m':float(y[-1,2]),'gap_after_last_integration_m':s,
    'min_ttc_s':float(np.min(y[:,4])),'peak_decel_g':float(np.max(-y[:,3])),
    'reference_gap_m':5.7,'reference_trigger_s':5.2,
    'third_level_assumed':True,'latch_added':True,'full_paper_reproduced':False}
original=json.loads((ROOT/'data/reproduction/metrics.json').read_text())
for k in ['trigger_time_s','gap_last_saved_sample_m','gap_after_last_integration_m','min_ttc_s','peak_decel_g']:
    assert abs(metrics[k]-original[k])<1e-8,(k,metrics[k],original[k])
out=ROOT/'results/recomputed';out.mkdir(exist_ok=True)
(out/'reproduction.json').write_text(json.dumps(metrics,indent=2),encoding='utf8')
print(json.dumps(metrics,indent=2))
print('PASS: archived trajectory matched; stopping gap remains different from the reference.')
