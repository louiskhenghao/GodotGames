# 0.8.0 — worlds and loadout

The home screen groups Companions and Badges below Fighter, Skills, Gym and Shop, immediately above Play. Settings remains in the header. Companions shows two persistent equipped cards with the actual model thumbnail, activation condition, benefit, Change and Unequip. An empty slot offers Choose. The collection scrolls independently, and Change filters to the correct slot. Equipment still takes effect at the next fight; a saved run retains its frozen loadout.

## Venue identities

| ID | Venue | Ordinary opponents | Champion appearance |
| --- | --- | --- | --- |
| 0 | The Underground | Human boxers, runners, brutes, chargers, guards | Iron Jack / human |
| 1 | Neon Siege | Street crew, including ranged Spark fighters | The Collector / human |
| 2 | Skyline Rooftop | Security crew and surveillance drones | Night Hawk / human |
| 3 | Iron Foundry | Industrial guards and drones | The Foreman / human |
| 4 | Dawn Temple | Martial guardians | The Sentinel / human |
| 5 | The Rift, separately unlocked | Bone, Revenant, Hexer only | The Bone King / skeleton |
| 6 | Wildwood | Wolves, spiked slimes, flying stingers | The Alpha / large wolf |
| 7 | Hollow Graveyard | Homing wisps and tomb slimes | The Wailing King / large spirit |
| 8 | Orbital Station | Spread-fire drones and armored twin-shot sentries | Overseer Prime / large drone |

Forest uses an irregular clearing, layered conifers, stepping stones and mossy rocks. The graveyard is a long route with graves, broken walls, bare trees, lanterns and a mausoleum. The space station has a beveled cargo deck, guide lights, crates and a bulkhead facing a star field. Combat obstacles are built from the same coordinates and radii used by movement, spawn placement and projectile collision. Perimeter detail stays outside the movement boundary, with low foreground scenery to preserve visibility.

Scenery is original procedural geometry merged into a small number of meshes. Stingers reuse the already bundled CC0 Quaternius Armabee animation library; sentries reuse the CC0 Cyberpunk Enemy Flying library. No new asset pack is added. Their sources and licenses remain accessible in Settings → Credits. Companion pets remain allowed in every venue: these are player equipment, distinct from the hostile encounter roster.

## Progression and compatibility

Ordinary route: Underground → Neon → Rooftop → Foundry → Temple → Wildwood → Graveyard → Station. Winning unlocks the next venue. Previous Temple winners automatically receive Wildwood access. New World Ladder runs contain 40 waves, with five waves per ordinary venue. Existing 25-wave ladder saves retain their original target.

Stage IDs 0–5 are unchanged. Both finite waves and the 90-second mode use `RushEncounterRoster`; early waves introduce two roles and later waves use the full venue family. Old saves containing a wolf or ghost in the gym remain resumable. Incompatible enemy roles are replaced by appropriate roles while preserving enemy count, health/status and earned run progress. New bosses keep the existing two-phase and counter mechanics; their model is derived from the venue on spawn and restore.

Game-specific content stays under `games/RingRush/game`: `encounter_roster.gd` owns enemy families; `challenges.gd` owns the stable route; `arena_layout.gd` owns boundaries/blockers; `frontier_venues.gd` owns the three new environments. The reusable mobile core does not depend on these game-specific rules.

## Validation

Run `python3 tools/workspace.py --godot <godot> test RingRush` from the monorepo root. `worlds_tests.gd` covers actual spawn loops, stage visibility, collision, boss model recycling, migration, progression, ladder compatibility and responsive loadout layout. `tests/worlds_capture.gd` produces native screenshots under ignored `docs/worlds-preview/` at phone and tablet sizes.

The support website/email, simulated commerce, production gates and privacy status are unchanged. This release is a playtest, not a store-ready mobile submission.
