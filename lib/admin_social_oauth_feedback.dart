import 'package:flutter/material.dart';

/// Shows snackbar after OAuth redirect (?social_oauth=success|error).
void showSocialOAuthReturnFeedback(BuildContext context) {
  final params = Uri.base.queryParameters;
  final result = params['social_oauth'];
  if (result == null || result.isEmpty) {
    return;
  }

  final platform = params['platform'] ?? '';
  final reason = params['reason'] ?? '';

  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }

  if (result == 'success') {
    messenger.showSnackBar(
      SnackBar(content: Text('เชื่อมบัญชี $platform สำเร็จ')),
    );
  } else {
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          reason.isNotEmpty
              ? 'เชื่อมบัญชีไม่สำเร็จ: $reason'
              : 'เชื่อมบัญชีไม่สำเร็จ',
        ),
      ),
    );
  }
}
