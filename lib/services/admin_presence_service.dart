import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers admin online presence + FCM token for internal calls.
class AdminPresenceService {
  AdminPresenceService._();

  static final AdminPresenceService instance = AdminPresenceService._();

  bool _started = false;

  Future<void> ensureRegistered() async {
    if (_started || kIsWeb) {
      return;
    }
    _started = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      final email = user.email?.trim().toLowerCase();
      final now = FieldValue.serverTimestamp();

      if (email != null && email.isNotEmpty) {
        await FirebaseFirestore.instance.collection('admins').doc(email).set(
          <String, dynamic>{
            'authUid': user.uid,
            'email': email,
            'displayName': user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : email,
            'lastSeenAt': now,
            'active': true,
          },
          SetOptions(merge: true),
        );
      }

      await FirebaseFirestore.instance.collection('admin_presence').doc(user.uid).set(
        <String, dynamic>{
          'uid': user.uid,
          if (email != null) 'email': email,
          'displayName': user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (email ?? 'แอดมิน'),
          if (token != null && token.isNotEmpty) 'fcmToken': token,
          'lastSeenAt': now,
          'platform': defaultTargetPlatform.name,
        },
        SetOptions(merge: true),
      );

      FirebaseMessaging.instance.onTokenRefresh.listen((nextToken) async {
        await FirebaseFirestore.instance.collection('admin_presence').doc(user.uid).set(
          <String, dynamic>{
            'fcmToken': nextToken,
            'lastSeenAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });
    } catch (error) {
      debugPrint('AdminPresenceService registration failed: $error');
    }
  }
}
