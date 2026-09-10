import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from scipy import sparse
from brain.connectome import Connectome, ROOT, ACTIONS
from brain.director import Budget, Readout, movement, normalize, reaction

class CoreTests(unittest.TestCase):
    def test_normalization_and_boundary(self):
        t={'x':6,'z':-16,'look_x':1,'speed':3.2,'pause_seconds':3,'retreat':3.2}
        np.testing.assert_allclose(normalize(t),[1,-1,1,0,0,1,1,1])
        self.assertTrue(np.isfinite(normalize({'x':1e9})).all())
        for value in [float('nan'),float('inf'),'4',True]:
            with self.assertRaises(ValueError): normalize({'x':value})
        with self.assertRaises(ValueError): movement({'turn_rate':float('nan')})
        with self.assertRaises(ValueError): movement({'turn_rate':True})
        with self.assertRaises(ValueError): normalize([])

    def test_reward_is_bounded_and_baseline_corrected(self):
        moving={'speed':3.2,'retreat':0,'turn_rate':0}
        reaction_sample={'speed':0,'retreat':3.2,'turn_rate':180}
        self.assertAlmostEqual(reaction(moving,[reaction_sample]),1)
        self.assertEqual(reaction(moving,[moving]),0)
        self.assertEqual(reaction(moving,[]),0)
        still={'speed':0,'retreat':0,'turn_rate':0}
        self.assertEqual(reaction(still,[still]),0)
        self.assertEqual(reaction(reaction_sample,[reaction_sample]),0)
        self.assertLessEqual(reaction(moving,[{'speed':-100,'retreat':100,'turn_rate':9999}]),1)

    def test_same_budget_and_cooldowns(self):
        for mode in ['random','fixed','learn']:
            b=Budget()
            for i,action in enumerate(['lights','steps','silhouette','lights','steps']):
                self.assertTrue(b.commit(action,i*8),mode)
                self.assertFalse(b.commit('silhouette',i*8+.1),mode)
            self.assertFalse(b.commit('lights',41))
            self.assertTrue(b.commit('lights',60))
            self.assertTrue(b.commit('wait',60))
        b=Budget();b.commit('lights',0)
        self.assertFalse(b.allowed('lights',8));self.assertTrue(b.allowed('lights',16))

    def test_learning_external_reproducible_persistent(self):
        with tempfile.TemporaryDirectory() as tmp:
            a=Readout(42,Path(tmp)/'params.json'); b=Readout(42)
            out={'readout':[-.65,-.45,-.2,.175]+[.4]*8}
            self.assertEqual([a.choose('fixed',out)[0] for _ in range(20)], [b.choose('fixed',out)[0] for _ in range(20)])
            before=a.weights.copy();x=a.features(out);a.update('lights',x,1)
            self.assertFalse(np.array_equal(before,a.weights));self.assertEqual(a.updates,1)
            a.save();c=Readout(path=a.path);c.load();np.testing.assert_equal(a.weights,c.weights)
            c.reset();np.testing.assert_equal(before,c.weights)
            a.path.write_text('{"schema":2,"model":"wrong"}')
            with self.assertRaises(ValueError):c.load()

class RealDataTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.brain=Connectome()
    def test_full_data_provenance(self):
        b=self.brain
        self.assertEqual(b.info['neurons'],166700)
        self.assertEqual(b.info['edges'],25582938)
        self.assertFalse(b.info['subnetwork'])
        counts=sparse.load_npz(ROOT/'data/counts.npz')
        self.assertEqual(int(counts.sum(dtype=np.float64)),124177617)
        ids=np.load(ROOT/'data/ids.npy');self.assertTrue(np.all(ids[1:]>ids[:-1]))
        self.assertEqual(counts.nnz,b.weights.nnz)
        mapping=json.loads((ROOT/'data/mapping.json').read_text())
        for key,group in mapping['inputs'].items():
            self.assertEqual([str(ids[i]) for i in group],mapping['input_body_ids'][key])

    def test_end_to_end_actual_wiring(self):
        b=self.brain; b.reset(); output0=b.step(np.full(8,-1))
        b.reset(); output1=b.step(np.full(8,1))
        self.assertGreater(np.max(np.abs(np.subtract(output0['output'],output1['output']))),.01)
        self.assertGreater(output1['active_neurons'],10000)
        self.assertTrue(np.all(np.abs(np.subtract(output0['readout'][4:],output1['readout'][4:]))>.05),
                        'Every downstream context channel must survive the scaling without saturation')
        np.testing.assert_allclose(output1['view_activity'],np.round(b.state[b.view_indices],5),atol=1e-7)
        ids=np.load(ROOT/'data/ids.npy')
        self.assertEqual(b.info['view']['ids'],[str(ids[i]) for i in b.view_indices])
        for pre,post,w in b.info['view']['edges']:
            self.assertAlmostEqual(w,float(b.weights[b.view_indices[post],b.view_indices[pre]]))
        layer=Readout(123)
        self.assertIn(layer.choose('fixed',output1)[0],ACTIONS)
        # Remove the actual edges temporarily: output groups must become silent.
        weights=b.weights;b.weights=sparse.csr_matrix(weights.shape,dtype=np.float32)
        b.reset(); silent=b.step(np.ones(8))
        b.weights=weights;b.reset()
        np.testing.assert_equal(silent['output'],[0,0,0,0])
        np.testing.assert_equal(silent['readout'],[0]*12)
        with self.assertRaises(ValueError): b.step([0]*7)
        with self.assertRaises(ValueError): b.step([float('nan')]*8)

class LearningChecks(unittest.TestCase):
    def test_rating_correction_decay_and_prior_are_persistent(self):
        direct=Readout(5);late=Readout(5)
        x=direct.features({'readout':[-.6,-.4,-.2,.18]+[-.25]*8})
        direct.update('lights',x,0,source='rating');late.update('lights',x,.9)
        for _ in range(7):
            direct.update('steps',x,.4);late.update('steps',x,.4)
        count=late.updates;late.correct('lights',x,.9,0,1)
        np.testing.assert_allclose(direct.weights,late.weights,atol=1e-12)
        np.testing.assert_allclose(direct.cov,late.cov,atol=1e-12)
        self.assertEqual(late.updates,count)
        self.assertEqual(late.summary(),direct.summary())
        with tempfile.TemporaryDirectory() as tmp:
            late.path=Path(tmp)/'personal.json';late.save();loaded=Readout(path=late.path);loaded.load()
            np.testing.assert_array_equal(loaded.weights,late.weights)
            synthetic=Readout(5,Path(tmp)/'prior.json')
            for _ in range(12):synthetic.update('silhouette',x,.8,source='simulation')
            synthetic.save();personal=Readout(5);personal.bootstrap(synthetic.path)
            self.assertEqual(personal.updates,0);self.assertEqual(personal.prior_events,12)
            self.assertEqual(personal.feedback_counts,{'motion':0,'rating':0,'simulation':0})
            np.testing.assert_allclose(personal.weights,synthetic.weights)
            with self.assertRaises(ValueError):personal.bootstrap(late.path)

    def test_context_learning_retention_erasure_and_allowed_actions(self):
        layer=Readout(7)
        contexts=[{'readout':[sign]+[0.]*11} for sign in [-1.,1.]]
        before=layer.weights.copy()
        for k in range(1000):
            item=contexts[k%2]
            action,x,_=layer.choose('learn',item)
            layer.update(action,x,float(action==('lights' if k%2==0 else 'steps')))
        for i,item in enumerate(contexts):
            self.assertEqual(layer.choose('learn',item,explore=False)[0],['lights','steps'][i])
            self.assertEqual(layer.choose('learn',item,allowed=['silhouette'])[0],'silhouette')
            self.assertEqual(layer.choose('learn',item,allowed=[])[0],'wait')
        with tempfile.TemporaryDirectory() as tmp:
            layer.path=Path(tmp)/'memory.json';layer.save()
            saved=Readout(path=layer.path);saved.load()
            np.testing.assert_array_equal(saved.weights,layer.weights)
            corrupt=json.loads(layer.path.read_text());corrupt['updates']=-1
            layer.path.write_text(json.dumps(corrupt))
            with self.assertRaises(ValueError):saved.load()
        layer.reset();np.testing.assert_array_equal(before,layer.weights)
        with self.assertRaises(ValueError):layer.update('wait',np.zeros(13),1)

if __name__=='__main__': unittest.main(verbosity=2)
