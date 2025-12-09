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
