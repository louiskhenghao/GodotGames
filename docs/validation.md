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


## 2026-09-06 friend playtest 0.2.0

**517 checks passed, no failures:** core 65; expansion 81; UX/ads 132; native quality 45; refinement 115; playtest 79. The expansion suite completes all seven finite modes including Hell, Blitz and Boss Rush, checks settlement/records and restores snapshots. Three creature kits participate in ownership and actual starting-stat checks.

The new suite validates centered icon bounds, foreground camera clipping, two-column Shop/GYM, live coin-upgrade actions, fixed GYM fight access, separated fight footer, eight mode icons, native creature animations, the starting Quick Combo passive, the Hell music selection and save/restore with all three creature enemy roles. Checks cover 320×568, 540×960 and 768×1024. Fast menu teardown initially exposed deferred icon calls to freed buttons; guarded untyped callback inputs fix that error, and the UX/ads suite was rerun cleanly.

One initial batched visual inspection and one confirmation batch covered home, fighters, shop, gym, fight picker, upgrade modal and creature combat. Confirmation tightened card heights and moved GYM's fight action to a fixed footer. The orthographic showroom camera was moved back along its viewing axis to remove near-plane clipping at the foreground; floor grid lines were removed. Current captures are under `playtest-preview/`.

Actual exported WebGL playtest, tested in the Codex in-app browser: fresh 1,200 coins, home/showroom rendering, human/creature carousel, coin unlock/equip of Hex, automatic combat through wave two with five KOs, upgrade selection and keyboard/drag inputs. Reload retained Hex, 580 coins after its purchase, and the unfinished fight; Resume restored to the paused screen. No browser console errors were captured. Web-only missing arrow glyphs were replaced with portable text. The Web build uses no threads and includes both desktop/mobile texture formats. It is served over HTTP, not file URLs.

Universal Mac ZIP was extracted and the exported executable launched from `/private/tmp`, outside the project. Startup succeeded with no engine errors. `codesign --verify --deep --strict` passed; `lipo -info` confirms x86_64 and arm64. This is ad-hoc signing, not Apple notarization. Both playtest builds have an isolated save profile and explicit mock commerce. The reusable export script builds both with official Godot 4.5.1 templates.

Stress sample on Apple M5 Max, 540×960, Hex, enlarged street venue, 48 enemies across nine roles, active status/orbit effects: median **2.101 ms**, p95 **3.837 ms**, **301 draws**, **662,548 rendered primitives** and **454 nodes**. VSync off, 60 warmup and 180 measured frames; see `playtest-performance.json`. This short local sample is not a phone or browser performance claim, nor a like-for-like comparison with earlier rosters. Native mobile thermals and sustained frame pacing still require physical devices.

The KayKit assets are CC0; raw source GLBs and both supplied FBX experiments are excluded from playtest exports. Prepared scenes depend only on local PNG textures. Crowd skeleton animation is baked offline into shared two-surface poses; the hero retains its live native skeleton. Original music uses 16-bar loops with circular DSP tails. No third-party commercial game assets are used.

## 2026-09-06 friend playtest 0.3.0

**600 checks passed, no failures:** core 65; expansion 72; UX/ads 129; native quality 45; refinement 115; playtest 69; reusable services 25; flow 80. The current roster is six humans. Three skeleton roles and their boss are restricted to the separately unlocked Rift; old creature purchases are refunded once, with their moves retained. All eight finite modes, including the 12-wave Rift, are covered by completion checks; the timed mode has its own rules.

The new checks cover the single-row colored navigation, symmetric PLAY label insets, aligned shop actions, six fighter backgrounds, PLAY → venue/mode selection → FIGHT, six front-facing ring skill previews, preview venue restoration, nine mode music resources and the secret gate. Service checks cover transaction failure and replay, migration idempotency and pending runs, notification permission boundaries, cue selection and retained mute state. Tests use disposable profiles.

One batched visual review and one confirmation batch covered 320×568, 540×960 and 768×1024 layouts. The fix batch tightened GYM cards, made the mode description visible, framed skill previews and reduced background lettering. Final captures are in `flow-preview/`. No further visual iteration was undertaken after the confirmation batch.

Actual exported WebGL verification used a separate `localhost` origin so the active `127.0.0.1` player profile was untouched. A fresh 1,200-coin profile opened the combined picker, spent 600 coins on the Rift, entered the dedicated arena as Atlas, fought skeleton enemies, earned five KOs, selected a level-up and resumed fighting. No browser warnings or errors were captured. The existing playtest profile migrated Hex to Atlas, refunded 620 coins and retained Thunder. This is a local HTTP build, not public hosting.

