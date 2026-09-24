"""Anatomical escape populations; sensory encoding and motor decoding are engineered.

Input starts at LC4/LPLC2, NOT at a simulated retina/looming detector.
All propagation is performed by the existing full-graph signed-rate solver.
"""
import math

import numpy as np
import pyarrow as pa
import pyarrow.compute as pc
import pyarrow.feather as feather


def threat_input(value=None):
    if value is None:
        return 0., 0.
    if not isinstance(value, dict):
        raise ValueError('Threat must be an object')
    result = []
    for key, low, high in [('level', 0, 1), ('bearing', -1, 1)]:
        v = value.get(key, 0)
        if type(v) not in (int, float) or not math.isfinite(v) or not low <= v <= high:
            raise ValueError('Invalid threat ' + key)
        result.append(float(v))
    return tuple(result)


class EscapePathway:
    TYPES = ('LC4', 'LPLC2', 'DNp01', 'DNp03')

    def __init__(self, directory, ids):
        table = feather.read_table(directory / 'annotations.feather', columns=['bodyId', 'type', 'somaSide'])
        table = table.filter(pc.is_in(table['type'], value_set=pa.array(self.TYPES)))
        data = table.to_pydict()
        self.groups = {}
        for cell in self.TYPES:
            for side in ('L', 'R'):
                bodies = np.asarray([b for b, t, s in zip(data['bodyId'], data['type'], data['somaSide'])
                                     if t == cell and s == side], dtype=np.int64)
                indices = np.searchsorted(ids, bodies)
                if not len(bodies) or np.any(indices >= len(ids)) or not np.array_equal(ids[indices], bodies):
                    raise ValueError('Missing escape population: ' + cell + side)
                self.groups[cell + side] = indices
        self.info = {'input_types': ['LC4', 'LPLC2'], 'output_types': ['DNp01', 'DNp03'],
                     'body_ids': {k: [str(ids[i]) for i in v] for k, v in self.groups.items()},
                     'engineering_encoding': True, 'engineering_motor_readout': True,
                     'retinal_looming_simulated': False}

    def inject(self, drive, threat):
        level, bearing = threat_input(threat)
        for cell in ('LC4', 'LPLC2'):
            for side, sign in [('L', -1), ('R', 1)]:
                drive[self.groups[cell + side]] += level * (1 + sign * bearing) * .5

    def read(self, state):
        raw = {key: float(state[group].mean()) for key, group in self.groups.items() if key.startswith('DN')}
        # Soma side is real metadata; interpreting bilateral contrast as a yaw force is engineering.
        left = max(0., raw['DNp01L']) + max(0., raw['DNp03L'])
        right = max(0., raw['DNp01R']) + max(0., raw['DNp03R'])
        return {'dn': raw, 'strength': float(np.clip((left + right) * 4, 0, 1)),
                'lateral': float(np.clip((right - left) * 8, -1, 1)),
                'vertical': float(np.clip((raw['DNp03L'] + raw['DNp03R'] -
                                            raw['DNp01L'] - raw['DNp01R']) * 4, -1, 1)),
                'source': 'full_graph_dnp', 'engineering_readout': True}
