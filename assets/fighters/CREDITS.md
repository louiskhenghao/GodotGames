# Human model and animation credits

- **Universal Base Characters — Superhero Male and Superhero Female**, by **Quaternius**.
  Official pack and CC0 license declaration: https://quaternius.com/packs/universalbasecharacters.html
- **Universal Animation Library**, by **Quaternius**, CC0.
  Official pack: https://quaternius.com/packs/universalanimationlibrary.html
- Download source: the CC0 **Quaternius_IK_Rigged** package linked by the Godot Asset Library:
  https://godotengine.org/asset-library/asset/5235
  https://codeberg.org/jamesonBradfield/Quaternius_IK_Rigged_with_animations
- CC0 terms: https://creativecommons.org/publicdomain/zero/1.0/

Ring Rush uses the model's mesh, skin/eye/normal textures and selected compatible animations, not the Godot 4.6 IK addon code. `tools/prepare_fighter.py` and `tools/prepare_female.py` assemble `boxer.gltf`/`boxer.bin` and `boxer_female.gltf`/`boxer_female.bin` from the source model and selected animation tracks. Original download inputs are preserved in the ignored `source/` directory for reproducibility and excluded from Godot import/export.

The game adds fitted boxing shorts, shoes, hair coverage and gloves, plus bone-bound helmets, shoulder/chest protection, ponytail/hair, visor, mask and cloth accessories. Zephyr and Raven use the separate female anatomy; the other fighters use the male base. These are two source sculpts with six assembled identities, not six individually commissioned models. `tools/bake_crowd.gd` generates the reduced crowd geometry and shared 24 Hz poses; run it with Godot's native renderer. The hero keeps the continuous imported skeleton. These are modified CC0 assets, not original sculpting by this project.

All new arena geometry, UI icons, skill effects and musical compositions/SFX in this project are original procedural work. No characters, music, models or code from Street Fighter, King of Fighters or Endless Puncher are included.
