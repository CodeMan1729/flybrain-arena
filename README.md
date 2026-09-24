# FlyBrain Arena

A first-person combat prototype for Windows, forked from [FLYFEAR](https://github.com/furkancak1r/flyfear). You fight a drone whose dodge behavior is driven by a real fly connectome: your threats propagate through actual MaleCNS neurons and out through real anatomical escape pathways, not a scripted dodge routine.

**This is a fork, not the original game.** FLYFEAR was a horror prototype about finding a key and escaping a room while a connectome-driven fly stalked you. FlyBrain Arena replaces that with combat: shoot the drone before it reaches you, and its evasive flight comes out of the same real connectome, now routed through neurons anatomically linked to escape behavior. The upstream project's README, web deployment, and macOS/uv toolchain do not describe this fork; see below for what changed and why.

| Summary | Status |
|---|---|
| Platform | Windows native (Godot 4.5.2 win64); not tested on macOS/web for this fork |
| Combat | Raycast hitscan, 15 damage/hit, 100 HP drone (7 hits to down), 0.35 s cooldown, 25 m range |
| Player | 100 HP, contact with the drone is instant death, not gradual damage |
| Drone dodge | Real MaleCNS connectome: threat signal → LC4/LPLC2 neurons → full 166,700-neuron graph → DNp01/DNp03 readout → dodge direction |
| Drone chase | Engineered controller (fixed speed/accel caps) modulated by the same neural output that drove FLYFEAR's scare events |
| Brain data | MaleCNS v1.0; 166,700 neurons, 25,582,938 directed connections (unchanged from upstream) |
| Latest validation | Full regression + real hitscan/physics smoke test passed at P4; see `STATUS.md` for exact counts |

![FlyBrain Arena: the drone in the room with the live neural activity panel](reports/learning-v3/feedback-open.png)

## Why this fork exists

FLYFEAR already had a real, computed connectome driving a fly's behavior — but only for picking horror sound/light events, never for movement itself. The fly's flight was a hand-written chase rule that read four neuron-group averages as tuning knobs. This fork keeps the real connectome and the honest "what's real vs. what's engineered" discipline from upstream, but asks a different question: can a player's *combat actions* — aiming at the drone, opening fire — become a real sensory input that propagates through actual escape-pathway neurons and comes back out as a dodge?

The answer, verified against the raw connection data rather than assumed: yes, partially. `LC4 → DNp01`, `LC4 → DNp03`, and `LPLC2 → DNp01` are real, weighted, direct anatomical connections in MaleCNS v1.0 (see `docs/ARCHITECTURE_NOTES.md` for the exact edge counts). `LPLC2 → DNp03` is real but negligible. There is no direct connection from the visual input neurons (R1-R6) to LC4/LPLC2, so this fork injects the threat signal directly at LC4/LPLC2 rather than pretending a fabricated visual pathway exists — that's disclosed as an engineering choice, not a rediscovered biological circuit.

## Controls

| Key | Function |
|---|---|
| WASD / mouse | Move / look; real `CharacterBody3D` collision |
| Left mouse button | Fire (raycast hitscan; blocked by walls) |
| F | Toggle flashlight |
| B | Toggle the small live neuron-activity panel (bottom right); on by default |
| V | Toggle the large brain view; pauses the game while open |
| TAB | Latest neural measurement, action, FPS, and memory panel |
| ESC | Pause / resume; quit from the menu |

Win by bringing the drone's HP to 0 (7 hits at 15 damage each). Lose if the drone reaches you — contact is instant, not a health drain. There is no key, no door, and no exploration objective; the map is the original three-room FLYFEAR layout reused as an arena, not as a puzzle to solve.

## Combat and feedback

Firing is a real raycast against the world collision layer (mask includes walls and the drone); a wall between you and the drone blocks the hit, there's no lock-on or damage falloff. A hit shows a brief (0.14 s) marker around the crosshair; a miss shows nothing. Shot, hit, win, and lose each play an independent short original sound; the drone itself uses a mechanical rotor loop instead of the original insect buzz. All of it respects the existing master volume and mute settings, and pauses/clears cleanly on round reset. None of this changes damage, cooldown, speed, or the neural model — `game/combat_feedback.gd` is presentation only.

## How the drone dodges: real neurons, not a script

The drone's chase behavior (`game/drone.gd`) is the same kind of engineered controller FLYFEAR always used for the fly: a fixed pursuit rule (6.4 m/s speed cap, 19.2 m/s² acceleration, both scaled down 20% from upstream's fly tuning) modulated by real neural output. What's new is the *dodge* on top of that chase.

