/// Feature toggles via --dart-define (see van1/van2).
const bool kAppCheckForceDebug =
    bool.fromEnvironment('APP_CHECK_DEBUG', defaultValue: false);
