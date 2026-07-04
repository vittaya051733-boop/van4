import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/admin_peer_profile.dart';

class AdminCallService {
  AdminCallService._();

  static const List<String> _regions = <String>[
    'asia-southeast1',
    'us-central1',
  ];

  static Future<Map<String, dynamic>> initiateVoiceCall({
    required AdminPeerProfile caller,
    required AdminPeerProfile callee,
  }) async {
    FirebaseFunctionsException? lastError;

    for (final region in _regions) {
      try {
        final callable = FirebaseFunctions.instanceFor(
          region: region,
        ).httpsCallable('initiateCall');
        final result = await callable.call<Map<String, dynamic>>(<String, dynamic>{
          'calleeId': callee.uid,
          'callerId': caller.uid,
          'callerName': caller.displayName,
          'callerPhotoUrl': caller.photoUrl,
          'isVideo': false,
          'callType': 'voice',
          'callerData': caller.toCallPayload(),
        });
        return Map<String, dynamic>.from(result.data);
      } on FirebaseFunctionsException catch (error) {
        lastError = error;
        debugPrint('initiateCall via $region failed: ${error.code} ${error.message}');
        if (error.code != 'not-found') {
          rethrow;
        }
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    throw StateError('ไม่สามารถเริ่มการโทรได้');
  }

  static Future<AdminPeerProfile> currentAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('กรุณาเข้าสู่ระบบก่อนโทร');
    }
    return AdminPeerProfile(
      uid: user.uid,
      displayName: user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.trim().isNotEmpty == true ? user.email!.trim() : 'แอดมิน'),
      email: user.email,
      photoUrl: user.photoURL,
    );
  }
}
