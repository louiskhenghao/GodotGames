# Ring Rush expansion validation

**Godot 4.5.1 / macOS / Apple M5 Max / OpenGL Compatibility**, 5 September 2026. This validates the playable desktop build. Signed Android/iOS exports, real ads/billing and physical-device performance remain untested.

## Automated behavior

- `tests/run_tests.gd`: **65 checks, zero failures**. Persistence/backup and future-schema handling, monetization callback safety, input, state transitions, status effects, original timed rounds, rewards and real shared crowd geometry.
- `tests/expansion_tests.gd`: **60 checks, zero failures**. All six character kits, all six techniques and their cooldowns, insufficient coins, duplicate/unknown unlocks, ownership reload, 10/30/50-wave and 25-wave ladder completion, all five ladder venues, per-mode records, duplicate settlement, serialized wave-17 resume including enemy health/status and build, and new menu construction.
- Full-wave completion checks boost HP/damage to reach every transition. They prove finite completion and correct state handling, not final balance.
- `tests/balance_sim.gd` is a separate deterministic bot using **fresh-account Atlas stats**, automatic targeting, nearest-enemy movement and automatic technique/ultimate usage. It chooses available upgrades without test damage/health overrides.

| Bot scenario | Result | Simulated combat time | KOs | Ending level |
| --- | --- | ---: | ---: | ---: |
| Quick Fight | 10 waves cleared | 90.9 s | 74 | 6 |
| Survival 30 | 30 waves cleared | 332.6 s | 375 | 15 |
| Onslaught 50 | 50 waves cleared | 566.5 s | 808 | 23 |

The bot reacts perfectly to the nearest enemy's telegraph, does not spend real time reading upgrade choices, and is not a substitute for people playing. It finished with full health after recovery/sustain upgrades; this suggests there is room for harder enemy patterns and difficulty tuning. Enjoyment and long-term economy are not certified by automation.

## Final crowd stress measurement

Explicit **540 × 960** render target, VSync off, 2× MSAA, 48 animated enemies retained using elevated benchmark health, elemental/orbit effects, physics simulation and HUD updates. 60 warmup frames followed by 180 samples.

| Metric | Final build |
| --- | ---: |
| Median frame interval | **1.875 ms** |
| 95th percentile | **2.889 ms** |
| Draw calls | **282** |
| Scene nodes | **380** |
| Rendered primitives, including passes | **474,472** |

During development, the straightforward version with 48 complete live humanoid rigs was too expensive (about 38 ms median in a smaller default window). Replacing crowd rigs with shared reduced pose meshes addressed that regression. The hero still uses continuous skeletal animation. These intermediate runs used different window sizes and are not a controlled percentage comparison.

`assets/fighters/crowd.res` is approximately **6.6 MB compressed**, down from a 32 MB intermediate bake after unused vertices and channels were removed. Each crowd pose has two mesh surfaces. Geometry and materials are shared across pooled actors. Crack effects add one bounded MultiMesh rather than creating scene objects during a slam.

This short desktop benchmark does not measure phone GPU limits, sustained thermals, battery drain or native mobile overlays. Run `tests/performance.gd` on target hardware before claiming a mobile frame-rate target.

## Visual review

Actual native Godot frames were inspected for the textured boxer, underground ring, street, rooftop, foundry, temple, earthquake effect, fighter unlocks and phone/tablet menu layouts. Street foreground buildings were shortened to keep opponents visible. The showroom was reframed to separate the fighter from its nameplate. The lower combat HUD has a contrast gradient over scenery.

Captures are staged engine renders, not concept art. UI supports safe-area insets and second-finger actions, but real phone cutouts, gesture bars and touch latency remain to be checked.

## Asset provenance and remaining release work

The human mesh, textures and base animation clips are CC0 Quaternius assets; see `assets/fighters/CREDITS.md`. Character wardrobe, arenas, icons, effects and synthesized musical compositions/SFX are original project work. The six identities share the same base anatomy with different proportions/colorways and combat kits; they are not six separately sculpted humans. Bosses share the same telegraphed area attack behavior.

Native ad SDKs, store products/receipts, restore/refund reconciliation, consent flows, signing and Android/iOS hardware validation remain release work, documented in `mobile-release.md`. Development store transactions remain explicitly simulated.
