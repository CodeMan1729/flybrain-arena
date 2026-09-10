"""MaleCNS adapter: real directed wiring, explicitly engineered rate dynamics."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import time

import numpy as np
import psutil
import pyarrow as pa
import pyarrow.feather as feather
from scipy import sparse

ROOT = Path(__file__).resolve().parents[1]
FEATURES = ['x', 'z', 'look_x', 'look_z', 'look_y', 'speed', 'pause', 'retreat']
ACTIONS = ['lights', 'steps', 'silhouette', 'wait']

def prepare():
    started = time.perf_counter()
    registry = json.loads((ROOT / 'research/source.lock.json').read_text())
    for name, info in registry.items():
        with (ROOT / 'data' / name).open('rb') as f:
            if hashlib.file_digest(f, 'sha256').hexdigest() != info['sha256']:
                raise ValueError(f'Source SHA256 mismatch: {name}')
    a = feather.read_table(ROOT / 'data/annotations.feather', columns=['bodyId', 'type', 'superclass', 'status']).to_pydict()
    rows = sorted((i for i in range(len(a['bodyId'])) if a['superclass'][i] and a['status'][i] != 'Glia'), key=lambda i: a['bodyId'][i])
    ids = np.array([a['bodyId'][i] for i in rows], dtype=np.int64)
    types = np.array([a['type'][i] or '' for i in rows])
    if len(np.unique(ids)) != len(ids):
        raise ValueError('Duplicate biological IDs')
    nt = feather.read_table(ROOT / 'data/neurotransmitters.feather', columns=['body', 'consensus_nt']).to_pydict()
    nt_map = dict(zip(nt['body'], nt['consensus_nt']))
    names = [nt_map.get(int(i), 'unclear') for i in ids]
    # Histamine/GABA/glutamate inhibitory; modulators/unknown are neutral in this approximation.
    signs = np.array([1 if n == 'acetylcholine' else -1 if n in ('histamine', 'gaba', 'glutamate') else 0 for n in names], dtype=np.float32)
    del nt, nt_map, a
    pre_list, post_list, weight_list = [], [], []
    source_edges = source_contacts = contacts = 0
    reader = pa.ipc.open_file(pa.memory_map(str(ROOT / 'data/edges.feather'), 'r'))
    for k in range(reader.num_record_batches):
        b = reader.get_batch(k)
        pre, post, weight = [b.column(b.schema.get_field_index(c)).to_numpy(zero_copy_only=False) for c in ('body_pre', 'body_post', 'weight')]
        if pre.dtype.kind not in 'iu' or post.dtype.kind not in 'iu' or np.any(weight <= 0) or not np.all(np.isfinite(weight)):
            raise ValueError('Invalid edge schema or weights')
        i, j = np.searchsorted(ids, pre), np.searchsorted(ids, post)
        keep = (i < len(ids)) & (j < len(ids))
        keep &= (ids[np.minimum(i, len(ids)-1)] == pre) & (ids[np.minimum(j, len(ids)-1)] == post)
        pre_list.append(i[keep].astype(np.int32)); post_list.append(j[keep].astype(np.int32))
        weight_list.append(weight[keep].astype(np.float32))
        source_edges += len(weight); source_contacts += int(weight.sum()); contacts += int(weight[keep].sum())
    matrix = sparse.csr_matrix((np.concatenate(weight_list), (np.concatenate(post_list), np.concatenate(pre_list))), shape=(len(ids), len(ids)))
    del pre_list, post_list, weight_list
    sparse.save_npz(ROOT / 'data/counts.npz', matrix)
    raw_edges = matrix.nnz
    denom = np.maximum(np.asarray(matrix.sum(axis=1)).ravel(), 1)
    matrix.data *= signs[matrix.indices]
    matrix.data /= np.repeat(denom, np.diff(matrix.indptr))
    sparse.save_npz(ROOT / 'data/weights.npz', matrix)
    np.save(ROOT / 'data/ids.npy', ids)
    sensory = np.flatnonzero(types == 'R1-R6')
    inputs = dict(zip(FEATURES, [g.tolist() for g in np.array_split(sensory, len(FEATURES))]))
    outputs = {action: np.flatnonzero(types == cell).tolist() for action, cell in zip(ACTIONS, ['L1', 'L2', 'L3', 'Mi1'])}
    assert all(inputs.values()) and all(outputs.values())
    mapping = {'inputs': inputs, 'outputs': outputs, 'input_body_ids': {k: [str(ids[i]) for i in v] for k,v in inputs.items()},
               'output_body_ids': {k: [str(ids[i]) for i in v] for k,v in outputs.items()},
               'engineering_mapping': True, 'output_types': dict(zip(ACTIONS, ['L1','L2','L3','Mi1']))}
    (ROOT / 'data/mapping.json').write_text(json.dumps(mapping, indent=2))
    report = {'dataset': 'MaleCNS v1.0', 'scope': 'FULL retained annotated neuronal graph; brain + VNC',
              'neurons': len(ids), 'edges': raw_edges, 'synaptic_contacts': contacts, 'source_edges': source_edges,
              'source_contacts': source_contacts, 'excluded_edges': source_edges - raw_edges,
              'neurotransmitters': dict(Counter(names)), 'zero_sign_neurons': int(np.count_nonzero(signs == 0)),
              'signed_nonzero_edges': int(np.count_nonzero(matrix.data)), 'input_count': len(sensory),
              'output_counts': {k:len(v) for k,v in outputs.items()}, 'prepare_seconds': time.perf_counter()-started,
              'rss_mb': psutil.Process().memory_info().rss / 2**20, 'source_sha256': registry,
              'subnetwork': False, 'additional_edge_threshold': None, 'dynamics': 'engineered signed rate deviations, not validated biological emulation'}
    (ROOT / 'data/manifest.json').write_text(json.dumps(report, indent=2))
    print(json.dumps({k:v for k,v in report.items() if k != 'source_sha256'}, indent=2), flush=True)

class Connectome:
    """Replaceable adapter contract: info, reset(), step(normalized[8]) -> dict."""
    def __init__(self, directory=ROOT / 'data'):
        directory = Path(directory)
        self.info = json.loads((directory / 'manifest.json').read_text())
        self.weights = sparse.load_npz(directory / 'weights.npz')
        mapping = json.loads((directory / 'mapping.json').read_text())
        self.inputs = [np.asarray(mapping['inputs'][k]) for k in FEATURES]
        self.outputs = [np.asarray(mapping['outputs'][k]) for k in ACTIONS]
        n=self.info['neurons']
        if self.weights.shape != (n,n) or not np.isfinite(self.weights.data).all():
            raise ValueError('Invalid cached connectivity matrix')
        if any(g.dtype.kind not in 'iu' or not len(g) or np.any(g<0) or np.any(g>=n) for g in self.inputs+self.outputs):
            raise ValueError('Invalid neuron mapping indices')
        self.state = np.zeros(self.weights.shape[0], dtype=np.float32)
        # Eight downstream populations selected only from actual sensory-to-output wiring.
        # These are engineered readouts, not biological action labels or direct telemetry bypasses.
        receivers = np.unique(np.concatenate(self.outputs))
        sensory_edges = self.weights[receivers]
        self.context_groups = []
        for group in self.inputs:
            strength = np.abs(np.asarray(sensory_edges[:,group].sum(axis=1)).ravel())
            self.context_groups.append(receivers[np.argsort(strength)[-32:]])
        # A fixed anatomical sample for display only; all 166,700 cells still simulate.
        a = feather.read_table(directory / 'annotations.feather', columns=['bodyId','somaLocation','superclass']).to_pydict()
        ids = np.load(directory / 'ids.npy')
        positions = {body: pos for body,pos,group in zip(a['bodyId'],a['somaLocation'],a['superclass'])
                     if pos and group in ('ol_intrinsic','cb_intrinsic','ol_sensory','visual_projection')}
        candidates = np.array([i for i,body in enumerate(ids) if body in positions])
        self.view_indices = candidates[np.linspace(0,len(candidates)-1,512,dtype=int)]
        xyz = np.array([positions[ids[i]] for i in self.view_indices],dtype=float)
        xyz = (xyz-xyz.min(axis=0))/np.maximum(np.ptp(xyz,axis=0),1)
        edges = self.weights[self.view_indices][:,self.view_indices].tocoo()
        strongest = np.argsort(np.abs(edges.data))[-160:]
        self.info = {**self.info, 'view': {'ids':[str(ids[i]) for i in self.view_indices],
                     'xyz':np.round(xyz,4).tolist(), 'edges':[[int(edges.col[k]),int(edges.row[k]),float(edges.data[k])] for k in strongest if edges.data[k]!=0],
                     'label':'512 actual soma positions; sampled real edges; full graph simulated'}}
        self.info['context_readout_ids'] = [[str(ids[i]) for i in group] for group in self.context_groups]

    def reset(self):
        self.state.fill(0)

    def step(self, values):
        values = np.asarray(values, dtype=np.float32)
        if values.shape != (8,) or not np.all(np.isfinite(values)) or np.any(np.abs(values) > 1):
            raise ValueError('Expected 8 finite normalized inputs in [-1,1]')
        start = time.perf_counter()
        drive = np.zeros_like(self.state)
        for idx, value in zip(self.inputs, values):
            drive[idx] = 0.2 + 0.8 * (float(value) + 1) / 2
        # ponytail: 24 discrete rate iterations, no biological clock; use calibrated LIF for physiology research.
        for _ in range(24):
            self.state += 0.35 * (np.tanh(1.5 * (self.weights @ self.state) + drive) - self.state)
        out = np.array([self.state[g].mean() for g in self.outputs], dtype=np.float32)
        return {'output': out.tolist(), 'mean_abs': float(np.abs(self.state).mean()),
                'readout': np.r_[np.clip(out/.2,-1,1), [self.state[g].mean() for g in self.context_groups]].tolist(),
                'view_activity': np.round(self.state[self.view_indices],5).tolist(),
                'active_neurons': int(np.count_nonzero(np.abs(self.state) > 0.001)),
                'peak_abs': float(np.abs(self.state).max()), 'latency_ms': (time.perf_counter()-start)*1000,
                'rss_mb': psutil.Process().memory_info().rss/2**20}

def benchmark():
    import resource
    start = time.perf_counter(); brain = Connectome(); load_s = time.perf_counter()-start
    times, outputs = [], []
    for i in range(16):
        result = brain.step(np.sin(np.arange(8) + i * .37))
        times.append(result['latency_ms']); outputs.append(result['output'])
    report = {'load_seconds': load_s, 'decisions': len(times), 'iterations_per_decision': 24,
              'latency_ms': {'p50': float(np.median(times)), 'p95': float(np.percentile(times,95)), 'max': max(times)},
              'rss_mb': result['rss_mb'], 'peak_rss_mb': resource.getrusage(resource.RUSAGE_SELF).ru_maxrss/2**20,
              'neurons': brain.info['neurons'], 'edges': brain.info['edges'], 'subnetwork': False, 'outputs': outputs,
              'input_sensitive': bool(np.ptp(outputs, axis=0).max() > 1e-5)}
    (ROOT / 'reports/brain-benchmark.json').write_text(json.dumps(report,indent=2)); print(json.dumps(report,indent=2))

if __name__ == '__main__':
    p = argparse.ArgumentParser(); p.add_argument('command', choices=['prepare','benchmark']); args=p.parse_args()
    prepare() if args.command == 'prepare' else benchmark()
