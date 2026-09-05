# Ring Rush

Portrait 3D boxing survival in **Godot 4.5.1**, with an Android/iOS export pipeline and reusable `addons/mobile_core/` services. This build replaces the primitive boxer with a textured, rigged Quaternius humanoid, adds five venues, six coin-unlockable fighting styles, six equipable signature techniques and finite wave challenges.

**Status:** playable and validated on macOS. Native ads/IAP adapters, receipt validation, signed mobile binaries and physical Android/iOS testing remain pending. The development cosmetic store explicitly simulates transactions; fighter and technique purchases use earned game coins.

## Play

Open `project.godot` in Godot 4.5.1 and press **F5**, or double-click `run.command` on this Mac. Set `GODOT_BIN` if Godot is installed elsewhere.

| Action | Touch | Keyboard |
| --- | --- | --- |
| Move | Drag away from action buttons | WASD / arrows |
| Punch | Automatic toward nearby enemies | Automatic |
| Dodge | Dodge | Space |
| Equipped technique | Technique, on cooldown | Q |
| Amplified technique | Unleash at 100% meter | E |
| Pause | Pause | Esc |

Dodge red attack warnings. Collect teal XP, choose one of three upgrades and combine up to 18 passive skills. Two rerolls are available per run. Techniques recharge independently of the ultimate meter; knockouts and wave clears charge the ultimate. Five-wave boss checkpoints punctuate longer runs. Clear a wave to collect remaining XP, recover some health and receive a short break.

## Challenges and venues

- **Quick Fight:** 10 clear-based waves, designed for a short session.
- **Survival 30 / Onslaught 50:** complete 30 or 50 waves with an increasingly strong build.
- **World Ladder:** 25 waves across all five venues, changing venue after each five-wave boss.
- **90-second Rush:** the original timed format, champion at 75 seconds and a bounded 30-second overtime.

Venues: **The Underground** boxing ring, **Neon Siege** street ambush, **Skyline Rooftop** helipad, **Iron Foundry** with timed steam vents, and **Dawn Temple** courtyard. Winning a venue unlocks the next for standalone fights. Ladder visits them automatically. Bosses currently share the telegraphed area-slam behavior with different scaled stats.

## Fighters and moves

| Fighter | Starting HP / damage | Signature | Starting passive | Coins |
| --- | --- | --- | --- | ---: |
| Atlas | 110 / 20 | Hundred Hands — tracking six-hit combination | Iron guard | Free |
| Zephyr | 85 / 15 | Cyclone Fist — mobile multi-hit spin | Light feet | 180 |
| Titan | 155 / 29 | Fault Line — ground cracks, shockwave and stagger | Iron guard ×2 | 300 |
| Volt | 95 / 17 | Thunder Step — up to eight chained targets | Live wire | 420 |
| Raven | 90 / 23 | Rising Dragon — uppercut and launch | Fighting spirit | 550 |
| Sol | 105 / 19 | Solar Wave — piercing fire projectile | Hot knuckles | 700 |

Movement speed and punch timing also differ. Unlocking a fighter includes its technique. Techniques can be purchased separately and equipped on any owned fighter. Atlas and Fault Line are available from the start. The gym retains permanent power/health/charge training. Coins, ownership and selection commit atomically; failed writes do not debit the balance.

## Save and resume

Active fights checkpoint every 15 seconds, on wave clears and when the app loses focus. The snapshot includes the run ID, wave director, stats, build, enemies, statuses, pickups and pending upgrade choice. **Resume Saved Fight** restores it to a paused screen. The challenge menu can instead bank the saved run and start fresh. Rewards settle once per run ID. A force-kill can lose the time since the last successful checkpoint. Older checkpoints without a complete snapshot bank their saved coins on launch.

## Performance and reusable core

- Pool of 48 opponents / 64 pickups; combat does not create/free actors.
- Hero uses the imported humanoid skeleton. Crowds share reduced meshes with 24 Hz baked real animation poses, in two surfaces per frame. The complete crowd animation asset is about 6.6 MB compressed.
- Environments are batched; spectators, particles and ground cracks use instancing.
- Fixed limits: 192 particles, 12 shockwave rings, 48 crack segments, 16 damage numbers and six SFX voices. Music has its own player and mute setting.
- Spatial crowd separation, fixed physics simulation, safe-area UI and independent second-finger action controls.
- Battery saver removes real-time shadows, audience and MSAA.

`addons/mobile_core/` contains reusable persistence, provider-based monetization, VFX, audio and touch input without importing game rules. See [architecture](docs/architecture.md), [validation](docs/validation.md) and [mobile release work](docs/mobile-release.md).

## Verify and rebuild assets

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/run_tests.gd
godot --headless --path . --script res://tests/expansion_tests.gd
godot --headless --path . --script res://tests/balance_sim.gd
godot --path . --script res://tests/capture.gd
godot --path . --disable-vsync --script res://tests/performance.gd -- /tmp/rush-stress.json stress
```

All test/capture profiles are disposable. Full-wave transition tests boost HP/damage; the separate balance bot uses starting stats. Actual human enjoyment, long-term economy, thermal behavior and mobile touch latency need human/device playtesting.

- `python3 tools/prepare_fighter.py`: assemble the humanoid and selected CC0 animation tracks.
- `godot --path . --script res://tools/bake_crowd.gd`: rebuild optimized crowd poses; requires the native renderer, not `--headless`.
- `python3 tools/generate_audio.py`: original level-up sound.
- `python3 tools/generate_score.py`: original music and layered combat SFX (Python + ffmpeg).

Model/animation attribution and license: [asset credits](assets/fighters/CREDITS.md). Barlow Condensed uses its bundled OFL license. Reference gameplay: [Endless Puncher](https://play.google.com/store/apps/details?id=com.fubugames.endlesspuncher&hl=en); no reference-game assets or code are included.
