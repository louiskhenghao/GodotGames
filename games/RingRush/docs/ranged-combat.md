# Ranged combat and spectacle — 0.6 baseline

Superseded model, ultimate and balance details: see `longevity.md` for 0.7.0. The validation below records the earlier 0.6 build.

## Play

Quick Fight introduces a drone in wave 1, an acid beetle from wave 2, a mechanical hound from wave 3 and an energy wisp from wave 4. Roughly one third of ordinary finite-wave spawns use the new silhouettes; classic mode begins mixing them from wave 2. Rift skeletons remain confined to their separately unlocked encounter.

| Enemy | Readable attack | Response |
| --- | --- | --- |
| Drone | Windup, then three diverging red projectiles | Sidestep between shots, close in during recovery |
| Acid beetle | Slow green acid projectile, small splash | Keep moving; use obstacles for cover |
| Mechanical hound | Ground line, then a committed charge | Dodge sideways, punish the recovery |
| Energy wisp | Purple projectile that steers for its first 0.8 seconds | Change direction after its tracking period |

Existing Spark/Hexer enemies now fire visible travelling projectiles. Ordinary ranged enemies need line of sight and must approach within 6 m to begin their 1.1-second windup. Their fire rate and the global 28-hostile-shot cap constrain pressure.

All fighters can equip free **Air Jab** (three aimed energy punches, 5.5-second base cooldown) or unlock **Nova Orb** for 450 coins (brief guidance and a 2.3 m base blast, 9-second cooldown). Both support levels 1–10, increasing damage and hit size; Nova's blast radius also increases, and levels 5/10 alter color. Their active hits participate in the existing Boss break/counter rules.

AEGIS has twin minigun bursts, ION has paired homing missiles, and ONYX has a forward burning cone. They automatically select a visible target within weapon range; close targets still trigger punches. Each robot keeps its Q/E skills. New weapon attachments and four short original sound effects distinguish the weapons.

## Implementation

- `game/ranged_combat.gd`: 96 reusable shot records, swept circle/segment collisions, nearest collision ordering, obstacle and boundary clipping, short homing, blast/cone damage. Homing references are weak and carry the actor's spawn generation, preventing recycled actors becoming accidental targets.
- `game/creature_model.gd`: four original, cached procedural silhouettes; three batched meshes per creature. Actor pools preallocate the model nodes. Hover/orbit/recoil/limb motion and tumble/fade replace human animation for these enemies.
- `packages/mobile-core/addon/vfx`: host-independent renderer. Four fixed MultiMesh groups provide irregular debris, noise-shaped clouds/flames, additive flares and ground shockwaves; essential projectile cores have a separate batch. No extra textures, dynamic point lights, or physics bodies per particle.
- Quake layers temporary branching dark cracks with hot cores, angular airborne stones, ground rings, spreading dust and gold light streaks. Cyclone adds spiral energy; lightning has colored edges and a white core. Flames use alpha blending so their orange color remains readable on bright floors.
- Low Quality reduces decoration counts. Effects-off retains collision-relevant shots and warnings. Cosmetic saturation cannot overwrite active gameplay projectiles.
- Physics updates stop when paused. Loading a run clears transient shots and restarts enemy warnings with grace; old saves, progress and currencies retain the existing schema.

## Validation, 2026-09-06

- 975 checks across the game suites passed, including 76 ranged checks and 71 Boss checks.
- 21 standalone shared-core checks passed without any RingRush assets or scripts.
- Native UI quality suite: 45 checks (three renderer-dependent checks beyond its 42 headless checks). Total unique Godot checks: **999**.
- Four workspace Python tests passed; package sync and `git diff --check` passed.
- Actual Compatibility-rendered captures: `tests/ranged_capture.gd` creates ignored `docs/ranged-preview/` images of quake, all creature silhouettes, each weapon, four skills and a 320×568 hostile shot. The capture advances effects explicitly at fixed time steps for comparable frames.
- Native stress: Apple M5 Max, 540×960, 48 mixed enemies, phase-II Boss, ONYX, ascended Solar Wave plus periodic Quake/Nova. Median **11.80 ms**, p95 **13.45 ms**, 389 draw calls, 268,598 primitives. See `ranged-performance.json`. Three nominal seconds of simulation include hit-stop (2.08 advancing gameplay seconds). This is a short desktop measurement, not a mobile sustained-performance guarantee.

Terrain is not physically destroyed: cracks expire and rocks are visual particles. Mobile GPU/thermal measurements, Android/iOS SDK integration and signed release testing remain separate platform work.

## Export validation

The final 0.6.0 / build 6 Web and Mac packages were exported successfully and both ZIP integrity checks passed. The exported Mac application was launched from an isolated directory with its packed resources: phase II, skill break, JSON snapshot, all four creature meshes, all three robot weapons, Nova Orb damage, shaders and normal shutdown passed. Browser playtesting confirmed Air Jab's demo, return to Skills, the final clipped eight-skill layout and no reported console errors. Test profiles used a separate browser origin and disposable native save files.

- Mac ZIP: 140.7 MiB; SHA-256 `176ba7592f6f15fc0b60884cfcbe8b4fe658395937adeca4ddf9d557c32d76ec`.
- Web ZIP: 89.5 MiB; SHA-256 `5ebae25ee89d68d35c2d9f4b0af24d905f8fd38be4659b2f9a1ee610cf21809e`.
