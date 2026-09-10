# Live experimental training — 5 September 2026

The user requested enabling learning on the public stream. We enabled the
existing adaptive-centered-v6 hypothesis as experimental training. Its scientific
validation remains failed. This operational change is not a learning result or a
launch green light for "a fly learning to survive". Historical negative results
remain published, and the previous fixed baseline runs and checkpoints remain.

## Exact loop and anatomical scope

Every game tic supplies actual RGB to 3,335 R1–R6 inputs and 811 inferred R8 inputs.
The complete retained MaleCNS v1.0 graph has 166,700 neurons, 25,582,938 directed
edges and 124,177,617 contacts. No graph cropping or replacement policy is used.
The existing R8-to-aMe12 sign assumptions, KC rest/adaptation and separation of
541 annotated modulatory cells from generic fast excitation are inherited from
v6. They are declared model assumptions, not measured physiology for this male.
Visual coordinates and RGB spectra are proxies; photoreceptors remain simplified
spiking cells. The paper supporting visual input types does not validate our
whole-brain visual response.

Nonfatal damage schedules +4 mV-equivalent current in the two identified PPL101
cells (IDs 11327, 11900), from the next neural interval for exactly 2,000 integration
steps (200 ms). Overlapping hits extend the active interval. Delivered dose is
counted per 0.1 ms step, including pulse endings inside a game tic. Terminal
health loss is logged but excluded from imposed reinforcement. A pending pulse
is cancelled at reset to avoid pairing the previous round’s damage with unrelated
new imagery. These are engineering choices, not natural nociceptor modeling.

Actual KC and PPL101 spikes drive the existing baseline-centered anti-Hebbian
rule on all 4,184 existing KC-to-MBON11 edges (MBON IDs 10704, 11402). It adapts
Huang, Luo et al. (2024); it does not reproduce the paper’s entire memory model.
Eta stays 0.001, KC/DAN trace constants 1 s, memory decay 1,800 s, efficacy filter
50 ms and bounds 0.1–2 times each original strength. Plasticity is updated in at
most 10 ms bins; neural integration remains 0.1 ms. These constants were not tuned
to make three days of attractive gameplay. Damage does not directly set a weight.

The decoder is unchanged: DNp20 right-minus-left rate turns; summed DNpe017 rate
moves; its spikes press fire. Neither health, enemy coordinates, rewards nor
memory metrics select controls. PPL101 and MBON11 are additional spectator
readouts only. The retinal panel displays only the R1–R6 brightness samples;
the memory histogram is computed directly from current KC-to-MBON11 weights.

The combat-survival-v2 arena keeps native attacks and the four-per-type enemy
caps. Death resets the game while neural state, memory traces, efficacy state and
controller filters persist. This continuous live protocol differs from the
historical isolated-trial pilot. Its results must not be pooled with that pilot
or interpreted as improvement over a different baseline model or environment.

## Validity, continuity and verification

Twenty-eight tests passed for pulse timing/dose, frozen controls, full memory and
decoder checkpoint continuation, integrity rejection, broadcast preservation,
existing neural boundaries and candidate v5/v6 mechanics. These are technical
checks. The v6 scientific failures (visual recovery, conditioning and survival)
remain unchanged. Changed weights are not proof of successful learning; previous
memory changes were harmful on one tested start.

Training saves complete mutable brain state, R8 filters, rate traces, efficacies,
queued events, controller filters and reinforcement state in atomic generations.
Two generations are retained; each payload is hashed and configuration/source
identity is checked. Restart restores the brain into a fresh arena with a new run
ID linked to the study. The interrupted round is censored; pending reinforcement
is cancelled for that fresh arena. The live stream does not pretend uninterrupted
game recovery. Per-step audits and hourly compressed archives remain enabled.

The website labels the phase TRAINING ON / EXPERIMENTAL / UNVALIDATED. It shows
measured changed weights, efficacy distribution, delivered damage feedback, and
recent completed-round survival. It reports no improvement score or percent
learned. The public host is still the Mac and its tunnel. Cloud operation,
endurance and audience load are not certified by these tests.

## Sources and remaining evidence

- https://doi.org/10.1038/s41586-024-07819-w — dopamine-mediated memory dynamics;
  source for the adapted centered rule and baseline rate targets.
- https://doi.org/10.1016/j.neuron.2015.11.003 — dopamine-gated KC-to-MBON plasticity.
- https://doi.org/10.1038/s41467-024-49616-z — visual inputs to Kenyon cells.
- https://doi.org/10.1038/s41586-023-06681-6 — R8 cotransmission hypothesis support.

An announcement of learned survival still requires useful sensory responses,
cue-specific conditioning, independent training runs with frozen and shuffled
controls, held-out survival benefit, retention and memory-erasure checks. This
public experiment allows people to observe the attempt, including failure.
