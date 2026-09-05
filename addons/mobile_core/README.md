# Mobile Core

Reusable Godot 4.5.1 services. No `game/` import, Ring Rush catalog, fighter IDs, starter currency, venue rules or game assets belong here.

## Start another game

From the host repository:

```sh
python3 tools/create_game.py /absolute/path/to/NewProject --name 'My Next Game'
```

This copies only this addon and `templates/core_starter/` into a new directory. The example has test purchases, rewarded ads and in-game notices. It starts with zero coins; the host owns its welcome economy. Existing directories are never overwritten. Add your own Android/iOS export presets, app IDs and native providers.

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

Ring Rush's `game/bootstrap.gd` owns its 1,200-coin playtest gift and retired-fighter migration. `game/challenges.gd` owns the secret arena gate. `game/music.gd` owns the soundtrack catalog. The host HUD renders notice events and chooses its own colors/icons.

`tests/core_services_tests.gd` validates failed-save atomicity, duplicate unlocks, notification permission/availability rules, cue changes and migration behavior. A generated project was separately imported and started with no Ring Rush assets or code. Use `templates/core_starter/` as the minimal integration example.
