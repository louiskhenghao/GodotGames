# Mobile Core

Reusable Godot 4.5.1 services. No `game/` import, Ring Rush catalog, fighter IDs, starter currency, venue rules or game assets belong here.

## Start another game

From the host repository:

```sh
python3 tools/create_game.py /absolute/path/to/NewProject --name 'My Next Game'
```

For a monorepo game use `python3 tools/workspace.py new SpaceDash`. Maintain shared code in `packages/mobile-core/addon`, then `python3 tools/workspace.py sync`. Run standalone tests with `python3 tools/workspace.py test-core`.

The standalone command copies only this addon and `templates/core_starter/` into a new directory. The example has test purchases, rewarded ads and in-game notices. It starts with zero coins; the host owns its welcome economy. Existing directories are never overwritten. Add your own Android/iOS export presets, app IDs and native providers.

## Services

| Module | Responsibility | Host supplies |
| --- | --- | --- |
| `CoreSaveStore` | Atomic JSON commit, backup recovery, transactions | Save path and game progress schema |
| `CoreWallet` | Idempotent coin unlocks, ownership, insufficient-funds checks | Validated catalog key and price |
| `CoreCommerce` | Ads / IAP lifecycle, timeouts, durable reward receipts, restore and deduplication | Product catalog, placements and provider |
| `CoreNoticeBus` | In-game notification event | Localized text and UI presentation |
| `CoreNotifications` | Explicit permission boundary, scheduling validation and cancellation | Platform notification adapter |
| `CoreMusicPlayer` | Cue selection, stream reuse, looping, preserved volume | Cue IDs and audio resources |
| `CoreAudioPool` | Bounded overlapping sound voices | Audio clips |
| `CoreImpactPool` | Bounded 3D effects | Positions, colors and effect calls |
| `CoreVirtualStick` | Touch ownership and excluded action regions | Host input layout |
| `CoreButtonLayout` | Symmetric label insets and icon positioning | Button, glyph control and theme |

The `MobileCore` autoload wires save, commerce, notices and notifications. Debug / `playtest` builds use separate save files. Commerce's mock provider requires an explicit project setting; production defaults to an unavailable provider until the host injects a real adapter.

```gdscript
MobileCore.configure_commerce(
    {"coin_pack": {"coins": 500}, "remove_ads": {"entitlement": "remove_ads"}},
    {"optional_bonus": 50},
    my_native_commerce_provider
)
MobileCore.commerce.buy("coin_pack")
MobileCore.notices.post("Purchase saved")
```

`CoreWallet` does not trust arbitrary UI prices: the host must look up known IDs in its own catalog before calling `unlock`. Game-specific benefits, combat snapshots and reward application stay in the host. A verified receipt ID and its coin/entitlement grant commit together. Store receipt verification itself must be implemented by a trusted native/backend adapter; this addon does not claim to verify Apple/Google receipts.

## Notifications

In-game messages and OS notifications are separate services. The addon does not ask for permission on launch, schedule reminders automatically, or send network requests.

Subclass `CoreNotificationProvider` and inject it with `MobileCore.notifications.configure(adapter)`. The provider owns native platform permission state and scheduling. Call `request_permission()` only after the player explicitly enables reminders in your UI. Forward the platform result through `permission_changed`.

```gdscript
# After opt-in and a granted permission result:
var result = MobileCore.notifications.schedule(
    "daily_challenge", "New challenge", "Your next round is ready",
    int(Time.get_unix_time_from_system()) + 86400,
    {"screen": "challenge"}
)
# Stable IDs replace the same reminder; cancel when the reason no longer applies.
MobileCore.notifications.cancel("daily_challenge")
```

Unsupported adapters return `ERR_UNAVAILABLE`; denied permissions return `ERR_UNAUTHORIZED`. No mock success is reported. This is an adapter contract, not an installed native notification SDK. Remote push delivery requires a separate server/provider integration.

## Host boundaries and validation

Ring Rush's `games/RingRush/game/bootstrap.gd` owns its 1,200-coin playtest gift and retired-fighter migration. `games/RingRush/game/challenges.gd` owns the secret arena gate. `games/RingRush/game/music.gd` owns the soundtrack catalog. The host HUD renders notice events and chooses its own colors/icons.

`packages/mobile-core/tests/services_tests.gd` validates failed-save atomicity, duplicate unlocks, notification permission/availability rules, cue changes and cue behavior. A generated project was separately imported and started with no Ring Rush assets or code. Use `templates/core_starter/` as the minimal integration example.

## Reusable real-time effects

`CoreImpactPool` is the public facade. Its child `CoreSpectaclePool` batches debris, soft clouds, light flares and ground waves into four fixed MultiMeshes; essential projectile bodies have a separate 128-instance batch. The host owns projectile movement, collisions, damage and warning timing. No RingRush assets or classes are imported by these effects.

