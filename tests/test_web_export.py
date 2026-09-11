import json
from pathlib import Path
import re
import tempfile
import unittest

from tools.export_web import publish_export


class WebExportTest(unittest.TestCase):
    def test_warm_cache_and_open_loader_keep_matching_assets(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory) / 'source', Path(directory) / 'web'
            source.mkdir()
            config = {'executable': 'index', 'fileSizes': {'index.wasm': 4, 'index.pck': 4}}
            (source / 'index.html').write_text('<script src="index.js"></script>\nconst config = ' + json.dumps(config) + ';\n')
            for name in ('index.js', 'index.wasm', 'index.pck', 'index.audio.worklet.js'):
                (source / name).write_bytes(b'old!')

            def export():
                publish_export(source, output)
                html = (output / 'index.html').read_text()
                result = json.loads(re.search(r'^const config = (.+);$', html, re.MULTILINE)[1])
                self.assertIn(f'src="{result["executable"]}.js"', html)
                self.assertEqual(result['fileSizes'], {result['executable'] + '.wasm': 4, result['mainPack']: 4})
                for name in (*result['fileSizes'], result['executable'] + '.js', result['executable'] + '.audio.worklet.js'):
                    self.assertTrue((output / name).is_file(), name)
                    self.assertTrue((output / (name + '.gz')).is_file(), name)
                return result

            original = export()
            self.assertEqual(original, export())
            (source / 'index.pck').write_bytes(b'new!')
            new_pack = export()
            self.assertEqual(original['executable'], new_pack['executable'])
            self.assertNotEqual(original['mainPack'], new_pack['mainPack'])
            (source / 'index.audio.worklet.js').write_bytes(b'new!')
            new_engine = export()
            self.assertNotEqual(original['executable'], new_engine['executable'])
            self.assertEqual(new_pack['mainPack'], new_engine['mainPack'])
            self.assertEqual((output / original['mainPack']).read_bytes(), b'old!')
            self.assertEqual((output / (original['executable'] + '.audio.worklet.js')).read_bytes(), b'old!')
            self.assertEqual((output / new_engine['mainPack']).read_bytes(), b'new!')
            self.assertEqual((output / (new_engine['executable'] + '.audio.worklet.js')).read_bytes(), b'new!')
            previous_html = (output / 'index.html').read_bytes()
            (source / 'index.wasm').write_bytes(b'')
            with self.assertRaises(ValueError):
                publish_export(source, output)
            self.assertEqual((output / 'index.html').read_bytes(), previous_html)
