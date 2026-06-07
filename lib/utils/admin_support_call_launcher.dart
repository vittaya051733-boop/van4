import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:van1/call_screen.dart';
import 'package:van1/models/user_profile.dart';

class AdminSupportCallLauncher {
  AdminSupportCallLauncher._();

  static Future<void> startVoiceCallToRequester({
    required BuildContext context,
    required String requesterUid,
    required String requesterName,
    String? requesterPhone,
    String? sourceApp,
  }) async {
    await startVoiceCallToPeer(
      context: context,
      peerUid: requesterUid,
      peerLabel: requesterName,
      phoneNumber: requesterPhone,
      sourceApp: sourceApp,
    );
  }

  static Future<void> startVoiceCallToPeer({
    required BuildContext context,
    required String peerUid,
    required String peerLabel,
    String? phoneNumber,
    String? sourceApp,
  }) async {
    final trimmedPeerUid = peerUid.trim();
    if (trimmedPeerUid.isEmpty) {
      _showSnack(context, 'ไม่พบบัญชีปลายทางสำหรับเริ่มการโทร');
      return;
    }

    try {
      final caller = await _buildCurrentAdminProfile();
      if (!context.mounted) {
        return;
      }
      if (caller.uid == trimmedPeerUid) {
        throw Exception('ไม่สามารถเริ่มการโทรหาบัญชีตัวเองได้');
      }

      final callee = await _buildPeerProfile(
        uid: trimmedPeerUid,
        fallbackLabel: peerLabel,
        fallbackPhone: phoneNumber,
        sourceApp: sourceApp,
      );

      final callData = await _initiateCall(caller: caller, callee: callee);
      if (!context.mounted) {
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CallScreen(
            channelName:
                (callData['channelId'] as String?) ??
                _fallbackChannelId(caller.uid, callee.uid),
            isVideo: false,
            targetProfile: callee,
            appIdOverride: callData['appId'] as String?,
            tokenOverride: callData['token'] as String?,
            isIncoming: false,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showSnack(context, 'เริ่มการโทรในแอปไม่สำเร็จ: $error');
    }
  }

  static Future<Map<String, dynamic>> _initiateCall({
    required UserProfile caller,
    required UserProfile callee,
  }) async {
    const regions = <String>['asia-southeast1', 'us-central1'];
    FirebaseFunctionsException? lastError;

    for (final region in regions) {
      try {
        final callable = FirebaseFunctions.instanceFor(
          region: region,
        ).httpsCallable('initiateCall');
        final result = await callable.call(<String, dynamic>{
          'calleeId': callee.uid,
          'callerId': caller.uid,
          'callerName': caller.displayName,
          'callerPhotoUrl': caller.photoUrl,
          'isVideo': false,
          'callType': 'voice',
          'callerData': caller.toFirestore()..['uid'] = caller.uid,
        });
        return Map<String, dynamic>.from(result.data as Map);
      } on FirebaseFunctionsException catch (error) {
        lastError = error;
        if (error.code != 'not-found') {
          rethrow;
        }
      }
    }

    if (lastError != null) {
      throw lastError;
    }
    throw FirebaseFunctionsException(
      code: 'unknown',
      message: 'Unknown error initiating call',
    );
  }

  static Future<UserProfile> _buildCurrentAdminProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('กรุณาเข้าสู่ระบบก่อนโทร');
    }

    return UserProfile(
      uid: user.uid,
      displayName: user.email?.trim().isNotEmpty == true
          ? user.email!.trim()
          : 'แอดมิน',
      phoneNumber: user.phoneNumber,
      photoUrl: user.photoURL,
    );
  }

  static Future<UserProfile> _buildPeerProfile({
    required String uid,
    required String fallbackLabel,
    String? fallbackPhone,
    String? sourceApp,
  }) async {
    final collections = switch (sourceApp) {
      'van1' => <String>[
          'market_registrations',
          'shop_registrations',
          'restaurant_registrations',
          'pharmacy_registrations',
          'other_registrations',
        ],
      'van3' => <String>['riders'],
      _ => <String>['customer_users', 'users', 'riders'],
    };

    for (final collection in collections) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(uid)
            .get();
        if (!doc.exists) {
          continue;
        }
        final data = doc.data();
        if (data == null) {
          continue;
        }
        return UserProfile.fromMap(uid, <String, dynamic>{
          ...data,
          if ((data['phoneNumber'] ?? data['phone']) == null &&
              fallbackPhone?.trim().isNotEmpty == true)
            'phoneNumber': fallbackPhone!.trim(),
        });
      } catch (_) {
        // Try next collection.
      }
    }

    return UserProfile(
      uid: uid,
      displayName: fallbackLabel.trim().isEmpty ? 'ผู้ใช้' : fallbackLabel.trim(),
      phoneNumber: fallbackPhone,
    );
  }

  static String _fallbackChannelId(String uidA, String uidB) {
    final sorted = <String>[uidA, uidB]..sort();
    return 'call_${sorted.join('_')}';
  }

  static void _showSnack(BuildContext context, String message) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
