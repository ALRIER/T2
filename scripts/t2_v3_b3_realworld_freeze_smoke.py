#!/usr/bin/env python3
"""Small B3 contract check: prevents real-world scoring without original parent freeze."""
from pathlib import Path
import csv
p=Path('config/realworld_v2_zenodo.csv')
rows=list(csv.DictReader(p.open()))
assert len(rows)==1 and int(rows[0]['parent_datasets'])==664
s=Path('scripts/t2_v3_b3_freeze_parents.py').read_text()
assert 'outcome_blind_all_664_crossfamily_evaluation' in s
assert "if len(parents)!=target" in s
sc=Path('scripts/t2_v3_b3_realworld_scoring.R').read_text()
for tok in ('T2_B3_RW_CHILD_REPS','parent_manifest','source_hash','t2_v3_infer_scenario','t2_v3_null_fpr','t2_b3_ram_guard'):
 assert tok in sc,tok
w=Path('.github/workflows/t2-v3-b3-realworld-full.yml').read_text()
assert 'freeze-parents:' in w and w.count('needs: [plan, freeze-parents]')==2
assert w.count('name: T2_V3_B3_frozen_parent_manifest')>=3
print('T2_V3_B3_REALWORLD_PARENT_FREEZE_CONTRACT_PASS')