```gdscript
var fx := CoreImpactPool.new()
add_child(fx)
fx.detail = 0 # 0: fewer decorative emissions; 1: normal
fx.quake(Vector3.ZERO, Color("ffc04d"), 4.6)
fx.explosion(Vector3(2, 0, 0), Color("e597f3"), 2.3)
fx.flame_jet(Vector3(0, 1, 0), Vector3.FORWARD, 4.0, Color("ff9e4d"))
fx.projectile(position, direction, color, "missile", 0.32)
# On scene exit, replay restart or loaded snapshot:
fx.clear()
```

`enabled = false` disables optional debris/clouds/flashes. Essential `projectile`, `stroke`, and `ring(..., true)` calls remain visible. Call `clear()` when switching effects off to remove existing decorations. The host should call `projectile` each simulation frame for every visible shot; the `trail` argument lets it throttle decorative trails independently.

Fixed capacities: 96 rocks, 64 clouds/flame puffs, 64 flares, 12 ground waves, 128 projectile markers; legacy pools retain 192 sparks, 48 line strokes, 12 rings and 16 damage labels. Saturated decoration pools recycle their oldest slot. This renderer deliberately avoids lights per projectile, screen-reading shaders and runtime physics debris. Cracks are temporary geometry above the floor, not permanent terrain destruction.

Instance color and custom shader data follow the [Godot MultiMesh interface](https://docs.godotengine.org/en/4.5/classes/class_multimesh.html). Native Compatibility and WebGL 2 are validated for RingRush; mobile device thermal/GPU validation remains a host release task.

## Accounts and offline-first cloud saves

`CoreApiClient`, `CoreCloudProfile`, and `CoreAccountSync` live in `addon/cloud/`. They use the shared `apps/backend` HTTP API; there are no RingRush imports or models. `CoreAccountSync` is exposed as `MobileCore.account`. It is idle until a host configures it and a player signs in.

```gdscript
# Configure once, before game-specific save migrations and commerce setup.
MobileCore.account.configure(
    MobileCore.save,
    "your_game_id",
    "https://your-api-host",
    func(): return current_screen in ["home", "account"] and not payment_in_progress
)
MobileCore.account.profile_loaded.connect(refresh_game_from_profile)
MobileCore.account.changed.connect(refresh_account_status)

# Call from your own UI; don't log the password or store it in a profile.
MobileCore.account.login(email_field.text, password_field.text)
MobileCore.account.email_action("register", email_field.text, password_field.text)
MobileCore.account.email_action("forgot-password", email_field.text)
MobileCore.account.check_verification()
MobileCore.account.sync_now()
MobileCore.account.logout()
```

The host supplies game ID, HTTPS API origin, presentation, and a callback identifying a safe menu state. Do not start gameplay while `account.busy` is true: a sync can replace the active profile. Render `account.status`, `account.verified`, `account.busy`, and `account.conflict`; subscribe to `profile_loaded` to reapply game migrations, selected character, settings and resume availability. Keep using the **same CoreSaveStore instance**; account switching changes its path/data so wallet and commerce keep referencing the active profile.

- Every ordinary save commits to disk first. Cloud uploads are debounced by 3 seconds; reconnect checks run at safe menus at most once per minute. Network failures never disable local play.
- Guest progress and each user UUID have different files. A local account index reopens the last account's offline copy after restart. Credentials are **memory-only** in this version; restarting requires login to resume cloud sync. Keystore/Keychain-backed persistent login is a future platform adapter, not plaintext `user://` storage.
- A new cloud account asks whether to import guest progress (`resolve("guest")`) or start fresh (`resolve("new")`). The guest file stays separate. Simulated IAP entitlement flags and IAP receipts are excluded from import. Existing playtest coins are gameplay progress, not evidence of a verified store transaction.
- Diverging revisions require `resolve("device")` or `resolve("cloud")`. The selected remote revision is checked again before writing. Both choices create a timestamped local conflict backup; the backend retains its recent save history too. Choosing either save replaces the whole progression; balances are never summed.
- Revision and digest metadata are committed with the profile. JSON number normalization prevents false conflicts between in-memory integer values and values parsed from HTTP. A lost upload acknowledgement is recognized on the next download.
- Tokens, device-local reward promises and cloud bookkeeping are excluded from the upload. Gameplay stats, unlocks, badges, equipment and resumable runs belong inside the regular `CoreSaveStore` profile. Profiles up to 500 KB are supported; larger histories need a game-specific compaction/migration.
- Ledger pages apply signed coin grants/refunds once by cursor. Refunds exceeding the balance retain `iap_debt`; future paid credits settle it. Inventory replaces the server-managed entitlement keys. This prepares cloud restoration for billing; it does **not** launch Play Billing or verify a client purchase.

`packages/mobile-core/tests/cloud_tests.gd` runs in the independent generated core project via `test-core`. The RingRush-only visual presentation is `games/RingRush/game/account_screen.gd`; another game can provide its own UI without reimplementing synchronization.
