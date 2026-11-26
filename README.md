# Americas-Shim

[Русская версия](README.ru.md)

Two separate Rust source snapshots for Windows graphics compatibility and diagnostics. Build each workspace independently from its own directory. The original patches and helper tools are retained for reference; no patches are required to populate the source trees.

| Source tree | Upstream base | Base commit | Local changes included |
| --- | --- | --- | --- |
| [Pareto](pareto/) | [codec-d/cool_fox](https://github.com/codec-d/cool_fox) | `f4b48ad766ddbec1a1867022cd42f7645b0dd55e` | NVIDIA adapter selection and logging; creation-only BVH diagnostics |
| [ztrx](ztrx/) | [greyfinch/ztrx](https://gf.openbay.app/greyfinch/ztrx) | `90b529f878a470fec9bf07b7be316bc769a12232` | Remap timing and creation-only BVH diagnostics |

Both snapshots retain their workspace manifests, lockfiles, Rust sources, tests and licenses. Runtime files, generated data, local notes and experimental captured fixtures are not included. The BCPack binary table is not distributed; decoding requires an authorized local table supplied through `VICTORY_BCPACK_TABLES`. No ownership is asserted without verification, and the Pareto memory-write diagnostic is excluded. The Pareto launcher requires an explicit executable path (`VICTORY_GAME_EXE`).

The Pareto workspace has a pre-existing build failure: `victory-formats::texture::Layout` does not define `bytes_from`, which the GPU crate calls. No runtime or compatibility testing was performed.

## Helpers

| Tool | Required local inputs |
| --- | --- |
| `tools/measure.ps1` | `-GameDir` and `-BundleRoot`; the latter points to an existing Pareto bundle with the expected `release`, `source`, or `capture-runner` layout for the selected mode |
| `tools/warm-ab.ps1` | `-Runner` and `-Executable`; runs an A/B/A diagnostic series |
| `tools/check-bvh-translation.ps1` | `-Runner` and `-ShaderPaths` (three files); checks translation, validation and pipeline creation, not dispatch |
| `tools/summarize-runs.ps1` | `-LogDir` containing local run logs |
| `tools/summarize-remap.py` | A local remap log path |

Supply all runtime inputs locally. Keep logs, captures, caches and other generated data outside this repository. The experimental BVH patch that depended on captured local fixtures is not included. This collection makes no runtime compatibility or performance claims.

## Credits and license

Based on [Marvisak/VIctory](https://github.com/Marvisak/VIctory), [fxceless/victory-fork](https://github.com/fxceless/victory-fork), and the two downstream bases above. The original copyright and license terms remain in effect; see [LICENSE](LICENSE) (GPL-3.0-or-later) and the upstream repositories for their complete contributor credits.
