/// Centralized feature toggles controlled via --dart-define flags.
///
/// Example usage when running the app:
/// ````
/// flutter run --dart-define=DISABLE_APP_UPDATE_GATE=true
/// ````
const bool kDisableAppUpdateGate =
    bool.fromEnvironment('DISABLE_APP_UPDATE_GATE', defaultValue: false);

const bool kAppCheckForceDebug =
    bool.fromEnvironment('APP_CHECK_DEBUG', defaultValue: false);

/// Debug-only App Check token pinned for van1 dev/emulator builds.
/// Register this exact token once in Firebase Console → App Check → van.merchant → Debug tokens.
/// Override at build time with --dart-define=VAN1_APP_CHECK_DEBUG_TOKEN=...
const String kVan1AppCheckDebugToken = String.fromEnvironment(
  'VAN1_APP_CHECK_DEBUG_TOKEN',
  defaultValue: 'd1a5b8e3-7f2c-4a6d-9e1b-3c4d5e6f7a82',
);
