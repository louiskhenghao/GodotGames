# Boss combat — 0.5.0

Each champion owns a `RushBossCombat` instance. Ordinary enemy AI is unchanged. Boss decisions, counter rewards and phase state belong to RingRush; VFX, sound pooling and persistence remain in mobile-core.

## Decisions and recovery opportunities

| Situation | Player decision | Result |
| --- | --- | --- |
| Red circle / charge lane | Leave the committed danger zone | Avoid the attack |
| Final 0.42 seconds, gold marker | Cast a technique and actually hit | Interrupt the complete combo, 1.6× hit, 1.65 s stagger, +12 energy, 35% remaining skill cooldown refund |
| Final 0.30 seconds while inside danger | Dodge | 2.2 s counter window; next direct/skill hit on this boss deals 2.5×, staggers 0.9 s, grants +8 energy |
| Boss below half health | Read a fresh two-strike pattern | Phase II, with one safe 0.95 s entrance and separate full telegraphs |

Counter takes priority if a post-dodge skill also lands inside the break window. Rewards are consumed once. Early or out-of-range casts do not break. Automatic punches cannot trigger skill breaks; passive burn/orbit/chain cannot consume a counter. Sustained skills must be deliberately cast during the gold window, then hit before it closes. A broken opening strike cancels its follow-up.

Slam, charge and locked-target lightning form venue-dependent opening patterns. Rift opens with lightning; Boss Rush rotates openers by round. Phase II adds a different follow-up, a 0.5 s gap, then at least 1.85 s recovery. Telegraph durations stay 1.05 / 0.95 / 1.15 seconds; growth does not compress them. Phase II moves 18% faster and has stronger impacts, without restoring health. Normal movement can dodge all three threats without spending a skill.

The top boss strip communicates phase and current action. The available skill button changes to BREAK! during the window. Essential ground warnings remain when decorative VFX are disabled. Rewards use the strip rather than covering HP with a toast. No additional mobile button was added.

## Save and pool behavior

Snapshots keep phase and pattern position. Partial telegraphs, rushes and reward windows reset on resume, with a 1.25 s delay before a new readable attack. Old saves infer phase from remaining health. JSON numeric fields are validated after round-trip; unsupported/fractional states are rejected. Reconfigured pooled enemies get a fresh encounter, and non-boss actors have none.

## Validation

`tests/boss_tests.gd` covers phase transitions, all six skill hits, early/missed casts, passive damage, full-combo interruption, one-time counter consumption, cooldown/refund, collision tunneling, marker lock, UI bounds and old/new JSON snapshots. `tests/boss_capture.gd` produces phone/small-screen/tablet screenshots. `tests/performance.gd` accepts `boss` to measure a champion inside the maximum crowd.

Fastest manual test: PLAY → Boss Rush → FIGHT. Try a normal dodge first, then a gold-window skill; drop the boss below half and watch the second warning before committing again.
