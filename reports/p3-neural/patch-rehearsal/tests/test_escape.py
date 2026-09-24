"""Full MaleCNS graph tests; no synthetic weights used for positive results."""
import json
import unittest
import numpy as np
from scipy import sparse
from brain.connectome import Connectome, ROOT


class EscapeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.brain = Connectome()

    def setUp(self):
        self.brain.reset()
        self.assertTrue(hasattr(self.brain, 'escape'), 'Full-graph escape adapter is implemented')

    def probe(self, bearing=0, level=1):
        self.brain.reset()
        return self.brain.step(np.zeros(8), {'level': level, 'bearing': bearing})['escape']

    def test_real_population_ids_and_direct_edges(self):
        b = self.brain
        groups = b.escape.groups
        self.assertEqual({t: sum(len(groups[t+s]) for s in 'LR') for t in b.escape.TYPES},
                         {'LC4':126, 'LPLC2':185, 'DNp01':2, 'DNp03':2})
        self.assertEqual(b.info['escape']['body_ids']['DNp01L'], ['10010'])
        counts = sparse.load_npz(ROOT/'data/counts.npz')
        for pre, post, edges, contacts in [('LC4','DNp01',126,6362), ('LC4','DNp03',126,2507), ('LPLC2','DNp01',185,4862)]:
            a=np.concatenate([groups[pre+s] for s in 'LR']); z=np.concatenate([groups[post+s] for s in 'LR'])
            sub=counts[z][:,a]
            self.assertEqual((sub.nnz, int(sub.sum())), (edges,contacts))

    def test_direction_changes_through_real_neurons(self):
        left=self.probe(-1); right=self.probe(1)
        self.assertLess(left['lateral'], -.5)
        self.assertGreater(right['lateral'], .5)
        self.assertGreater(left['dn']['DNp01L'],left['dn']['DNp01R'])
        self.assertGreater(right['dn']['DNp01R'],right['dn']['DNp01L'])
        self.assertGreater(min(left['strength'],right['strength']),.5)

    def test_zero_input_and_no_direct_motor_drive(self):
        self.assertEqual(self.probe(level=0)['strength'], 0)
        drive=np.zeros_like(self.brain.state)
        self.brain.escape.inject(drive, {'level':1,'bearing':.4})
        for cell in ('DNp01','DNp03'):
            for side in 'LR': self.assertTrue(np.all(drive[self.brain.escape.groups[cell+side]]==0))

    def test_actual_direct_pathway_ablation(self):
        b=self.brain; normal=self.probe(-1)
        original=b.weights
        # Ablate only real LC4/LPLC2 -> DNp01/DNp03 edges, retaining the full graph.
        rows=np.concatenate([v for k,v in b.escape.groups.items() if k.startswith('DN')])
        columns=np.concatenate([v for k,v in b.escape.groups.items() if not k.startswith('DN')])
        b.weights=original.copy()
        for row in rows:
            lo,hi=b.weights.indptr[row:row+2]
            b.weights.data[lo:hi][np.isin(b.weights.indices[lo:hi],columns)]=0
        try:
            ablated=self.probe(-1)
            self.assertLess(ablated['strength'],normal['strength']*.2)
            print('DIRECT_EDGE_ABLATION',json.dumps({'normal':normal,'ablated':ablated}),flush=True)
        finally: b.weights=original;b.reset()

    def test_invalid_threat_preserves_state(self):
        b=self.brain
        for threat in [[], True, {'level':True}, {'level':float('nan')}, {'level':1.01}, {'level':-1},
                       {'bearing':float('inf')}, {'bearing':2}, {'bearing':'0'}]:
            with self.subTest(threat=threat):
                before=b.state.copy()
                with self.assertRaises(ValueError): b.step(np.zeros(8),threat)
                np.testing.assert_array_equal(before,b.state)

    def test_reset_reproducibility_and_legacy_interface(self):
        a=self.probe(.5)
        self.probe(-1)
        self.assertEqual(a,self.probe(.5))
        b=self.brain;b.reset(); legacy=b.step(np.zeros(8));b.reset(); quiet=b.step(np.zeros(8),{'level':0})
        self.assertEqual(legacy['output'],quiet['output'])
        self.assertEqual(legacy['readout'],quiet['readout'])
        self.assertEqual(legacy['escape'],quiet['escape'])


if __name__=='__main__': unittest.main()
