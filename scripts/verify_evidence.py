"""Recompute the paper's quantities from the published sample records."""
from pathlib import Path
import csv,hashlib,json
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
cases=json.loads((ROOT/'data/cases.json').read_text(encoding='utf8'))
reference=json.loads((ROOT/'results/verification/original_audit.json').read_text(encoding='utf8'))
expected={c['id']:c['native'] for c in reference['cases']}
results=[];sim_baseline=None;sim_repeat=None

# Verify that gzip decoding recovers the exact original export, not just a
# numerically similar downsampled series.
import gzip
for entry in json.loads((ROOT/'data/provenance.json').read_text(encoding='utf8')):
    with gzip.open(ROOT/entry['published_file'],'rb') as f:
        actual=hashlib.file_digest(f,'sha256').hexdigest()
    assert actual==entry['sha256'],entry['published_file']

for c in cases:
    folder=ROOT/'data/cases'/c['id']
    s=np.loadtxt(folder/'signals.csv.gz',delimiter=',')
    trigger=np.loadtxt(folder/'trigger.csv.gz',delimiter=',')
    with np.load(folder/'native_selected.npz',allow_pickle=False) as z:
        native=z['values'].astype(float);dt=float(z['dt']);t0=float(z['t0'])
    assert s.shape==(100001,7) and native.shape==(100001,4)
    t=t0+dt*np.arange(len(native))
    assert np.allclose(t,s[:,0],atol=1e-12,rtol=0)
    v,ax,x,pressure=native.T
    assert abs(v[0]-c['speed_kmh'])<1e-5
    stop=np.flatnonzero(v<=.5);first=np.flatnonzero(trigger[:,1]>.5)[0]
    residuals={
        'Vx':float(np.max(np.abs(v-s[:,1]))),
        'Xo':float(np.max(np.abs(x-s[:,3]))),
        'Ax_aligned':float(np.max(np.abs(ax[:-1]-s[1:,2]))),
        'pressure_aligned':float(np.max(np.abs(pressure[1:]-s[:-1,6])))}
    assert max(residuals.values())<1e-5
    values=dict(min_gap_m=float(np.min(50-x)),
        stop_time_s=float(t[stop[0]]) if stop.size else None,
        trigger_time_s=float(trigger[first,0]),
        relay_switch_count=int(np.sum(np.abs(np.diff(trigger[:,1]))>.5)),
        peak_pressure_MPa=float(pressure.max()),
        final_v_kmh=float(v[-1]),displacement_m=float(x[-1]-x[0]),
        integral_position_error_m=float(np.trapezoid(v/3.6,t)-(x[-1]-x[0])))
    assert abs(values['integral_position_error_m'])<.0006
    for k,val in values.items():
        exp=expected[c['id']][k]
        assert (val is None and exp is None) or (val is not None and exp is not None and abs(val-exp)<1e-8),(c['id'],k,val,exp)
    results.append(dict(id=c['id'],**values,aligned_residuals=residuals))
    if c['id']=='hold_50':sim_baseline=s.copy()
    if c['id']=='hold_50_repeat':sim_repeat=s.copy()
    print(c['id'],'OK',flush=True)

meta=json.loads((ROOT/'data/cases/hold_50/native_all_metadata.json').read_text())
repeat_meta=json.loads((ROOT/'data/cases/hold_50_repeat/native_all_metadata.json').read_text())
assert meta['names']==repeat_meta['names'] and len(meta['names'])==690
different=[];equal_count=0
for start in range(0,690,meta['partition_width']):
    name=f'native_full_{start:03d}.npz'
    with np.load(ROOT/'data/cases/hold_50'/name,allow_pickle=False) as z:a=z['values']
    with np.load(ROOT/'data/cases/hold_50_repeat'/name,allow_pickle=False) as z:b=z['values']
    assert a.shape==b.shape and a.shape[0]==100001
    for j in range(a.shape[1]):
        if np.array_equal(a[:,j],b[:,j],equal_nan=True):equal_count+=1
        else:different.append(meta['names'][start+j])
assert equal_count==687
assert set(different)=={'T_Real_Elapsed','T_Real_Last','T_Real_Step'}
assert np.array_equal(sim_baseline,sim_repeat)
out=ROOT/'results/recomputed';out.mkdir(exist_ok=True)
report={'status':'PASS','cases':results,'repeatability':{'exactly_equal_native_channels':equal_count,'different_channels':different,'all_simulink_columns_exactly_equal':True},'limits':reference['limits']}
(out/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print('PASS: six cases, unit/kinematic checks, aligned channels and 687/690 repeatability verified.')
