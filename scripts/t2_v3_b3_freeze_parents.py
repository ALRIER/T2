#!/usr/bin/env python3
"""T2 V3 B3 immutable parent-selection gate.
Requires outcome-blind profiles and the historical 664-parent contract.
No model performance enters selection; no silent fallback to a smaller pool.
"""
import csv,hashlib,json,pathlib,sys
base=pathlib.Path(sys.argv[1] if len(sys.argv)>1 else 'artifacts/realworld_regime_matched_v2')
out=pathlib.Path(sys.argv[2] if len(sys.argv)>2 else 'artifacts/T2_V3_B3_realworld_freeze')
out.mkdir(parents=True,exist_ok=True)
config=list(csv.DictReader(open('config/realworld_v2_zenodo.csv',newline='')))
if len(config)!=1:raise RuntimeError('Historical catalog has no unique provenance contract')
target=int(config[0]['parent_datasets'])
if target!=664:raise RuntimeError(f'Unexpected historical catalog count {target}')
records=[]
for p in sorted(base.glob('profile_batch_*/profiles.csv')):
 for r in csv.DictReader(p.open(newline='')):
  if r['load_ok'].lower() not in ('true','t','1'):continue
  raw=p.parent/'raw'/(r['dataset_id']+'.rds')
  if not raw.exists():raise RuntimeError(f'Missing parent scientific data: {raw}')
  if not r.get('raw_sha256'):raise RuntimeError(f'Missing source fingerprint: {raw}')
  import hashlib
  if hashlib.md5(raw.read_bytes()).hexdigest()!=r['raw_sha256']:raise RuntimeError(f'Parent fingerprint mismatch: {raw}')
  r['batch']=p.parent.name
  records.append(r)
parents={}
for r in records:
 pid=r['parent_dataset_id']
 if pid in parents:
  raise RuntimeError(f'Duplicate parent identifier, needs explicit dependency reconciliation: {pid}')
 parents[pid]=r
if len(parents)!=target:
 raise RuntimeError(f'B3 GATE BLOCKED: historical 664 parents required, observed {len(parents)}. Use pinned Zenodo 664 catalog; do not promote a smaller profile pool.')
families=['normal','lognormal','weibull','invgauss','exgaussian','exwald']
rows=[]
for pid in sorted(parents):
 r=parents[pid]
 for family in families:
  rows.append(dict(version='T2_V3_B3',parent_dataset_id=pid,dataset_id=r['dataset_id'],
    family=family,batch=r['batch'],empirical_profile=r['empirical_profile'],
    source_url=r['source_url'],source_hash=r['raw_sha256'],
    selection_rule='outcome_blind_all_664_crossfamily_evaluation'))
p=out/'frozen_parent_family_manifest_T2_V3_B3.csv'
with p.open('w',newline='') as f:
 w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
digest=hashlib.sha256(p.read_bytes()).hexdigest()
(out/'freeze_T2_V3_B3.json').write_text(json.dumps(dict(version='T2_V3_B3',
 parent_count=len(parents),evaluation_families=6,rows=len(rows),manifest_sha256=digest,
 provenance=config[0]['doi'],selection_uses_performance=False),indent=2))
print(f'T2_V3_B3_FROZEN_664_PARENTS_PASS {len(rows)}')