`game/threat_sensor.gd` builds a threat signal from whether you're aiming near the drone, how close your aim ray passes, and whether anything occludes it — accepted shots count, blocked/behind/out-of-range aim doesn't. This is a **predictive** threat signal: it reacts to aim and sustained fire, not to a simulated bullet already in flight, so there's no "undo the hit" mechanic and no invincibility frames hiding behind it.

That signal drives `brain/escape.py`, which injects directly into the real body IDs for LC4 (126 neurons) and LPLC2 (185 neurons) — using the dataset's actual annotated IDs, not placeholders. This shares the *same* `Connectome.step()` call every decision tick already makes for the scare-event system (no second matrix multiply per frame); the escape readout just reads a different pair of output groups from the same propagation. After the standard 24-iteration signed-activity update propagates through the full 166,700-neuron / 25,582,938-edge graph, the readout takes the real activity at DNp01 and DNp03 (2 neurons each side) and turns left/right activity difference into dodge direction, front/back difference into a vertical component.

What's genuinely computed on real data: the connectivity itself, which neurons exist, the sparse matrix-vector propagation, and the DN activity that comes out of it. Zeroing out the LC4/LPLC2 → DNp01/DNp03 edges in a controlled test drops escape strength from 1.0 to 0.088 — the pathway is doing real work, not just passing noise through. What's engineered: the decision to inject at LC4/LPLC2 instead of a real visual pathway (because no such direct connection exists), the threat-sensor math, and the mapping from DN activity to a movement vector. This is not a claim of biological looming detection, calibrated escape-reflex timing, or insect flight dynamics — same disclosure standard upstream held for the fly's original chase behavior.

Escape requests run on their own channel, separate from and non-blocking with the original 2–5 second scare-event decision cadence: a client can have at most one escape request in flight, spaced at least 0.65 s apart, each with an 0.85 s validity window after which a late reply is discarded and the drone defaults to no added dodge. Escape doesn't consume the scare-event budget or affect its learning — the two systems read the same brain, but don't interfere with each other.

## Local setup (Windows)

