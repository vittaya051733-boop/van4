import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'admin_app.dart';
import 'firebase_options.dart';
import 'services/observability_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  try {
    await ObservabilityService.instance.initialize(appName: 'van4_admin');
  } catch (_) {}
  runApp(const VanMarketAdminApp());
}