The new universal Mac ZIP was extracted and its executable started from `/private/tmp`, outside this repository. `codesign --verify --deep --strict` passed and `lipo -info` confirmed arm64 and x86_64. Headless execution with the Dummy audio driver reports Ogg playback resources during exit; the same exported application with `--headless --audio-driver CoreAudio --quit-after 180` starts and exits cleanly. Signing is ad-hoc; Apple notarization and signed mobile exports remain outstanding.

The independently generated core starter was imported and launched from `/private/tmp/rush-core-proof-v3-final`, without Ring Rush code or assets, and printed `CORE STARTER READY` without errors. `tools/create_game.py` packages only `addons/mobile_core` and the starter host. Real advertising, store receipt verification and OS notification delivery require platform providers; the shipped playtest uses explicit mock commerce, and unsupported notification operations return errors rather than reporting success.

Nine original synthesized mode scores use different melodies, instrumentation, drum patterns and arrangements; the Rift also uses 3/4 meter. All nine decode successfully with peaks below full scale and unique content hashes. See `mode-music.json` and `mode-audio-validation.json`. This verifies audio content and routing, not player preference or musical quality.

Native stress sample on Apple M5 Max, Godot 4.5.1 Compatibility, 540×960, Atlas, Rift, 48 creature enemies and active status/orbit effects: median **2.959 ms**, p95 **3.598 ms**, **401 draws**, **684,388 rendered primitives**, **463 nodes**. VSync off, 60 warmup and 180 sampled frames; see `flow-performance.json`. This does not establish phone or browser performance. Device thermals, mobile audio interruptions, real touch hardware and production SDKs still need physical-device validation.


## 2026-09-06 growth playtest 0.4.0

**811 checks passed, no failures:** core 65; expansion 84; UX/ads 132; native quality 45; refinement 124; playtest 72; services 25; flow 83; growth 178; shutdown 3. Tests use separate disposable profiles. Growth checks exercise 240 training purchases, per-skill caps, exact wallet costs, failed saves, 36 reachable badge objectives, small aggregate bonuses, duplicate settlement, legacy snapshots, frozen new-run modifiers, preview exclusion, actual robot fist articulation, actual damage/range at skill levels 1 and 10, and banked contract rewards.

All three new robot chassis have different meshes. The adaptation replaces original animal pilot geometry with mechanical helmets and adds two articulated boxing arms, while retaining native locomotion and hit animations. One batched visual inspection across 320×568, 540×960 and 768×1024 led to one fix batch (robot heads/arm placement and skill evolution markers), followed by one confirmation batch. Captures are under `growth-preview/`. A final lookup correction maps GYM and venue badges to existing dumbbell/stairs icons; the growth suite checks every badge icon against implemented symbols. No further visual refinement loop followed.

Final native stress run: Onyx, level-10 Solar Wave, street venue, 48 enemies, active status/orbit effects and robot skeleton/fist animation; Godot 4.5.1 Compatibility on Apple M5 Max at 540×960. Median **2.109 ms**, p95 **2.807 ms**, **381 draws**, **656,830 rendered primitives**, **480 nodes**. VSync off, 60 warmup and 180 measured frames. This short desktop measurement does not establish browser/mobile speed or sustained phone thermals.

Universal Mac 0.4.0 was extracted and launched from `/private/tmp` with CoreAudio. Forced `--quit-after` teardown can report two retained Ogg resources; normal close now saves the run, stops audio and lets the driver release its references before quitting. Deep/strict code-sign verification passed; the executable includes arm64 and x86_64. Signing is ad-hoc, not notarized. Android/iOS signed installs, physical-device checks and real monetization/notification providers remain pending.

The final Mac archive was also launched through an external SceneTree harness that loads the archive's own main scene and triggers the normal close path. It printed `EXPORTED 0.4.0 READY / NORMAL CLOSE` and exited without warnings or errors. The harness is outside the repository and does not depend on source assets.

Final exported WebGL smoke test used an independent HTTP origin on port 8771. A simulated 4,000-coin pack changed 1,200 → 5,200; AEGIS unlocked/equipped for 1,800; Quake upgraded to level 2 for 182; Power upgraded for 80. The page showed two automatically earned badges and +0.4 permanent power. TRY EFFECT entered the arena and the header Back returned to Skills. Reload retained the training/badges. No browser warning/error logs were captured. The user-facing test page remains open; it uses a separate save origin from earlier port-8769 playtests.
