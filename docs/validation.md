# Ring Rush quality validation

Godot 4.5.1, macOS, Apple M5 Max, OpenGL Compatibility. Verified 5 September 2026. Desktop validation only; Android/iOS hardware, signed mobile builds and native ads/billing remain pending.

## Behavior and animation

**296 headless checks, zero failures:**

- `tests/run_tests.gd`: 65 checks for saves, economy, combat, input, pause/resume and pool reuse. The pool test now waits for the visible fall to finish before expecting that actor to be reused.
- `tests/expansion_tests.gd`: 60 checks covering all character/move kits, unlocks, 10/30/50-wave and five-venue ladder completion, records and combat snapshot restoration.
- `tests/ux_ads_tests.gd`: 129 checks for touch ownership, collision/obstacle navigation, advertisements, revive and victory rewards, duplicate callbacks, timeout and durable reward recovery.
- `tests/quality_tests.gd`: 42 checks covering drag rotation without character switching, arrow selection, opaque menus, locked venue previews, closer camera and dead-zone following, hit flash/recoil, fall poses and Compatibility material fading, fixed corpse budget and reuse, retained combat HUD/camera beneath the upgrade popup, paused clock/input, rerolls and duplicate choice protection.

The quality suite also ran with the native renderer: **45 checks, zero failures**. This includes the same 42 behavior checks plus entrance scale, settled scale and guarded exit behavior under a duplicate tap. All final logs were free of engine errors. `git diff --check` passed.

Transition tests boost HP/damage to exercise all wave boundaries. A separate normal-stat Atlas bot cleared 50 waves in **562.57 simulated seconds**, with 808 KOs and level 23. It finished with full health after sustain/recovery choices. The bot's fast reactions and automatic choices are not a substitute for human balance and enjoyment tests.

## Rendering measurement

Final stress run: **540 × 960**, Zephyr, Neon Siege, 48 active enemies, status/orbit effects, physics/HUD updates and the closer follow camera. VSync off, 2× MSAA, 60 warmup frames and 180 samples.

| Metric | Result |
| --- | ---: |
| Median frame interval | 2.003 ms |
| P95 frame interval | 3.228 ms |
| Draw calls | 334 |
| Scene nodes | 405 |
| Rendered primitives, including passes | 608,182 |

This short desktop benchmark does not establish a phone frame rate or thermal budget. Characters outside the view still simulate; rendering naturally culls offscreen geometry.

Crowd poses occupy approximately **8.1 MB compressed**, including 18 new fall poses. At most ten dying actors remain visible, drawn from the same pool of 48; extreme pool pressure can reclaim the oldest body. Deaths leave the active targeting/wave list immediately and cannot grant a second KO. The fall plays for 0.72 seconds, holds to 1.10 and fades by 1.45 seconds. Per-surface alpha supports the actual Compatibility renderer, unlike GeometryInstance3D.transparency.

## Visual review

`tests/quality_capture.gd` produces staged real-engine frames using a disposable profile. Two bounded review rounds covered the gym showroom, rotated fighter, actual venue previews above the controls, shop/skill backgrounds, central and edge-following combat views, hit/fall/fade, and the upgrade popup. Phone, 320×568 small-window and tablet layouts were included. The fix batch reduced wall lettering, improved header/action contrast and verified material fading. Final images are in `docs/quality-preview/`.

The upgrade popup retains the arena, camera and HUD; only its panel animates. It stops combat simulation and background input, enters over 0.22 seconds and dismisses over 0.12 seconds. The Reduced Motion setting skips its spatial entrance. Menu-root opacity remains stable, with actors explicitly hidden on non-showroom pages.

## Practical limits

The six fighter identities still use two CC0 source anatomical models with original equipment and clothing. See `assets/fighters/CREDITS.md`. Current bosses share an area-slam behavior; distinct boss patterns and human playtesting are the next gameplay priorities in `game-plan.md`.

Safe-area and touch code are implemented but real cutouts, OS gesture bars, touch latency, background interruptions, sustained phone performance and native monetization remain unverified. Advertising and purchases remain explicit development simulations; see `mobile-release.md`.

## 2026-09-06 refinement validation

- Core suite: **65 checks passed**.
- Expansion suite: **60 checks passed**, including finite 10 / 30 / 50-wave and ladder completion, resume and settlement.
- UX / ads suite: **129 checks passed**.
- Native quality suite: **45 checks passed**, including hit / fall / fade, popup entrance / exit, and duplicate-choice protection.
- New refinement suite: **115 checks passed**. Tests cover five permanent stats, cap / persistence / failed-save behavior, consumable receipt deduplication / repeat purchases / restore exclusion, all six essential skills with decorative effects disabled and no enemies, charger swept collision, dodgeable locked lightning, guard mitigation, new-role snapshots, and all 18 upgrade descriptions across 320×568, 540×960 and 768×1024 windows.

**414 checks, no failures** across the final suites. Fixtures use isolated disposable save files. The real debug profile's existing `effects: false` setting was not overwritten: essential feedback now remains visible while decorative particles remain off.

A single batched screenshot review covered phone / small window / tablet home, fight, shop, gym, wave-clear and upgrade states plus six low-effects techniques. The confirmation batch verified the corrected female texture path. Captures are under `docs/refinement-preview/`; `overview.jpg` summarizes the final inspection. The original capture script exited before a final transient tween completed and logged a cleanup warning; its cleanup now waits for outstanding short animations. The native quality suite and stress benchmark exit without those warnings.

Stress measurement on this Mac's Apple M5 Max, Godot 4.5.1 Compatibility, 540×960, Zephyr, enlarged street venue, **48 active enemies across six roles**: median **8.300 ms**, p95 **13.989 ms**, 364 draws, 726,214 rendered primitives and 453 nodes. See `refinement-performance.json`. This is a desktop measurement with a different enemy mixture from the previous baseline; it is not a phone performance claim. Android/iOS device thermals, sustained frame pacing, real SDKs and signed mobile exports remain unvalidated.

Both supplied FBX files were imported, reduced and rendered with their original animation. The attempted seven-clip retarget has visible bind-pose errors and is excluded from the playable roster and both mobile exports. Original / optimized measurements and visual comparisons are in `docs/model-review/`.
