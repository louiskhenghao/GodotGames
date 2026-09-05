# Android, iOS and live monetization

The project includes platform presets, not signed mobile binaries. Desktop import, gameplay tests and real Godot renders were verified with 4.5.1. Android/iOS device behavior and native SDKs have not been tested. Pin one engine version and use its matching export templates and compatible native plugins.

## Android

1. Install matching Godot export templates, OpenJDK 17 and the Android SDK packages required by that Godot version. Configure the Java SDK and Android SDK paths in Godot editor settings.
2. Use **Project → Install Android Build Template**. The provided Android preset uses a Gradle ARM64 AAB build. For a sideloadable development build, choose APK in the preset or duplicate it as an APK preset.
3. Replace `com.example.ringrush` with your app ID. Configure your release keystore locally; do not commit credentials. Set the target SDK and dependencies to the store requirements in force when submitting.
4. Export, install on physical devices, and measure frame time, thermals, memory, pause/resume, sound interruption and touch controls.

```sh
mkdir -p builds/android
godot --headless --path . --export-release Android builds/android/ring-rush.aab
```

This command requires the templates, SDK, Gradle build template and signing setup above. [Godot Android export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html) describes the environment and AAB workflow.

## iOS

1. Use macOS with Xcode and matching Godot export templates.
2. Replace the bundle identifier and fill in your Apple developer Team ID. Configure signing/provisioning using your account. The provided preset deliberately leaves the Team ID empty.
3. Export the Xcode project, open it in Xcode, select the development team and test on a physical iPhone/iPad. Archive with distribution signing when ready.
4. Verify safe-area layout, app backgrounding, interruptions, audio behavior, touch ownership and restore purchases before TestFlight distribution.

Godot 4.5's [iOS export guide](https://docs.godotengine.org/en/4.5/tutorials/export/exporting_for_ios.html) covers Xcode export and signing. It notes that the iOS simulator export is not supported in that version; use physical devices for this project.

## Connect real monetization

The default mock demonstrates the game-facing flow only. It does **not** integrate AdMob, Google Play Billing, StoreKit, or any mediation network. Selecting and installing compatible native plugins, writing their adapters and operating receipt verification are required before enabling real products.

For the first commercial integration, use one rewarded-ad provider plus each platform's native purchase system. The game catalog now includes training coins, one revive per run, a victory bonus, non-consumable Remove Ads and the gold-glove cosmetic. Integrate banner and interstitial placements alongside rewarded videos; Remove Ads must suppress only banner/automatic placements.

1. Set up app records, banner, interstitial and rewarded ad units plus both non-consumable products in your own accounts. Native product identifiers must map to the game catalog. Store pricing must be fetched and displayed using the store's localized product metadata; never use the current test button as a purchase confirmation.
2. Implement a `CoreCommerceProvider` adapter using the selected plugin's real API. Inject it as the third argument to `configure_commerce`. Start SDK initialization and ad loading only after the applicable consent flow has completed; add tracking permission only if the integration requires it.
3. Use official test ad units and store sandbox accounts. Emit `earned=true` only from the SDK's earned-reward event. Ad dismissal, no-fill and loading failure are not rewards. Keep close controls and video duration under SDK control; do not overlay the development 5/15-second timer on real ads. Connect dismissal after the earned event, so the reward receipt is persisted correctly. An earned reward must not be discarded merely because an SDK later reports dismissal; bridge callback ordering deliberately. Tune loading/showing timeouts to the chosen SDK and reconcile verified rewards on resume. See [Google's rewarded-ad callbacks](https://developers.google.com/admob/android/rewarded).
4. Validate purchase tokens/receipts through a trusted backend. Deliver only confirmed purchases, persist the entitlement and stable transaction ID, and then acknowledge/finish the store transaction through a retryable workflow. Handle pending/deferred purchases and reconcile store transactions at launch/resume. See [Google Play purchase security](https://developer.android.com/google/play/billing/security) and [Apple In-App Purchase](https://developer.apple.com/documentation/storekit/in-app-purchase).
5. Implement restore and refund/revocation reconciliation against current verified entitlements. The current core merges restored entitlements and therefore needs an explicit revocation path for production.
6. Enable Android internet permission and native plugin export options as required. Add the chosen SDK's iOS configuration, privacy manifests and platform disclosures. Supply production icons, a privacy policy and store metadata matching the actual integration.

## Release checks tied to this implementation

- No debug provider or mock profile in a release export; verify missing configuration produces an unavailable state.
- Test real ad completion, cancellation, no-fill, callback duplication and interruption. Ensure a granted reward is retained after restarting.
- Test pending purchase, validation failure, timeout followed by success, local save failure, duplicate transaction, reinstall/restore and refunded ownership.
- Verify no ad triggers during combat, optional rewards are clear, and a store cancellation returns control to the player.
- Benchmark maximum crowds on low-end Android and an older supported iPhone. Review UI at tall, short and tablet aspect ratios.

Unique boss attack patterns, commissioned character art, long-term economy tuning, analytics, remote configuration and live operations remain next production work. See `game-plan.md` for the ordered gameplay roadmap.