This fork targets Windows native (not WSL, not macOS). Godot binaries, the Python venv, and connectome data all live inside the project folder — nothing is installed to `C:\` or `/Applications`.

```powershell
git clone https://github.com/CodeMan1729/flybrain-arena.git
cd flybrain-arena
powershell -ExecutionPolicy Bypass -File .\setup.ps1
powershell -ExecutionPolicy Bypass -File .\run.ps1
```

`setup.ps1` finds a Python 3.12 install, creates `.venv`, downloads Godot 4.5.2 win64 into `tools/`, and downloads + prepares the ~1.1 GB MaleCNS v1.0 connectome (hash-verified against `research/source.lock.json`). `run.ps1` calls `setup.ps1` automatically if anything's missing, then launches the game with a random per-run access key and a free local port; a file lock prevents a second instance. See `research/source.lock.json` for the exact pinned MaleCNS file hashes and sizes.

The in-game UI text is Turkish, inherited unchanged from upstream FLYFEAR — this fork did not translate or replace it.

## Validation and tests

```powershell
powershell -ExecutionPolicy Bypass -File .\test.ps1 -SkipSmoke   # Python + offline Godot checks, no game launch
powershell -ExecutionPolicy Bypass -File .\test.ps1              # adds a real combat smoke test end-to-end
```

Coverage includes: real full-graph connectome computation (not mocked), the LC4/LPLC2 → DNp01/DNp03 pathway (including edge-ablation and left/right-input-reversal checks against the real weight matrix), hitscan damage and cooldown against real physics, drone HP reaching 0 triggering win, player contact triggering loss, settings save/reset/corruption recovery, and a full round played through a real Godot client talking to a real WebSocket backend. `docs/ARENA.md` has the current one-page usage summary; `STATUS.md` has the full, dated history of what was built, tested, and rolled back at each stage — read that before assuming any specific behavior is finalized, since P2 (combat numbers) and P3 (dodge pathway) were both tuned across multiple playtest rounds.

## What upstream FLYFEAR had that this fork removed

The key search across three rooms, the door/exit win condition, the web deployment (`web/`), and the macOS/uv toolchain are **not part of this fork** — `has_key`/`door_open`/`interact()` and the related game state were deleted outright rather than kept as unused compatibility shims. If you're looking for the original horror game, use [upstream](https://github.com/furkancak1r/flyfear) directly; this repository only makes sense as the combat variant.

## The numerical model: what's real, what's engineering

This section is unchanged from upstream's disclosure standard, because the same model underlies both games' neural computation.

`C[post, pre]` is the real contact count between two neurons; `s(pre)` is +1 for ACh, −1 for GABA/glutamate/histamine, 0 for unknown and for dopamine/serotonin/octopamine (a simplification, since receptor context isn't in the dataset). 3,718 neurons have an output sign of 0. The update rule:

```text
W[j,i] = C[j,i] * s(i) / max(1, sum_i C[j,i])
a ← a + 0.35 * (tanh(1.5 * W @ a + drive) - a)
```

runs 24 iterations per decision tick over the real 166,700-neuron, 25,582,938-edge sparse graph (124,177,617 synaptic contacts before edge-weight collapsing). This is not the DOOMFLY LIF core or a reproduction of the Shiu et al. model; it's a small, auditable signed-activity-deviation model with no random edges, no synaptic learning, and no calibrated biological time constant. Full detail — including the input/output neuron ID mapping, why R1-R6 can't reach LC4/LPLC2 directly, and the FLYFEAR-era scare-event budget/learning system this fork left intact — is in `docs/ARCHITECTURE_NOTES.md`.

## Data and license

MaleCNS v1.0 connectivity data is unchanged from upstream: [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), source at the [MaleCNS download page](https://male-cns.janelia.org/download/), credited to the MaleCNS collaboration (FlyEM/HHMI Janelia, Cambridge Zoology, MRC LMB, Google Research). Raw `.feather` files and derived `.npz`/`.npy` matrices are not in this repo; `setup.ps1` downloads and verifies them against `research/source.lock.json`. See `THIRD_PARTY.md` for full attribution, including DOOMFLY and Shiu et al. reference material this project studied but does not bundle or reproduce code from.

Original FLYFEAR code and FlyBrain Arena's changes are [MIT](LICENSE). This is an unofficial fork; DOOMFLY, the MaleCNS data authors, Godot, and the original FLYFEAR author have not endorsed it.

## Project structure

| Path | Contents |
|---|---|
| [game/](game/) | Godot scene: player, drone (`drone.gd`), threat sensor, combat feedback, WebSocket client |
| [brain/connectome.py](brain/connectome.py) | Real connectome loader and signed-activity propagation |
| [brain/escape.py](brain/escape.py) | LC4/LPLC2 → DNp01/DNp03 dodge pathway on top of the same connectome |
| [brain/director.py](brain/director.py) | Scare-event budget/learning system, unchanged from upstream |
| [brain/server.py](brain/server.py) | Local WebSocket backend serving both scare-event decisions and escape requests |
| [data/](data/) | Derived connectome graph, neuron ID mappings, manifest (raw `.feather`/`.npz` gitignored) |
| [tests/](tests/) | Python and real-Godot-client checks, including escape-pathway ablation tests |
| [docs/ARENA.md](docs/ARENA.md) | Current one-page usage summary |
| [docs/ARCHITECTURE_NOTES.md](docs/ARCHITECTURE_NOTES.md) | Full data-flow trace and real-vs-engineered breakdown |
| [research/](research/) | Pinned MaleCNS/DOOMFLY/Shiu source hashes and license snapshots |
| `logs/`, `reports/` | Local session logs and per-stage validation evidence (gitignored except curated reports) |
| [setup.ps1](setup.ps1) / [run.ps1](run.ps1) / [test.ps1](test.ps1) | Windows setup / launch / validation |
| [STATUS.md](STATUS.md) | Dated build/test/rollback history — the authoritative source of current state |
