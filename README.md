# Ring Rush

Portrait 3D boxing survival in **Godot 4.5.1**, with Web and universal macOS playtests plus an Android/iOS export pipeline and reusable `addons/mobile_core/` services. This build includes a 3D fighter carousel with drag-to-rotate inspection, nine fighting identities using two human bases, distinct equipment and three CC0 creature models, icon-led move selection with playable effect previews, five shaped venues with obstacles, and eight challenge modes including 10/30/50-wave survival, Hell and Boss Rush.

**Status:** standalone Web and universal Mac playtests exported and smoke-tested. Native ads/IAP adapters, receipt validation, signed mobile binaries and physical Android/iOS testing remain pending. The development cosmetic store explicitly simulates transactions; fighter and technique purchases use earned game coins.

## Play

Open `project.godot` in Godot 4.5.1 and press **F5**, or double-click `run.command` on this Mac. Set `GODOT_BIN` if Godot is installed elsewhere.

| Action | Touch | Keyboard |
| --- | --- | --- |
| Move | Drag in the lower left half | WASD / arrows |
| Punch | Automatic toward nearby enemies | Automatic |
| Dodge | Small right-side round arrow | Space |
| Equipped technique | Colored round skill icon on the right | Q |
| Amplified technique | Upper-right crown at 100% | E |
| Pause | Pause | Esc |

Dodge red attack warnings. Collect teal XP, choose one of three upgrades and combine up to 18 passive skills. Two rerolls are available per run. Techniques recharge independently of the ultimate meter; knockouts and wave clears charge the ultimate. Five-wave boss checkpoints punctuate longer runs. Clear a wave to collect remaining XP, recover some health and receive a short break.

## Combat flow and presentation

- Fight selection shows the real 3D venue above the venue arrows and challenge buttons. Locked venues can be previewed without equipping them. Saved runs offer Resume or Bank instead of starting over.
- Upgrades open in a centered popup over the unchanged arena and HUD. Combat and held input pause. The panel enters in 0.22 seconds and exits in 0.12 seconds; rapid repeated clicks cannot award twice. Reduced Motion skips the spatial entrance.
- Combat uses a closer camera with a small dead zone and smooth following. Walking toward an arena edge reveals more of the surroundings. Viewport changes and saved-run restoration reframe the player.
- Hits use recoil, short warm flashes and feedback audio. Defeated opponents fall, hold briefly and fade through materials supported by Compatibility rendering. At most ten fallen actors remain visible, using the existing 48-actor pool; extreme pool pressure can reclaim the oldest body.
- The showroom has a boxing-gym backdrop. Other menus have an opaque stadium background; option changes no longer fade the entire page and reveal the hidden character. Top/bottom contrast veils protect controls over bright scenery.

## Menus and ads

Home focuses on the selected fighter and one Play/Resume action. Drag the fighter to turn it; use the arrows or keyboard left/right to switch identities to see each model, attributes, signature and coin cost together; browsing never equips or spends coins. Six skills have different icons and colors, a short tactical hint and a **Try Effect** button. The shop has six graphical cards in two columns. The GYM has five permanent stat upgrades with a visible purchase action and a fixed Quick Fight / Resume button.

Development monetization is fully interactive but simulated:

- Home banner only; combat stays clear.
- One optional rewarded revive per fight: 60% HP and 3 seconds of protection.
- Optional victory video: +50% of the already-saved result coins, once.
- Automatic interstitial after every third settled run, skipped after an earned video on that run.
- Permanent **Remove Ads** suppresses banners and automatic interstitials; voluntary rewards remain available.
- Test rewarded ads last 15 seconds. Close unlocks after 5 seconds; early close grants nothing. Test interstitials close after 5 seconds. Production duration and close controls must be owned by the native SDK.
- Earned reward receipts and their game benefits persist with duplicate protection; no-fill, timeout and failed saves have retry paths.

## Challenges and venues

- **Quick Fight:** 10 clear-based waves, designed for a short session.
- **Blitz:** eight waves, 0.22-second spawn intervals and one-second breaks.
- **Hell:** twenty dense waves, 0.18-second spawns, 0.75-second breaks, creatures from wave one and no ordinary-wave healing.
- **Boss Rush:** five bosses with alternating rush, slam and ranged-circle patterns.
- **Survival 30 / Onslaught 50:** complete 30 or 50 waves with an increasingly strong build.
- **World Ladder:** 25 waves across all five venues, changing venue after each five-wave boss.
- **90-second Rush:** the original timed format, champion at 75 seconds and a bounded 30-second overtime.

Venues: **The Underground** boxing ring, **Neon Siege** street ambush, **Skyline Rooftop** helipad, **Iron Foundry** with timed steam vents, and **Dawn Temple** courtyard. The street is a long rectangle, rooftop an octagon, foundry a wide rectangle and temple a six-sided courtyard. Solid props block movement and dashes; enemies steer around them. Trees and instanced spectators populate the perimeter. Winning a venue unlocks the next for standalone fights. Ladder visits them automatically. Boss Rush changes attack patterns between rush, slam and locked ranged circles; other modes retain the area-slam champion.

## Fighters and moves

| Fighter | Starting HP / damage | Signature | Starting passive | Coins |
| --- | --- | --- | --- | ---: |
| Atlas | 110 / 20 | Hundred Hands — tracking six-hit combination | Iron guard | Free |
| Zephyr | 85 / 15 | Cyclone Fist — mobile multi-hit spin | Light feet | 180 |
| Titan | 155 / 29 | Fault Line — ground cracks, shockwave and stagger | Iron guard ×2 | 300 |
| Volt | 95 / 17 | Thunder Step — up to eight chained targets | Live wire | 420 |
| Raven | 90 / 23 | Rising Dragon — uppercut and launch | Fighting spirit | 550 |
| Sol | 105 / 19 | Solar Wave — piercing fire projectile | Hot knuckles | 700 |
| Rattle | 100 / 22 | Hundred Hands | Quick combo | 320 |
| Shade | 90 / 24 | Rising Dragon | Sweet spot | 480 |
| Hex | 120 / 17 | Thunder Step | Live wire | 620 |

