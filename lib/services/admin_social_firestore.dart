import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Isolated Firestore database for van4 admin-only data (social, etc.)
class AdminSocialFirestore {
  AdminSocialFirestore._();

  static const String databaseId = 'van4';

  static FirebaseFirestore get instance => FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: databaseId,
      );
}
