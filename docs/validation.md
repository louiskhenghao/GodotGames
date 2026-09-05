# Validation — Ring Rush gameplay expansion

Godot **4.5.1**, macOS, Apple **M5 Max**, OpenGL Compatibility renderer. These are desktop observations, not certification of Android/iOS builds or a promise of physical-device frame rate.

## Functional regression

The final headless run completed **65 checks with zero failures** and clean shutdown. The suite covers commerce cancellation, duplicate transactions, verified late purchases, restoration, save failures, backup recovery, future-schema protection, touch movement, second-finger dash, legal ability selection, rank caps, reroll limits, burn/frost, lightning, orbiting gloves, armor, regeneration, life on knockout, dash invulnerability, special charge, actor-pool reuse, complete rounds, champion unlocks, overtime defeat, atomic settlement and checkpoint recovery.

A full round is accelerated with increased test health/damage to reach all state transitions. That test establishes that victory and progression work; it does not establish final difficulty balance. Content and economy still need human playtesting on physical devices.

## Rendering comparison

Identical 540×960 viewport, 48 visible animated fighters, VSync disabled. After 60 warmup frames, 180 frames were sampled. The render-only comparison disables the game simulation in both versions; the upgraded build includes 2× MSAA. Counters include the engine's rendering/shadow passes. Results are one local comparison and will vary across hardware and system load.

| Metric | Initial prototype | Expanded game |
| --- | ---: | ---: |
| Draw calls per frame | 1,229 | 641 |
| Scene nodes | 856 | 595 |
| Rendered primitives per frame | 62,438 | 292,890 |
| Median frame interval | 3.357 ms | 1.932 ms |
| 95th percentile frame interval | 4.871 ms | 2.972 ms |

The expanded scene uses approximately **48% fewer draw calls** and has a **42% lower median frame interval** on this machine. It renders more geometry for the improved models; the reduced submission overhead outweighs that cost here. This tradeoff must be measured on mobile GPUs. The high-detail hero and lower-detail crowd share baked mesh resources, while stadium repetition and particles use MultiMesh.

A separate stress run enables simulation, a full 48-enemy crowd, burning, slowing, chain lightning, orbiting gloves, nova and HUD updates. It observed **2.295 ms median**, **4.018 ms p95**, **679 draw calls**, and **595 nodes** over the same sample length. Enemy/player test health is raised to retain the full crowd. This short burst test does not measure sustained thermals, battery drain or a worst-case device.

Reproduce with `tests/performance.gd` using the commands in the README. The output JSON is written to the path supplied after `--`; append `stress` for the combined workload. Saves are isolated and removed at exit.

## Visual and interaction review

Actual Godot frames were inspected at portrait phone sizes and a tablet aspect ratio: 540×960, 540×800, 540×1170 and 768×1024. The review covered the fighter showroom, combat, skill selection, training, circuit selection, locker and scrolling playbook. The canvas expands across aspect ratios. A framing overlap and disabled-icon contrast issue were corrected. Native safe-area measurements are applied on mobile but remain unverified against physical cutouts/system bars.

Controls support mouse/keyboard and touch. An explicit regression holds the movement touch while a second finger activates dash; another verifies skill-button touches do not start the movement stick. Physical-device touch latency, suspension, ad/store overlays and accessibility remain release work.

## Still outside this validation

No signed AAB/IPA, native ad SDK, real store transaction, backend receipt validation, physical Android/iPhone benchmark, device thermal test, full home-construction system, broad equipment inventory, or long-term economy balancing is represented as complete. See `mobile-release.md` for native integration work.