Movement speed and punch timing also differ. Unlocking a fighter includes its technique. Techniques can be purchased separately and equipped on any owned fighter. Atlas and Fault Line are available from the start. The gym offers power, health, initial energy, speed and technique cooldown upgrades, with five levels each. Coins, ownership and selection commit atomically; failed writes do not debit the balance.

## Save and resume

Active fights checkpoint every 15 seconds, on wave clears and when the app loses focus. The snapshot includes the run ID, wave director, stats, build, enemies, statuses, pickups and pending upgrade choice. **Resume Saved Fight** restores it to a paused screen. The challenge menu can instead bank the saved run and start fresh. Rewards settle once per run ID. A force-kill can lose the time since the last successful checkpoint. Older checkpoints without a complete snapshot bank their saved coins on launch.

## Performance and reusable core

- Pool of 48 opponents / 64 pickups; combat does not create/free actors.
- Hero uses male/female imported humanoid skeletons with bone-bound equipment. Crowds share reduced meshes with 24 Hz baked real animation poses, in two surfaces per frame. Six shared crowd pose libraries cover human and creature silhouettes; each opponent still draws two surfaces and uses no live skeleton.
- Environments are batched; spectators, particles and ground cracks use instancing.
- Fixed limits: 192 particles, 12 shockwave rings, 48 crack segments, 16 damage numbers and six SFX voices. Music has its own player and mute setting.
- Spatial crowd separation, fixed physics simulation, safe-area UI and independent second-finger action controls.
- Battery saver removes real-time shadows, the stadium audience and MSAA; perimeter crowds remain batched.

`addons/mobile_core/` contains reusable persistence, provider-based monetization, VFX, audio and touch input without importing game rules. See [architecture](docs/architecture.md), [validation](docs/validation.md) and [mobile release work](docs/mobile-release.md).

## Verify and rebuild assets

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/expansion_tests.gd
godot --headless --path . --script res://tests/ux_ads_tests.gd
godot --headless --path . --script res://tests/quality_tests.gd
godot --path . --script res://tests/quality_tests.gd
godot --headless --path . --script res://tests/balance_sim.gd
godot --path . --script res://tests/quality_capture.gd
godot --path . --disable-vsync --script res://tests/performance.gd -- /tmp/rush-stress.json stress
```

All test/capture profiles are disposable. Full-wave transition tests boost HP/damage; the separate balance bot uses starting stats. Actual human enjoyment, long-term economy, thermal behavior and mobile touch latency need human/device playtesting.

- `python3 tools/prepare_fighter.py` and `python3 tools/prepare_female.py`: assemble the two humanoids and selected CC0 animation tracks.
- `godot --path . --script res://tools/bake_crowd.gd`: rebuild optimized crowd poses; requires the native renderer, not `--headless`.
- `python3 tools/generate_audio.py`: original level-up sound.
- `python3 tools/generate_feedback.py`: original hurt/exhale and landing Foley.
- `python3 tools/generate_score.py`: original music and layered combat SFX (Python + ffmpeg).

Model/animation attribution and license: [asset credits](assets/fighters/CREDITS.md). Barlow Condensed uses its bundled OFL license. Reference gameplay: [Endless Puncher](https://play.google.com/store/apps/details?id=com.fubugames.endlesspuncher&hl=en); no reference-game assets or code are included.

Design decisions and next production priorities: [game plan](docs/game-plan.md). Current native-renderer screenshots: [quality previews](docs/quality-preview/).

The latest refinement adds content-sized upgrade cards, side navigation, five coin-funded permanent stats, three simulated coin packs, larger arenas and charger / spark / guard enemies with distinct tactics. Essential skill effects remain visible with extra particles disabled. See [refinement screenshots](docs/refinement-preview/overview.jpg) and the [two supplied FBX model assessment](docs/model-review/README.md). The supplied models are optimized previews; animation retargeting needs correction before they become playable fighters.


## Friend playtest 0.2.0

See [playtest instructions](docs/playtest.md). Exports are ignored build artifacts:

- `builds/mac/RingRush.zip`: universal app (Intel + Apple Silicon), with ad-hoc signing; not Apple-notarized.
- `builds/RingRush-Web-Playtest.zip`: static WebGL 2 / WebAssembly build. Serve over HTTP(S); opening `index.html` through `file://` does not work.

Both use the isolated `profile.playtest.json`, a one-time 1,200-coin welcome grant and clearly labelled free mock purchases. They make no real charges. Native release presets do not enable the playtest feature.

Install the matching Godot 4.5.1 export templates, then run:

```sh
python3 tools/export_playtest.py --godot /path/to/Godot
```

Alternatively pass `--templates /folder/with/templates` containing `web_nothreads_release.zip` and `macos.zip`. The script temporarily supplies those paths and restores the preset file afterwards. The Web shell keeps a portrait canvas centered on wide screens; desktop/mobile texture compression variants are enabled. `builds/.gdignore` prevents exported assets from being imported back into the project.

Run `godot --headless --path . --script res://tests/playtest_tests.gd` for the new mode, model, save and UI checks. [Current screenshots](docs/playtest-preview/overview.jpg) and [validation](docs/validation.md) describe the tested boundaries.
