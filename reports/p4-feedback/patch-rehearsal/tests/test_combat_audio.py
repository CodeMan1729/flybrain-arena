import tempfile
from pathlib import Path
import unittest
import wave
import numpy as np
from tools.generate_combat_audio import generate, DURATIONS, RATE

ROOT=Path(__file__).resolve().parents[1]


class CombatAudioTests(unittest.TestCase):
    def test_bounded_original_assets_and_reproducibility(self):
        with tempfile.TemporaryDirectory() as directory:
            generate(directory)
            for name,duration in DURATIONS.items():
                with self.subTest(name=name):
                    asset=ROOT/'game/audio'/f'{name}.wav'
                    self.assertEqual(asset.read_bytes(),(Path(directory)/asset.name).read_bytes())
                    with wave.open(str(asset)) as sound:
                        self.assertEqual((sound.getnchannels(),sound.getsampwidth(),sound.getframerate()),(1,2,RATE))
                        pcm=np.frombuffer(sound.readframes(sound.getnframes()),dtype='<i2').astype(float)/32767
                    self.assertAlmostEqual(len(pcm)/RATE,duration,places=4)
                    self.assertLessEqual(np.abs(pcm).max(),.1801)
                    self.assertGreater(np.sqrt(np.mean(pcm*pcm)),.01)
                    self.assertLess(abs(pcm.mean()),.002)
                    if name!='rotor':self.assertTrue(np.all(pcm[[0,-1]]==0))
                    else:self.assertLess(abs(pcm[-1]-pcm[0]),.005)


if __name__=='__main__':unittest.main()
