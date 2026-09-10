# Fly Brain / Doom — neuroscience and implementation review

Reviewed 5 September 2026. Scope: the live male Doom experiment, its source data,
neural solvers, visual input, decoder, optional reinforcement, and public telemetry.

**Verdict:** this is a real, closed-loop, connectome-based simulation controlling
a real Doom-engine scenario. It is not a validated emulation of fly vision,
natural action selection, or learning. The data import is correct under its
declared inclusion policy. Several biological assumptions remain unsupported.
A shared numerical error was found and corrected during this review.

The defensible description is: **“A full retained MaleCNS connectome, simulated
with approximate neural dynamics, drives an engineered Doom interface.”**
“A fly understands Doom” and “the fly is learning to play” are not supported.

## Findings and disposition

| Priority | Finding | Disposition |
|---|---|---|
| Critical for a learning claim | No synaptic plasticity, weight updates, or validated memory mechanism exists. | Confirmed absent; public run remains explicitly NO LEARNING. |
| High scientific limitation | Graded visual neurons are replaced by spiking LIF proxies; input geometry and currents are assumed. | Documented; requires biological calibration and a different visual dynamics model. |
| High implementation defect | Incoming synaptic signals were retained during refractory periods, unlike the stated reference equations in Brian2. | Corrected in both backends; independently tested against Brian2. |
| High interpretation risk | The engineered controls remain active with black input and depend strongly on tonic lamina current. | Tested explicitly; kills do not demonstrate image understanding, aiming, or learning. |
| High scientific limitation | Transmitter identity is treated as a fixed outgoing sign; receptors and neuromodulation are omitted. | All edges retained; uncertainty and sensitivity tests reported. |
| Medium reproducibility issue | A stale native binary could be loaded without checking it against the source. | Binary/source checksums enforced; graph and game assets identified in every broadcast. |
| Medium presentation issue | “Left eye / Right eye” labels split an overlapping screen projection; raster columns ignored unequal bin durations. | Labels corrected; raster uses elapsed neural time and rates. |
| Medium interpretation risk | Old validation used one long sensory update and one short game trial. | Added production-cadence interventions and three matched game seeds; legacy results labeled. |
| Medium reproducibility issue | The base game WAD was left to engine discovery. | Explicitly selects packaged Freedoom 2 and reports asset hashes. |

## 1. Which connectome actually runs?

