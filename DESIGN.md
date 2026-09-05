# Ring Rush visual direction

Extend the existing underground boxing identity: midnight blue surfaces, warm ivory lettering, cyan fighter equipment and gold primary actions. The game and its fighter are the visual focus; menus support quick repeated play.

- Barlow Condensed Bold for boxing-poster headings and controls; Godot's readable UI font for explanations.
- Original vector line icons with a consistent 2.2-unit stroke. No emoji/glyph substitutes for controls.
- Animated 3D fighter showroom on a cyan-edged podium. Keep the character above the nameplate and the primary action visible.
- Five isometric venues: underground ring, neon street ambush, skyline helipad, industrial furnace hall and dawn temple courtyard. Foreground street buildings stay low to preserve combat visibility. Warm/cool lighting identifies each venue.
- Hero uses a continuous textured humanoid with a real skeleton. Crowd geometry shares reduced 24 Hz baked poses from the same source animations. Keep body proportions and animation recognizable at the gameplay camera distance.
- Gameplay information belongs above the ring; active moves are circular floating icons on the right; the left lower half belongs to movement. Pause, technique cooldown, ultimate availability and dodge cooldown must be readable at a glance.
- Full-height secondary screens with scrollable content support shorter phones and tablets. No essential button may be reachable only through a decorative animation.
- Combat feedback uses short punch animation, bounded particle bursts, damage numbers, visible attack warnings and expanding area rings. Camera shake and effects can be disabled.
- Canvas expands to device aspect ratio, with native safe-area insets and second-finger skill controls. Physical-device verification remains required.

- Six original fighting identities use different stats, starting passives and signature moves. Characters and moves are purchased with earned coins, with clear ownership/selection states.
- Short challenge: ten waves; endurance: thirty or fifty; world ladder: five venues with a boss at each transition. Offer recovery and build decisions between escalation beats.
- Ground-slam cracks/debris, cyclone rings, lightning chains, piercing fire and tracking punch trails must remain visually distinct. Crowd launch reactions create a genuine stagger window.
- An unobtrusive lower-screen gradient protects action-label contrast against tall scenery. Menus scroll; core combat controls remain visible.
- Original rhythmic music layers support the menu, general fights and street venue. Effects have separate transients for fists, heavy slams, electricity, wind and knockouts.

## UX refinement

- Home has one dominant Play/Resume action and three destinations: Fighter, Skills, Shop.
- Fighter selection uses arrows to switch identities and dragging to rotate the visible model with one visible 3D model, three stat bars, a signature icon and one selection/unlock button. Preview does not change the saved loadout.
- Skill choice uses six semantically colored icons and short names. Reveal one tactical hint at a time and provide a real effect preview.
- Model identity comes from two anatomical bases and silhouette-changing equipment, not just palettes.
- Venue boundaries and real map previews share a convex polygon definition. Collision props and perimeter dressing support the same layout.
- Toasts appear below the top header, clear on navigation and never block bottom actions.
- Ads stay off the fighting screen. Voluntary rewards are explicit, limited and retained after Remove Ads. Never stack an interstitial immediately after an earned rewarded video.

## Continuous combat refinement

- Fight picker: real 3D map above; venue selection and challenge controls below.
- Skill rewards are a protected-focus modal over the unchanged arena. Use a 0.22 s restrained scale entrance and a faster 0.12 s fade exit, with a reduced-motion alternative.
- Do not fade the entire menu root. Secondary menu backgrounds remain opaque while their controls change.
- The fighter stays near the center of a closer view; a small dead zone prevents camera jitter, then travel smoothly reveals the rest of the map.
- Boxing-gym scenery enriches the showroom. Keep its lettering subordinate to the interface, and protect stat/action contrast with restrained veils.
- Hits must visibly interrupt a foe's pose. KOs have a readable fall, ground hold and short fade. Corpse presentation is bounded and cannot award duplicate coins or interfere with wave completion.

### September refinement

Keep the boxing club identity, with a brighter royal-blue upgrade surface (`#163065`) and hue-tinted skill cards. Text determines card height; rank metadata never floats outside its action. Upgrade choices scroll only when the safe height requires it. Wave clear uses centered ivory text on saturated teal (`#147b72`). Floating right-side Fighter / Skills / Shop destinations leave the character dominant; Play occupies the bottom action area above any banner. Gym shows current → next values and a visible coin cost. Skill silhouettes and enemy warnings stay readable even when decorative impact effects are disabled.
