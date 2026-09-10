# DOOMFLY attribution and license scope

DOOMFLY is an independent research experiment, not affiliated with or endorsed by
id Software, Bethesda, ZeniMax, Freedoom, Farama Foundation, the dataset creators
or the cited researchers. DOOM and related marks belong to their respective
owners. This statement grants no trademark rights and is not trademark clearance.

## Original project material

The [MIT license](LICENSE) covers the original DOOMFLY Python/C++ code, original
application code, tests, documentation and custom arena definitions. Original
project contributions to generated app graphics are offered under MIT to the
extent the contributors hold rights in them; no exclusive copyright in purely
AI-generated elements is asserted. Existing third-party portions retain their
own terms. MIT does not relicense research data, game artwork or trademarks.

## MaleCNS v1.0 connectome

Credit: the MaleCNS collaboration, including FlyEM at HHMI Janelia, the University
of Cambridge Department of Zoology, the MRC Laboratory of Molecular Biology, and
Google Research, with the authors and contributors identified by the release.

- Dataset and release: https://male-cns.janelia.org/download/
- Paper: https://doi.org/10.1016/j.cell.2026.08.015
- License: [Creative Commons Attribution 4.0 International](licenses/CC-BY-4.0.txt)
  (https://creativecommons.org/licenses/by/4.0/), as linked by the release page.
- Scope: MaleCNS source-derived annotations, connectivity summaries and rendered
  dataset information in `data-provenance/malecns_v1/`, the viewer's data/public
  reports, and experiment outputs. The large original graph is downloaded separately.
- Changes: entries are normalized, explicit non-neuronal/unresolved objects are
  accounted for, and all released edges among retained neurons are preserved.
  Model weights, sensory mappings and analyses are project transformations; they
  are not measurements supplied or validated by the dataset creators.
- Source URLs, immutable input hashes, upstream filters and exact retention rules
  appear in `doom/datasets.json` and `data-provenance/malecns_v1/`.

## Dopamine and memory source data

Huang, C., Luo, J., Woo, S.J. et al. *Dopamine-mediated interactions between short-
and long-term memory dynamics*. Nature 634, 1141–1149 (2024).
https://doi.org/10.1038/s41586-024-07819-w

The article is [CC BY 4.0](licenses/CC-BY-4.0.txt); separately credited third-party
material may have different terms. `research/huang-2024/targets.json` extracts
selected rates and computes summary statistics from the cited supplementary
workbooks. It retains their hashes and source cells. This attribution also covers
copies of those derived targets in archived Doom experiments. The adapted model
is not an author-endorsed reproduction of the complete paper.

The external workbooks and paper PDF are not bundled, including inside ZIPs.
See [retrieval instructions](research/huang-2024/README.md) to obtain them from
the publisher. Existing scientific reports retain original input hashes for
provenance; a recorded hash does not imply the corresponding input is bundled.

## ViZDoom, Freedoom and the arena

The runtime pins ViZDoom 1.3.0 and explicitly selects its installed
`freedoom2.wad`. No commercial Doom campaign IWAD is distributed. The repository's
small WADs contain original map geometry, scripts and/or solid-color experimental
textures. Texture and actor names refer to the separately installed game assets.
Game screenshots and game-derived elements in app/social graphics contain
Freedoom artwork and retain its BSD-3-Clause attribution and disclaimer.

The full [Freedoom and ViZDoom notices](THIRD_PARTY_NOTICES.md) distinguish original
ViZDoom MIT code from the underlying engine's additional licensing. No engine
executable or upstream engine source checkout is bundled. A future redistributed
engine or container must retain all applicable upstream notices and obligations.

The optional arena compiler is [ZDoom ACC](https://github.com/ZDoom/acc/tree/bdb9bc4d2c5aee7ca3ff8da985d73aaf83af0557).
It is not bundled. To rebuild the WAD, clone that revision into `tools/acc/`,
follow its build instructions, and run `python -m doom.combat_arena --acc PATH_TO_ACC`.
Preserve the compiler's source notices if redistributing it. It is not required
at simulation runtime.

## UI and scientific model references

Adapted shadcn/ui components and the viewer's direct package dependencies retain
their full notices in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and `licenses/`.
The Silkscreen font is requested from Google Fonts, not bundled in this repository.
Dependency files themselves are installed from the lockfile.

The LIF framework references Shiu et al. (2024),
https://doi.org/10.1038/s41586-024-07763-9. The upstream model is MIT licensed,
copyright Philip Shiu and Nico Spiller; its original notice is retained in
`licenses/Shiu-model-MIT.txt`. The upstream model checkout is not bundled.
Other scientific papers are cited in the methods and review documents; citing a
paper or implementing an equation does not grant rights to republish its figures.
