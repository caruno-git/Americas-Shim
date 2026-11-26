# Americas-Shim

[Русская версия](README.ru.md)

A source-only collection of local Windows graphics compatibility and diagnostics patches for the VIctory family. It is not a standalone runtime or a mirror. Apply each patch to its own base checkout; the two patches are not a stack.

| Patch | Base checkout | Base commit | Scope |
| --- | --- | --- | --- |
| `patches/pareto-nvidia-adapter.patch` | [codec-d/cool_fox](https://github.com/codec-d/cool_fox) | `f4b48ad766ddbec1a1867022cd42f7645b0dd55e` | Opt-in NVIDIA adapter selection (`VICTORY_D3D12_NVIDIA=1`) and adapter logging |
| `patches/ztrx-diagnostics.patch` | [greyfinch/ztrx](https://gf.openbay.app/greyfinch/ztrx) | `90b529f878a470fec9bf07b7be316bc769a12232` | Remap timing and opt-in, creation-only BVH pipeline diagnostics (`VICTORY_BVH_CHECK=1` in diagnostics builds) |

From the matching clean checkout, run `git apply --check <path-to-patch>`, then `git apply <path-to-patch>`. Build using that checkout's instructions.

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
