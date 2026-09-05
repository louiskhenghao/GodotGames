# Ring Rush visual direction

Extend the existing underground boxing identity: midnight blue surfaces, warm ivory lettering, cyan fighter equipment and gold primary actions. The game and its fighter are the visual focus; menus support quick repeated play.

- Barlow Condensed Bold for boxing-poster headings and controls; Godot's readable UI font for explanations.
- Original vector line icons with a consistent 2.2-unit stroke. No emoji/glyph substitutes for controls.
- Animated 3D fighter showroom on a cyan-edged podium. Keep the character above the nameplate and the primary action visible.
- An isometric ring with restrained stadium geometry, spectators and small cyan apron accents. Warm key light and cool fill light separate body volumes.
- Hero geometry gets more detail than distant crowd actors. Bake small details into the six animated surfaces; share meshes and instance repeated environment geometry.
- Gameplay information belongs above the ring; active moves belong below it. Pause, special availability and cooldowns must be readable at a glance.
- Full-height secondary screens with scrollable content support shorter phones and tablets. No essential button may be reachable only through a decorative animation.
- Combat feedback uses short punch animation, bounded particle bursts, damage numbers, visible attack warnings and expanding area rings. Camera shake and effects can be disabled.
- Canvas expands to device aspect ratio, with native safe-area insets and second-finger skill controls. Physical-device verification remains required.
