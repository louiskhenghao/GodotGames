# Ring Rush UX and monetization validation

Godot 4.5.1, macOS, Apple M5 Max, OpenGL Compatibility. Verified 5 September 2026. This is desktop validation; signed Android/iOS exports, native ads/billing and physical-device performance remain untested.

## Automated behavior: 254 checks, zero failures

- `tests/run_tests.gd`: 65 checks. Persistence/backup, future schemas, commerce callbacks, input, state transitions, effects, timed rounds, rewards and shared crowd geometry.
- `tests/expansion_tests.gd`: 60 checks. All six character kits and techniques, coin unlock ownership and duplicate protection, 10/30/50-wave completion, the 25-wave five-venue ladder, run records and serialized wave-17 resume with enemies and status effects.
- `tests/ux_ads_tests.gd`: 129 checks. Carousel preview without equipping; both anatomy meshes and valid outfit surfaces; equipment differences; six distinct skill icons/colors; right-hand round controls and simultaneous left-stick input; convex boundaries, swept dash collision, enemy navigation around every blocker and valid spawns; knockout snapshots; minimum-close time, early close without reward, no-fill, earned revive, second-death settlement; victory bonus once; interstitial cadence and queued replay, timeout removal, no stacked rewarded/interstitial ads; Remove Ads persistence and voluntary rewarded ads after purchase; duplicate/late callbacks; durable receipt recovery and failed benefit-save retry.
- All three final runs completed without engine errors. `git diff --check` passed.

Full-wave transition tests boost HP/damage to cover all transitions. They establish correctness, not final difficulty.

## Normal-stat balance bot

The final `tests/balance_sim.gd -- onslaught50` run used fresh-account Atlas stats and no test health/damage boosts. It cleared 50 waves in 588.43 simulated seconds, with 808 KOs and level 23. The bot automatically responds to telegraphs and picks useful upgrades; it finished with full health through recovery/sustain. Human difficulty tuning remains necessary. This does not establish player enjoyment or retention.

## Final crowd stress measurements

48 animated enemies retained with elevated benchmark health, elemental/orbit effects, physics and HUD updates, VSync off and 2× MSAA. 60 warmup frames and 180 samples. The table records the renderer's actual target size.

| Scenario | Actual render target | Median frame interval | P95 | Draw calls | Scene nodes | Primitives including passes |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Titan / hexagonal temple | (540.0, 960.0) | 2.011 ms | 2.753 ms | 323 | 401 | 548,738 |
| Zephyr / rectangular street | (820.0, 1093.0) | 1.917 ms | 2.447 ms | 312 | 395 | 544,730 |

These are short desktop measurements, not phone frame-rate claims. Crowd animation shares a compressed 6.6 MB library of reduced two-surface poses at 24 Hz. Hero equipment is built during character selection. Trees and venue props are batched; perimeter spectators are instanced. Physical phone GPU, battery, thermals, memory and SDK overlay behavior still need testing.

## Visual review

`tests/ux_capture.gd` captured the real Godot renderer with a disposable preview profile. Two bounded review rounds covered home, all six fighters, skills, live quake preview, modes, shop, revive, ad and victory screens, all five venues, compact-phone and tablet layouts. The batched fix corrected polygon floor winding, toast/button overlap, showroom framing and accessory placement. The final review confirmed visible floors and unobstructed primary actions. Images are under `docs/ux-preview/`; they are staged engine frames, not concept art.

Native safe-area inset handling is implemented for HUD and the development banner. Real phone cutouts, gesture bars, touch latency and ads interrupted by OS events remain unverified.

## Scope and provenance

The male/female models, textures and animation sources are CC0 Quaternius assets; see `assets/fighters/CREDITS.md`. The six identities use two anatomical source models plus distinct bone-bound equipment and clothing. They are not six separately sculpted humans. Bosses still share the telegraphed area attack, with different scaled stats.

Ad screens and purchases are explicit development simulations. Test rewarded ads run 15 seconds, allow closing after 5, and grant nothing on early close. The native adapter must use the SDK earned callback, and let the SDK own real video duration and close controls. Native billing, receipt verification, restore/refund reconciliation and signing remain release work in `mobile-release.md`. No test profile changes the player's real coins or unlocks.
