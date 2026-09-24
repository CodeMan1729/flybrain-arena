"""Verify real directed synaptic edges for the visual-escape pathway candidates."""
import json
from pathlib import Path

import numpy as np
from scipy import sparse

ROOT = Path(__file__).resolve().parents[1]

candidates = json.loads(Path('/tmp/escape_candidates.json').read_text())
ids = np.load(ROOT / 'data/ids.npy')
counts = sparse.load_npz(ROOT / 'data/counts.npz')  # [post_idx, pre_idx] raw synapse counts

def idx_of(body_ids):
    body_ids = np.asarray(body_ids, dtype=np.int64)
    pos = np.searchsorted(ids, body_ids)
    pos = np.clip(pos, 0, len(ids) - 1)
    found = ids[pos] == body_ids
    return pos[found], body_ids[found], body_ids[~found]

def check(pre_name, post_name):
    pre_idx, pre_found, pre_missing = idx_of(candidates[pre_name])
    post_idx, post_found, post_missing = idx_of(candidates[post_name])
    print(f'{pre_name} -> {post_name}: {len(pre_found)}/{len(candidates[pre_name])} pre found, '
          f'{len(post_found)}/{len(candidates[post_name])} post found in graph')
    sub = counts[np.ix_(post_idx, pre_idx)]
    nnz = sub.nnz
    total_weight = int(sub.sum())
    print(f'  real directed edges: {nnz}, total synapse weight: {total_weight}')
    if nnz:
        coo = sub.tocoo()
        top = np.argsort(coo.data)[-5:][::-1]
        for k in top:
            pre_body = pre_found[coo.col[k]]
            post_body = post_found[coo.row[k]]
            print(f'    {pre_body} -> {post_body}: weight {coo.data[k]}')
    return nnz, total_weight

print('=== R1-R6 -> LPLC2 ===')
check('R1-R6', 'LPLC2')
print('=== R1-R6 -> LC4 ===')
check('R1-R6', 'LC4')
print('=== LPLC2 -> DNp01 ===')
check('LPLC2', 'DNp01')
print('=== LPLC2 -> DNp03 ===')
check('LPLC2', 'DNp03')
print('=== LC4 -> DNp01 ===')
check('LC4', 'DNp01')
print('=== LC4 -> DNp03 ===')
check('LC4', 'DNp03')