The running graph is **MaleCNS v1.0, one adult male's brain and ventral nerve
cord**. The official download page links exactly the annotation, neurotransmitter,
and connection files used here. All three downloaded files were compared with
the official GCS object's checksum and size. Local SHA-256 checksums also match
the immutable local source lock. [Official MaleCNS downloads](https://male-cns.janelia.org/download/).

The independent audit did not call the importer to verify itself. It rejoined
every raw connection using a separate pandas index, compared every normalized
endpoint and contact count, and checked the complete sorted runtime CSR graph.

| Quantity | Verified value |
|---|---:|
| Retained annotated neuron candidates | 166,700 |
| Directed connection rows retained | 25,582,938 |
| Synaptic contacts represented | 124,177,617 |
| Single-contact connections retained | 10,299,701 |
| Self-connections retained | 101 |
| Raw connection rows examined | 151,856,684 |
| Raw synaptic contacts examined | 311,833,243 |
| Retained entries explicitly labeled glia | 0 |

“Full” means **all released connections between retained neuronal entries**.
The model retains entries with an assigned neuronal superclass, including
uncertain classifications and incomplete tracing. It excludes 33,013 unresolved
annotation objects and 11,864 explicitly non-neuronal objects. Edges whose
endpoints are outside the retained set are accounted for, not silently pruned.
The released source already uses a synapse confidence threshold of 0.5. It is
not every biological synapse in a living animal, a complete physiological state,
or a claim that all reconstruction errors have been resolved.

The audit also checks cell-type and neurotransmitter joins, readout IDs/sides,
all sensory population memberships, inferred retinal columns, projection
confidence calculations, and UV coordinates. Exact integer IDs are preserved;
there is no float conversion or male/female ID mixing.

The separate female dataset is BANC materialization 888, detector v2. It is
**not active in Doom**. Female retinal correspondence remains unresolved and
the preparation code refuses to substitute the male map. This review verifies
the active male graph; it is not a new full re-audit of the female import.

Evidence: `outputs/doom/audit/data-integrity.json`,
`official-source-check.json`, `retinal-projection.json`, `doom/audit_data.py`,
`doom/audit_retina.py`, and `doom/audit_remote.py`.

## 2. What “viewing a frame” means here

The input is the real, current ViZDoom RGB screen buffer. No enemy positions,
depth buffer, labels, map, or object state enter the visual sampler or decoder.
Bilinear sampling converts sRGB to linear-light human-weighted luminance at
3,335 inferred R1–R6 receptor coordinates. Forty-two additional R1–R6 entries
remain in the graph without assigned external pixels. R7/R8 color inputs,
ocelli, optical blur, photon noise, and fly spectral sensitivity are not modeled.

The coordinates are inferred from each receptor's weighted contacts onto
hex-annotated L1/L2/L3 cells. That inference is structurally reproducible. Its
modal-column contact fraction is **not a measured probability of correct
retinal placement**. Left and right columns are mapped onto overlapping,
arbitrarily oriented screen viewports; neither optical angles nor eye pose
have been calibrated. The mapped inputs are asymmetric: 1,107 on the left and
2,228 on the right. This may bias the input-output relationship; a correct
structural import does not imply a balanced or complete visual stimulus model.

The input transform is a chosen model:

```
L_filtered ← L_filtered + (1 − exp(−interval_ms/10)) (L_frame − L_filtered)
receptor drive = 30 × L_filtered / (0.02 + L_filtered)  [mV equivalent]
L1/L2/L3/L5 tonic drive = 12 mV equivalent
```

The filter updates once per game interval; that interval's filtered current is
then held throughout the neural substeps. Thus 0.1 ms neural integration does
**not** imply 0.1 ms visual filtering or a continuous phototransduction model.
It is a discrete low-pass filter, not calibrated light adaptation. Long single
calls and multiple short calls need not produce the same neural response.
New experiments use the production 35-Hz frame cadence instead of a single
500 ms sensory update.

Most importantly, early fly visual neurons often communicate through graded
voltage and transmitter release, which the uniform spiking model cannot
faithfully reproduce. Published connectome-constrained visual models use
graded dynamics, cell-type parameters and independent physiological comparisons.
Their success does not transfer to this different model simply because its
connectome is larger. [Lappalainen et al., 2024](https://www.nature.com/articles/s41586-024-07939-3).

**Required scientific validation:** measured geometry; contrast/flash responses;
ON/OFF polarity; T4/T5 direction tuning; optic-flow responses and response
latencies against held-out recordings. None is established by killing a monster.

## 3. Neural interactions and the corrected numerical error

Each retained cell uses the same point-neuron equations:

```
dv/dt = (−52 mV − v + external_drive + g) / 20 ms
dg/dt = −g / 5 ms
spike: v > −45 mV; reset v = −52 mV and g = 0
refractory period = 2.2 ms; synaptic delay = 1.8 ms; dt = 0.1 ms
edge increment = contact_count × 0.275 mV × presynaptic_sign
```

This borrows constants and a LIF framework from the published Shiu model, whose
feeding/grooming predictions were experimentally tested. It is not a direct
replication of that study: different connectome, direct visual current instead
of its Poisson optogenetic-style input, and different task and output interface.
The reference also removes refractoriness for its directly stimulated Poisson
targets; this Doom proxy does not. [Shiu et al., 2024](https://www.nature.com/articles/s41586-024-07763-9).

**Confirmed defect:** both local solvers froze `g` during refractoriness but
still added incoming weights. Brian2's `unless refractory` makes the variable
read-only, including synaptic writes. A strong autapse and convergent excitation/
inhibition exposed 39 mismatched neuron/time bins in a 4-cell, 90 ms test before
the fix. Both solvers now discard those arrivals and resume integration at the
correct boundary. The independent oracle checks exact spike bins and membrane/
synaptic states within 0.002 mV, including batched execution and changing drive.
[Brian2 2.5.1 refractory semantics](https://brian2.readthedocs.io/en/2.5.1/user/refractoriness.html).

The author code was inspected at commit
`91bdd1e7dcf193f3e7ca5a8933497fcef63b7960` in
[the published model repository](https://github.com/philshiu/Drosophila_brain_model/blob/91bdd1e7dcf193f3e7ca5a8933497fcef63b7960/model.py).
The native optimization skips only subthreshold evolution that cannot spike
without a new input; it does not delete neurons or weak edges. Dense/native
comparisons and the independent Brian2 oracle test this distinction. Numerical
agreement validates implementation of the declared equations, not biology.

**Remaining limits:** no cell-specific time constants, dendritic compartments,
voltage-dependent conductances, receptor reversal potentials, electrical
synapses, or calibrated background activity. Contact counts are structural
measurements, not measured conductances. Strong inhibition can push voltages
below −100 mV in the tested model; they are model states, not plausible neural
recordings. There is no biological validation of transferring one global gain
from the older brain model to this larger brain-plus-VNC reconstruction.

## 4. Transmitter signs and internal state

ACh is assigned positive output; GABA, glutamate and histamine negative output.
Unclear, missing and modulator-only annotations use the explicit positive-sign
assumption: 3,718 cells. All connections remain present. This is a coarse
computational convention, not a receptor-resolved model. Target receptor types
can change the effect of a transmitter; even visual models with sign priors
use known receptor exceptions. [Visual-model methods](https://www.nature.com/articles/s41586-024-07939-3).

In particular, representing a dopaminergic neuron as an ordinary fast excitatory
cell does **not** implement dopamine concentration, receptor signaling, reward,
plasticity, motivation, hunger, satiety, or a biological internal state. Reversing
the uncertain signs is an informative sensitivity test, not a substitute for
resolving those mechanisms. The result is not a model of individual personality.

## 5. How neural output becomes Doom actions

The default decoder reads four actual retained cells, with verified IDs:

| Cell | Source ID | Engineered use |
|---|---:|---|
| DNp20 right | 10059 | Right-minus-left rate → turn |
| DNp20 left | 10162 | Right-minus-left rate → turn |
| DNpe017 left | 10527 | Summed rate → forward; any spike → attack |
| DNpe017 right | 555871 | Summed rate → forward; any spike → attack |

Counts are converted to rates with a 100 ms exponential filter. Turn is
`clip(0.12 × (right_Hz − left_Hz), −6, 6)` degrees per game tic. Forward is
`clip(0.4 × summed_Hz, 0, 20)` in the game's movement scale. A DNpe017 spike
presses attack for one tic. The decoder receives no score, object coordinates,
pixels, or target detector. Zero neural counts remove new attack commands;
the filtered movement rates decay over time.

These cells/gains were selected after observing responses. That selection is
an engineered brain-computer interface, not preregistered evidence of native
fly motor meaning. There is no fly “shooting neuron.” The DNa02/DNp09/MDN/MN9
alternative is only a biological-role comparison, also using engineered game
mappings. Steering evidence supports studying DNa02; it does not establish our
screen geometry, game gain, or transfer to every state.
[DNa02 steering study](https://elifesciences.org/articles/102230).

The fly body, muscles and proprioceptive feedback are absent. Neural spikes do
cause genuine game inputs, but the resulting game motion is produced by Doom
physics, not validated fly biomechanics. The scenario's weapon rules remain in
the engine; no claim is made that all native Doom aiming/weapon assistance has
been disabled. No additional aiming policy enters our decoder.

## 6. Reward is not learning

The public run has reward stimulation **off**. The optional experiment takes
positive game reward and schedules a nominal 200 ms, 30 mV-equivalent current
to 23 LB3c cells, with onset/offset quantized to frame intervals. Their sugar
identity is a cell-type/homology assumption, not a new physiological validation.
The audit log now distinguishes stimulation actually applied this step from
stimulation scheduled after the resulting reward.

There are **no synaptic updates**, eligibility traces, dopamine-dependent
plasticity or learning checkpoints. Weights remained byte-identical through
the new tests. Persistent membrane state across episodes is dynamics, not
evidence of learned skill. A reward pulse perturbing activity is not training.

Real flies can learn visual associations, with mushroom-body and dopaminergic
circuits involved in specific experimental paradigms. That motivates a future
model; it does not validate attaching an arbitrary score to a sensory current.
[Vogt et al., 2014](https://elifesciences.org/articles/02395),
[visual pathways to mushroom bodies](https://elifesciences.org/articles/14009).

A defensible learning experiment requires identified sensory/reinforcement
paths, compartment-specific plasticity supported by physiological data,
explicit state and weight measurements, and frozen-decoder evaluation. Compare
pretraining/post-training behavior with no reward, shuffled or yoked reward,
plasticity disabled, and held-out game seeds. Demonstrate retention and loss of
the effect under a relevant causal intervention before claiming learning.

## 7. The actual game and broadcast

ViZDoom 1.3.0 runs the packaged `defend_the_center` scenario with explicitly
selected Freedoom 2 assets. This is a real Doom-engine executable and scenario,
not a JavaScript visual imitation or the commercial campaign. The scenario is
a short arena designed for reinforcement-learning experiments; success in it
does not demonstrate general Doom ability.
[ViZDoom scenario documentation](https://vizdoom.farama.org/environments/default/).

Every iteration samples the current frame, advances the neural model by 285 or
286 substeps, decodes spikes, and advances the game by exactly one tic. Neural
and game time remain aligned to within 0.1 ms. The displayed JPEG is the
**pre-action input** frame; game counters describe the **post-action** state.
Both ticks are now explicit. The raw RGB hash and compressed JPEG hash are
distinct; hashes establish correspondence and reproducibility, not proof of
biological fidelity.

The raster shows binned simulated spike rates for 128 fixed, identified sampled
neurons across four populations. It is not every cell or an electrophysiology
recording. The brightness panel shows 1 in 8 raw receptor input samples, not
firing rates or conscious visual experience. Its eye viewports overlap. Retinal
cell IDs, sides, filtered brightness, injected drive, and measured spike counts
are available in the feed for tracing the input transform.

The native source/binary, graph, game assets and Python source are fingerprinted.
The runtime rejects an unverified binary or changed graph. Only read-only
`/state` and `/health` are exposed through the tunnel. The public viewer handles
stale data explicitly, rather than replaying a prerecorded run as live.

**Operational limit:** a live broadcast is not necessarily a 1×-speed simulation.
The displayed ratio reports actual speed. The broadcaster runs on the current
host, so its sleep, disconnection or process termination stops the broadcast.
Reliable 24/7 access still requires an always-on compute service and stable
origin; the website itself does not execute the full graph in visitors' browsers.

## 8. Evidence from this review

The machine-readable results are in `outputs/doom/audit/experiments.json`.
They include eight matched, fixed-frame conditions at the production sensory
cadence, followed by three game seeds under intact vision, black input, and
clamped controls. Each closed-loop trial lasts six simulated seconds. The
decoder was not retuned after the numerical correction.

| Seed | Live vision kills | Black input kills | Clamped-control kills |
|---|---:|---:|---:|
| 41027 | 1 | 3 | 0 |
| 41028 | 1 | 3 | 0 |
| 41029 | 1 | 2 | 0 |

Black input outperformed live vision in these short comparisons. This is not a
statistical conclusion about all possible trials, but the experiment provides
no evidence of a visual-performance advantage. Twenty-three automated checks
passed, including the independent single-step and batched Brian2 comparisons.

The essential causal findings are:

- Disconnecting every edge prevents activity reaching the selected controls.
- Removing all external input produces no spikes from the resting state.
- Black visual input still permits controls to fire because lamina current
  supplies a nonvisual drive. Removing that current silences the selected
  controls in the fixed-frame test, even with the original image present.
- Changing or spatially shuffling pixels changes simulated activity, which
  establishes input sensitivity, not correct motion computation or recognition.
- Weight arrays remain unchanged. These trials contain no learning mechanism.

The earlier “three kills in six seconds” example used the pre-review solver
and one seed. It should not be reused as validation of the corrected model.
Old JSON reports and reward probe are retained for historical transparency,
clearly marked as legacy. The review's comparisons supersede their evaluation
claims. A three-seed, six-second test is still too small for a reliable skill
estimate, and all trials share one reconstructed animal.

## 9. What should happen before stronger claims

1. **Validate vision first.** Preserve the full graph, add appropriate graded
   visual-cell dynamics and receptor-specific transmission, and fit only
   declared physiological parameters. Test held-out flash, contrast, motion
   and optomotor responses before returning to Doom.
2. **Resolve the source of action.** Measure blank/still/scrambled inputs,
   remove tonic-drive confounds, perturb relevant pathways, and evaluate a
   frozen neural decoder on matched seeds. Treat natural motor semantics as a
   separate claim requiring body/feedback modeling.
3. **Implement and validate a specific memory mechanism.** Use identified
   synapses and dopamine compartments; record plastic changes. Begin with a
   simple controlled visual choice task. Progress in Doom comes only after
   retention, causal controls and held-out performance establish learning.
4. **Make the experiment reproducible and continuously available.** Publish
   protocols, source locks, tests, run fingerprints and results; deploy the
   broadcaster to stable compute before advertising continuous access.

This review verifies the implementation and locates its scientific limits. It
does not turn an approximate model into a biologically validated fly by changing
labels, choosing more responsive neurons, or adding a hidden game-playing policy.
