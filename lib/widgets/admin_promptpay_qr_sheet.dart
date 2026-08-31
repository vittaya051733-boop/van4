import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/promptpay_qr_payload.dart';

Future<void> showAdminPromptPayQrSheet(
  BuildContext context, {
  required String promptPayId,
  required double amount,
  String? actorLabel,
}) async {
  if (!PromptPayQrPayload.isValidId(promptPayId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('เลข PromptPay ไม่ถูกต้อง — ตรวจสอบโปรไฟล์ผู้ขอถอน'),
      ),
    );
    return;
  }

  final payload = PromptPayQrPayload.build(
    promptPayId: promptPayId,
    amount: amount,
  );
  if (payload == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('สร้าง QR PromptPay ไม่สำเร็จ')),
    );
    return;
  }

  final displayLabel = PromptPayQrPayload.formatDisplayLabel(promptPayId);
  final copyDigits = PromptPayQrPayload.copyableDigits(promptPayId);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'QR PromptPay',
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              if (actorLabel != null && actorLabel.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  actorLabel,
                  style: const TextStyle(color: Color(0xFF64748B)),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                '${amount.toStringAsFixed(2)} บาท',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Flexible(
                    child: Text(
                      displayLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    tooltip: 'คัดลอกเลข PromptPay',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: copyDigits));
                      if (sheetContext.mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(content: Text('คัดลอกเลข PromptPay แล้ว')),
                        );
                      }
                    },
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: QrImageView(
                  data: payload,
                  size: 260,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'สแกนด้วยแอปธนาคารเพื่อโอนให้ผู้ขอถอน',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('ปิด'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
