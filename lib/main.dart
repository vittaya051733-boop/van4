import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'admin_app.dart';
import 'firebase_options.dart';
import 'services/admin_firestore.dart';
import 'services/observability_service.dart';
import 'utils/feature_flags.dart';

/// Debug-only App Check token for van4 admin sideload builds.
/// Register in Firebase Console → App Check → van4.com → Debug tokens.
const String kVan4AppCheckDebugToken = String.fromEnvironment(
  'VAN4_APP_CHECK_DEBUG_TOKEN',
  defaultValue: 'a3f9c2e1-4b8d-4a6f-9e2c-1d7b5e8f0a42',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Must be set before any Firestore call (desktop gRPC cold-start).
  if (defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux) {
    AdminFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
  }

  final useDebugAppCheck = !kReleaseMode || kAppCheckForceDebug;
  try {
    await FirebaseAppCheck.instance
        .activate(
          providerAndroid: useDebugAppCheck
              ? AndroidDebugProvider(debugToken: kVan4AppCheckDebugToken)
              : const AndroidPlayIntegrityProvider(),
          providerApple: useDebugAppCheck
              ? const AppleDebugProvider()
              : const AppleDeviceCheckProvider(),
        )
        .timeout(const Duration(seconds: 5));
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

    if (useDebugAppCheck) {
      debugPrint(
        'van4 App Check debug token (register in Firebase Console → van4.com Android): '
        '$kVan4AppCheckDebugToken',
      );
    }

    try {
      await FirebaseAppCheck.instance
          .getToken(true)
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      if (useDebugAppCheck) {
        debugPrint('van4 App Check getToken on startup failed: $error');
      }
    }
  } catch (error) {
    if (useDebugAppCheck) {
      debugPrint('van4 App Check activate failed: $error');
    }
  }

  try {
    await ObservabilityService.instance.initialize(appName: 'van4_admin');
  } catch (_) {}
  runApp(const VanMarketAdminApp());
}
