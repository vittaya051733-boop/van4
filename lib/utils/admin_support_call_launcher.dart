import 'package:flutter/material.dart';

import '../models/admin_peer_profile.dart';
import '../services/admin_call_service.dart';
import '../admin_voice_call_screen.dart';

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
      peer: AdminPeerProfile(
        uid: requesterUid,
        displayName: requesterName,
        email: null,
        photoUrl: null,
      ),
      phoneNumber: requesterPhone,
      sourceApp: sourceApp,
    );
  }

  static Future<void> startVoiceCallToPeer({
    required BuildContext context,
    required AdminPeerProfile peer,
    String? phoneNumber,
    String? sourceApp,
  }) async {
    final trimmedPeerUid = peer.uid.trim();
    if (trimmedPeerUid.isEmpty) {
      _showSnack(context, 'ไม่พบบัญชีปลายทางสำหรับเริ่มการโทร');
      return;
    }

    try {
      final caller = await AdminCallService.currentAdminProfile();
      if (!context.mounted) return;
      if (caller.uid == trimmedPeerUid) {
        _showSnack(context, 'ไม่สามารถเริ่มการโทรหาบัญชีตัวเองได้');
        return;
      }

      final callee = AdminPeerProfile(
        uid: trimmedPeerUid,
        displayName: peer.displayName,
        email: peer.email,
        photoUrl: peer.photoUrl,
      );

      final callData = await AdminCallService.initiateVoiceCall(
        caller: caller,
        callee: callee,
      );

      if (!context.mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AdminVoiceCallScreen(
            channelId: (callData['channelId'] as String?) ?? '',
            token: (callData['token'] as String?) ?? '',
            appId: (callData['appId'] as String?) ?? '',
            peer: callee,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      _showSnack(context, 'เริ่มการโทรในแอปไม่สำเร็จ: $error');
    }
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
