import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../firebase_options.dart';
import '../utils/app_check_guard.dart';

/// van4 admin uploads — explicit bucket + auth/App Check ก่อน Storage write
class AdminStorageHelper {
  AdminStorageHelper._();

  static FirebaseStorage get instance {
    final bucket = DefaultFirebaseOptions.currentPlatform.storageBucket;
    if (bucket != null && bucket.isNotEmpty) {
      return FirebaseStorage.instanceFor(
        app: Firebase.app(),
        bucket: bucket,
      );
    }
    return FirebaseStorage.instance;
  }

  static Future<void> ensureUploadReady() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('กรุณาเข้าสู่ระบบก่อนอัปโหลด');
    }
    await user.getIdToken(true);
    await AppCheckGuard.ensureCallableReady();
  }
}
