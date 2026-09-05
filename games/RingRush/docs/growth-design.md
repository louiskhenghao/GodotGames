# Ring Rush 0.4.0 — growth design

The player gets stronger faster than the automatic rival adjustment. The optional hard contract increases the challenge for a 25% coin bonus. Progress is frozen at the beginning of a fight; purchases between sessions cannot change a resumed fight. The host owns these rules; reusable `mobile_core` services remain game-independent.

## New roster

| Fighter | Coins | HP | Power | Speed | Starting skill / identity |
| --- | ---: | ---: | ---: | ---: | --- |
| AEGIS | 1,800 | 190 | 33 | 3.9 | Quake; 2 guard ranks; 8% wider skills |
| ION | 2,600 | 125 | 27 | 5.3 | Thunder; 2 chain ranks; 8% faster skill recharge |
| ONYX | 3,600 | 165 | 38 | 4.4 | Fire Wave; 2 burn ranks; 12% more skill damage |

Three CC0 chassis have original robot helmets and boxing arms; all six earlier humans remain. Each new fighter has a different showroom. These models are separate meshes with native locomotion/hit clips and custom fist articulation. Skeletons remain Rift-only enemies.

## Gym

Eight disciplines, 30 levels each. Individual discipline tiers: Bronze 1–5, Silver 6–10, Gold 11–15, Platinum 16–20, Diamond 21–25, Master 26–30. Untrained is shown as Bronze / 0. The club rank counts total training purchases and advances at 20 / 50 / 90 / 140 / 200 levels. The UI shows both the club rank and each discipline's tier.

| Discipline | Benefit | At level 30 |
| --- | --- | --- |
| Power | +3 per first five levels; +1.5 afterward | +52.5 base punch damage |
| Health | +10 per first five; +6 afterward | +200 starting HP |
| Energy | +10 starting charge per first five; +0.6 afterward | Start with 100% ultimate |
| Speed | +4% per first five; +0.8% afterward | +40% base movement |
| Cooldown | −4% per first five; −0.8% afterward | 40% shorter skill cooldown |
| Resilience | 0.6% incoming damage reduction per level | 18% reduction |
| Recovery | +0.3% max HP after each wave per level | +9% recovery |
| Coin bonus | +1% fight settlement coins per level | +30% coins |

The next level costs 80 + 50 × current level. Original level 1–5 purchases preserve their benefits. Body / Tech / Rewards filters reduce scrolling; PLAY and BADGES stay fixed at the bottom. Costs, level, ownership and badge grants are committed together.

## Skills

Six techniques each support levels 1–10. New levels add 12% damage and 3.5% targeting radius, and reduce the base cooldown by 1.5%. At level 10: +108% damage, +31.5% radius, −13.5% cooldown before GYM, fighter and badge modifiers.

Level 5 awakens a secondary color and extra impact ring; level 10 adds a further ring and vertical energy accent. Thunder also gains two chain targets at each milestone. Quake, Cyclone, Uppercut, Flurry targeting and Fire Wave width use the actual increased collision range. Effect pools stay bounded. The next rank costs 100 + 70 × current rank + 12 × current rank².

Both preview Back actions return to Skills. Previews use the owned rank and training, and do not count toward achievements.

## 36 badges

- Combat: 4 knockout totals (10 / 100 / 500 / 2,000); 3 best-combo targets (10 / 25 / 50); 2 boss totals (1 / 25).
- Victories: first clear of each of 8 finite modes; a victory in each of the 5 ordinary venues.
- Growth: 5 / 50 / 200 total training levels; highest skill level 2 / 5 / 10; owning 2 / 6 / 9 fighters.
- Style: 20 casts each of Quake / Cyclone / Thunder; 10 ultimates; 50 dodges.

Each badge grants either +1 HP, +0.2 power or −0.2% cooldown. All 36 together grant only +12 HP, +2.4 power and −2.4% cooldown. Badges unlock automatically; no repetitive claim button. Cards show the objective, progress and exact benefit. The result screen links to newly earned badges. Existing tracked KO, venue and mode records count retroactively; unrecorded old combos/casts cannot be reconstructed.

Run metrics settle with the run transaction. Retrying, reloading or previewing cannot grant duplicate metrics/rewards. A failed save does not change the wallet, upgrades or badges. Pending snapshots retain growth and action counts; old snapshots remain valid without those optional fields.

## Rivals and hard contracts

Rival growth considers total GYM levels, equipped skill rank and premium fighter power. Automatic caps: +65% health, +30% damage, +6% speed. Attack telegraphs are not accelerated. A fresh Atlas has no automatic increase. Hard contracts add +30% base enemy HP and +20% base damage for +25% coins; this is additive to the automatic factors, not a secret multiplier. The GYM shows the resulting rival bonuses and the fight picker shows when a contract is active.

Recovery training also works in Hell; it is an earned counter to that mode's normal zero recovery. Coin bonuses settle once, including banked unfinished fights, and apply before optional rewarded-video bonuses.

## Next design priorities

Use real playtest feedback to tune time-to-unlock and boss pressure. The next substantial addition should be bosses with distinct second phases and readable counters, then cosmetic rewards for veteran achievements. Additional damage inflation is a lower priority than richer decisions during a fight.
