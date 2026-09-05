# Fighter model and animation credits

- **Universal Base Characters — Superhero Male and Superhero Female**, by **Quaternius**.
  Official pack and CC0 license declaration: https://quaternius.com/packs/universalbasecharacters.html
- **Universal Animation Library**, by **Quaternius**, CC0.
  Official pack: https://quaternius.com/packs/universalanimationlibrary.html
- Download source: the CC0 **Quaternius_IK_Rigged** package linked by the Godot Asset Library:
  https://godotengine.org/asset-library/asset/5235
  https://codeberg.org/jamesonBradfield/Quaternius_IK_Rigged_with_animations
- CC0 terms: https://creativecommons.org/publicdomain/zero/1.0/

Ring Rush uses the model's mesh, skin/eye/normal textures and selected compatible animations, not the Godot 4.6 IK addon code. `tools/prepare_fighter.py` and `tools/prepare_female.py` assemble `boxer.gltf`/`boxer.bin` and `boxer_female.gltf`/`boxer_female.bin` from the source model and selected animation tracks. Original download inputs are preserved in the ignored `source/` directory for reproducibility and excluded from Godot import/export.

The game adds fitted boxing shorts, shoes, hair coverage and gloves, plus bone-bound helmets, shoulder/chest protection, ponytail/hair, visor, mask and cloth accessories. Zephyr and Raven use the separate female anatomy; the other fighters use the male base. These are two source sculpts with six assembled identities, not six individually commissioned models. `tools/bake_crowd.gd` generates the reduced crowd geometry and shared 24 Hz poses, including an 18-pose sample of the original Death01 clip for the short knockdown presentation; run it with Godot's native renderer. The hero keeps the continuous imported skeleton. These are modified CC0 assets, not original sculpting by this project.

All new arena geometry, UI icons, skill effects and musical compositions/SFX in this project are original procedural work. No characters, music, models or code from Street Fighter, King of Fighters or Endless Puncher are included.

`crowd_raven.res` and `crowd_titan.res` are offline reductions and pose bakes of the same CC0 female/male bases, with original bone-bound equipment from `game/wardrobe.gd`. They add different enemy silhouettes without live per-enemy rigs.

Unused copies of the two supplied FBX files and failed retargeting experiments were removed in the monorepo migration. The original Downloads files are untouched. See `docs/model-review/README.md` for the archived assessment.


## KayKit creature fighters and enemies

**KayKit Character Pack: Skeletons 1.0**, by **Kay Lousberg**. Official source:
https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Skeletons-1.0

License: CC0; the original notice is preserved in `kaykit/LICENSE.txt`.
`Skeleton_Minion`, `Skeleton_Rogue` and `Skeleton_Mage` become Rattle, Shade and Hex. All three keep their own native skeleton and seven compatible animation clips; no humanoid retargeting is involved. The scenes have 41 bones and approximately 5,288 / 5,278 / 4,588 triangles. Their 1,024-pixel atlas and distinct heads, hoods, hats and body proportions remain visible in gameplay.

`tools/prepare_creatures.gd` reduces the source animation libraries; `tools/bake_creatures.gd` bakes shared crowd poses at 24 Hz. Enemy bone, revenant and hexer roles use these three silhouettes. The prepared scenes reference local PNG textures only; source GLBs are excluded from playtest exports. These are modified open assets, not newly sculpted project originals.

The four original music loops can be regenerated with `tools/generate_battle_music.py`: menu 104 BPM, street 138 BPM, general combat 144 BPM, Hell/Boss Rush 156 BPM. Sixteen-bar arrangements include syncopated bass, drums, chord stabs, riffs and fills. Godot engine and dependency license notices are in `assets/licenses/`.


### Role change in 0.3.0

Rattle, Shade and Hex are now **enemy-only** in the optional Rift mode, with a creature champion. The playable roster contains six humans. Prepared live skeleton scenes are retained only for asset preparation; runtime crowds load shared baked poses on demand when entering the secret encounter. Old creature purchases are refunded by game migration, not by the engine core.

The mode music supersedes the earlier shared tempo variants. `tools/generate_mode_music.py` creates nine original compositions with separate motifs, harmony, rhythmic patterns and instruments. `docs/mode-music.json` records their titles and parameters. No commercial recordings or sampled songs are used.

## 0.4.0 playable mechs

AEGIS, ION and ONYX use three different chassis from **Ultimate Space Kit**, by **Quaternius**, CC0 1.0. Author/license: https://quaternius.com/packs/ultimatespacekit.html . Download mirror: https://opengameart.org/node/155017 (`ultimate_space_kit-glb.zip`). Original files: `Mech-D5wW2jDO42.glb`, `Mech-o3Ps8z8ByP.glb`, `Mech-4UvIHxnoSR.glb`.

The game adaptation removes the original animal pilot head triangles, adds original mechanical helmets and articulated boxing arms, normalizes scale, and maps seven native animations to the combat interface. These are three different chassis meshes (4,008 / 5,846 / 6,756 source triangles), not recolors of the existing boxer. `tools/prepare_mechs.gd` reproduces the scene adaptation; runtime gloves and helmets are authored in `game/boxer.gd`. Unused source-pack assets were removed; the three selected source GLBs remain for reproducible preparation and are excluded from exports.
