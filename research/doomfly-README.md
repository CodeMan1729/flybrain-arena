# DOOMFLY

A fly-connectome simulation connected to a live Doom-engine arena. Game frames stimulate modeled sensory neurons; activity propagates through the retained MaleCNS v1.0 wiring, and a fixed neuron-to-button interface turns, moves and fires. An experimental dopamine-gated memory rule changes a small set of existing connections during play.

**Status: live experimental training, not demonstrated learned survival.** The current v6 candidate failed its visual, conditioning and survival validation gates. Changing weights and longer individual rounds do not establish learning. This repository includes the negative results, controls and modeling assumptions alongside the implementation.

## The loop

1. Each actual ViZDoom frame drives **3,335 R1–R6 brightness inputs and 811 R8 color inputs**. Pixel positions and color responses are inferred proxies.
2. Approximate neural dynamics run on **166,700 retained neurons and 25,582,938 directed connections** from MaleCNS v1.0. No circuit cropping or replacement game policy is used.
3. A fixed interface maps DNp20 right-minus-left activity to turning, and DNpe017 activity to movement and firing. These are engineered controller assignments, not established natural motor functions.
4. Nonfatal damage schedules a **200 ms artificial aversive input into two PPL101 dopamine cells**. KC and dopamine activity drive an adapted plasticity rule on **4,184 existing KC→MBON11 connections**. The rest of the wiring and controller remain fixed.
5. Death starts a new arena round while neural state and memory persist. All viewers watch the same experiment.

The wiring comes from a biological reconstruction. The dynamics, retinal interface, artificial reinforcement and controller are models and engineering choices. This is not a literal reconstructed living fly brain. See the [current training protocol](docs/doom-live-training.md), [model review](docs/doom-neuroscience-review.md), and [iteration results](doom-ui/public/learning-iterations.json).

## Repository map

| Path | Contents |
| --- | --- |
| `doom/` | Whole-graph simulator, native kernel, ViZDoom interface, arena and broadcaster |
| `doom_learning/`, `doom_learning_v2/` … `doom_learning_v6/` | Conditioning, plasticity candidates and controlled learning experiments |
| `doom-ui/` | Monochrome spectator website, live telemetry, learning and methods pages |
| `doom/connectome.py`, `doom/datasets.json` | MaleCNS importer and exact input registry |
| `tests/` | Neural, numerical, game, reinforcement and checkpoint checks |
| `docs/`, `outputs/`, `data-provenance/` | Scientific reviews, compact evidence, source snapshots and dataset hashes |
| `deploy/doomfly/` | Prepared container and deployment instructions |

## Run the neural experiment

Use Python 3.11 and a C++ compiler. The full graph needs several GB of RAM and downloaded data; it does not run inside a browser or an edge function. Use the pinned neural requirements below.

```sh
python3.11 -m venv .venv-neural
source .venv-neural/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-neural.txt -r doom/requirements.txt \
  --build-constraint neural-build-constraints.txt
```

Download the three MaleCNS inputs listed in [`doom/datasets.json`](doom/datasets.json) to `connectome_data/malecns_v1/`, using the exact registry filenames. Verify them against [`data-provenance/malecns_v1/source.lock.json`](data-provenance/malecns_v1/source.lock.json). The following downloads missing files and checks every digest before import:

```sh
python - <<'PY'
from pathlib import Path
import hashlib, json, urllib.request
name = 'malecns_v1'
registry = json.loads(Path('doom/datasets.json').read_text())['datasets'][name]
locked = json.loads(Path(f'data-provenance/{name}/source.lock.json').read_text())
root = Path('connectome_data') / name
root.mkdir(parents=True, exist_ok=True)
for filename, url in registry['files'].items():
    target = root / filename
    if not target.exists():
        partial = target.with_suffix('.download')
        urllib.request.urlretrieve(url, partial)
        partial.replace(target)
    with target.open('rb') as stream:
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    if digest != locked[filename]['sha256']:
        raise RuntimeError(f'Source checksum mismatch: {filename}')
(root / 'source.lock.json').write_text(json.dumps(locked, indent=2) + '\n')
PY
python -m doom.connectome malecns_v1
python -m doom.prepare
python -m doom.audit_data
python -m doom.build_kernel
python -m doom.server --model experimental-v6 --learning --port 8766 \
  --audit-dir outputs/doom/local-training \
  --checkpoint-dir outputs/doom/local-training/checkpoints \
  --checkpoint-seconds 300 --resume
```

The default server invocation without `--model experimental-v6 --learning` runs the fixed baseline. Graph preparation also describes the baseline; the explicit model selection and [training protocol](docs/doom-live-training.md) determine the learning behavior. Baseline instructions remain in [`doom/README.md`](doom/README.md).

For numerical checks, run `python -m pytest tests/test_doom.py tests/test_doom_reference.py tests/test_doom_live_training.py -q`. Some broader tests and historical experiments require downloaded graphs or optional upstream research materials. Passing software tests is not evidence of biological validity. Do not run many full-graph jobs concurrently on a small machine.

## Run the viewer

Use Node.js 22.13 or later. In `doom-ui/`, run `npm ci`, create a local `.dev.vars` containing `DOOM_STREAM_ORIGIN=http://localhost:8766`, then run `npm run dev`. `npm run build` builds the viewer. Configuration files containing real origins or credentials stay untracked.

Hosting the viewer alone does not host the simulation. It needs an independently running Python worker and a configured read-only HTTPS origin. A laptop must stay awake and connected. The prepared container has not been certified for cloud operation or audience load. Register your own hosting project before publishing a fork.

## Evidence and publication hygiene

Historical reports and failed experiments are preserved. Large connectome downloads, mutable checkpoints, raw operational logs, dependencies, credentials and the separately generated Twitter banners are excluded. Existing application graphics and scientific plots remain included.

This is a fresh source snapshot with no private Git history. Local paths, temporary hostnames and image metadata were removed where found. Historical source hashes identify the original experimental artifacts; privacy-redacted files or rebuilt archives can have different byte hashes. See [public release notes](docs/public-release.md) for those boundaries and [third-party sources](THIRD_PARTY.md) for upstream materials.

## License and attribution

Original DOOMFLY code is [MIT licensed](LICENSE). Data, game artwork and copied
components retain their own licenses: see [attribution and scope](THIRD_PARTY.md)
and [full third-party notices](THIRD_PARTY_NOTICES.md). DOOMFLY is an independent
research project, unaffiliated with and not endorsed by id Software, Bethesda
or ZeniMax. No trademark rights are granted.
