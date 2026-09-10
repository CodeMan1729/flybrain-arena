# Attribution and license scope

FLYFEAR original code, geometry and generated PCM audio: MIT, see LICENSE.

## MaleCNS v1.0

The MaleCNS collaboration: FlyEM / HHMI Janelia, University of Cambridge
Department of Zoology, MRC Laboratory of Molecular Biology and Google Research,
with all authors and contributors identified by the dataset publication.

- Source: https://male-cns.janelia.org/download/
- Paper: https://doi.org/10.1016/j.cell.2026.08.015
- License: https://creativecommons.org/licenses/by/4.0/
- Local copy of full license: research/CC-BY-4.0.txt
- Changes: retain annotated non-glial neurons, preserve edges among them,
  transform counts into signed normalized weights, engineer input/output groups,
  derive gameplay telemetry and experiment reports. These transformations are
  FLYFEAR modeling choices; no endorsement or physiological validity is implied.

## Research snapshots

DOOMFLY snapshots under research/ are MIT; original copyright/permission text is
in research/doomfly-LICENSE. Its dataset registry and hashes identify the raw
MaleCNS sources. The DOOMFLY simulator/game/artwork are not used by FLYFEAR.
Shiu README/license snapshots retain research/Shiu-LICENSE (MIT). No Shiu
simulator code or paper figures are bundled into the game.

## Runtime dependencies

- Godot 4.5.2: MIT, https://godotengine.org/license/;
  engine third-party notices: https://github.com/godotengine/godot/blob/4.5.2-stable/COPYRIGHT.txt
- Python 3.12.12: Python Software Foundation license, https://docs.python.org/3.12/license.html
- NumPy 2.2.6: BSD-3-Clause, https://github.com/numpy/numpy/blob/v2.2.6/LICENSE.txt
- SciPy 1.15.3: BSD-3-Clause and bundled dependency notices, https://github.com/scipy/scipy/blob/v1.15.3/LICENSE.txt
- PyArrow 20.0.0: Apache-2.0, https://github.com/apache/arrow/blob/apache-arrow-20.0.0/LICENSE.txt
- websockets 15.0.1: BSD-3-Clause, https://github.com/python-websockets/websockets/blob/15.0.1/LICENSE
- psutil 7.0.0: BSD-3-Clause, https://github.com/giampaolo/psutil/blob/release-7.0.0/LICENSE

Downloaded runtime/package directories preserve their upstream notices and are
excluded by .gitignore. If redistributing an executable bundle, retain all
applicable runtime and bundled third-party notices. No commercial game assets,
Doom IWAD, paid fonts, external media, or trademark rights are included.
