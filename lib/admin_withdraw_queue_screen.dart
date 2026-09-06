import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'admin_settlement_support.dart';
import 'services/promptpay_qr_payload.dart';
import 'utils/guarded_functions.dart';
import 'widgets/admin_promptpay_qr_sheet.dart';
import 'models/admin_work_task.dart';
import 'services/admin_activity_log.dart';
import 'utils/thai_national_id.dart';
import 'widgets/admin_work_claim_bar.dart';

double _readWithdrawAmount(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

double _readWithdrawFee(Map<String, dynamic> data) {
  final fee = data['withdrawFeeBaht'];
  if (fee is num) {
    return fee.toDouble();
  }
  return 0;
}

double _readWithdrawNetPayout(Map<String, dynamic> data) {
  final net = data['netPayout'];
  if (net is num) {
    return net.toDouble();
  }
  return (_readWithdrawAmount(data['amount']) - _readWithdrawFee(data))
      .clamp(0, double.infinity);
}

class AdminWithdrawQueueScreen extends StatefulWidget {
  const AdminWithdrawQueueScreen({super.key});

  @override
  State<AdminWithdrawQueueScreen> createState() =>
      _AdminWithdrawQueueScreenState();
}

class _AdminWithdrawQueueScreenState extends State<AdminWithdrawQueueScreen> {
  int _csvThreshold = 5;
  bool _exportingCsv = false;
  String? _busyRequestId;

  @override
  void initState() {
    super.initState();
    _loadThreshold();
  }

  Future<void> _loadThreshold() async {
    try {
      final rates = await AdminSettlementSupport.fetchSettlementFeeRates();
      if (mounted) {
        setState(() => _csvThreshold = rates.withdrawBankCsvThreshold);
      }
    } catch (_) {
      // Keep default.
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _pendingStream() {
    return FirebaseFirestore.instance
        .collection('withdraw_requests')
        .where('status', isEqualTo: 'pending_admin')
        .snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final sorted = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
    sorted.sort((a, b) {
      final aTs = a.data()['timestamp'];
      final bTs = b.data()['timestamp'];
      if (aTs is Timestamp && bTs is Timestamp) {
        return bTs.compareTo(aTs);
      }
      return 0;
    });
    return sorted;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _bankEligibleDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final destination = doc.data()['payoutDestination'];
      if (destination is! Map) {
        return false;
      }
      final map = Map<String, dynamic>.from(destination);
      return map['accountNumber']?.toString().trim().isNotEmpty == true;
    }).toList();
  }

  Future<void> _exportBankCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> bankDocs,
  ) async {
    if (bankDocs.isEmpty || _exportingCsv) {
      return;
    }
    setState(() => _exportingCsv = true);
    try {
      final result = await GuardedFunctions.call(
        'exportWithdrawBankCsv',
        parameters: <String, dynamic>{
          'requestIds': bankDocs.map((doc) => doc.id).toList(),
        },
      );
      final data = result.data is Map
          ? Map<String, dynamic>.from(result.data as Map)
          : const <String, dynamic>{};
      final csv = data['csv']?.toString() ?? '';
      if (csv.isEmpty) {
        throw StateError('ไม่ได้รับไฟล์ CSV');
      }
      await Share.shareXFiles(
        <XFile>[
          XFile.fromData(
            utf8.encode(csv),
            name: 'withdraw_bank_${DateTime.now().millisecondsSinceEpoch}.csv',
            mimeType: 'text/csv',
          ),
        ],
        subject: 'Withdraw bank CSV',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export ${data['rowCount'] ?? bankDocs.length} รายการแล้ว'),
          ),
        );
      }
    } on FirebaseFunctionsException catch (error) {
      _showSnack(error.message ?? 'Export CSV ไม่สำเร็จ');
    } catch (error) {
      _showSnack('Export CSV ไม่สำเร็จ: $error');
    } finally {
      if (mounted) {
        setState(() => _exportingCsv = false);
      }
    }
  }

  Future<void> _confirmWithSlip(
    String requestId,
    double amount,
    String adminPayoutMethod,
  ) async {
    if (_busyRequestId != null) {
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = picked?.files.single;
    if (file == null) {
      return;
    }

    setState(() => _busyRequestId = requestId);
    try {
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final fileName = file.name.isNotEmpty ? file.name : 'withdraw-slip.jpg';
      final storagePath =
          'admin_withdraw_slips/$requestId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final ref = FirebaseStorage.instance.ref().child(storagePath);
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      await GuardedFunctions.call(
        'confirmManualWithdraw',
        parameters: <String, dynamic>{
          'withdrawRequestId': requestId,
          'adminPayoutMethod': adminPayoutMethod,
          'storagePath': storagePath,
          'fileName': fileName,
          'contentType': 'image/jpeg',
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ยืนยันถอน ${amount.toStringAsFixed(2)} บาทแล้ว')),
        );
      }
      unawaited(
        AdminActivityLog.logFinancial(
          action: 'confirm_withdraw',
          targetType: AdminWorkSourceType.withdraw,
          targetId: requestId,
          labelTh: 'ยืนยันถอนเงิน $requestId',
          detail: <String, Object?>{
            'amount': amount,
            'method': adminPayoutMethod,
          },
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      _showSnack(error.message ?? 'ยืนยันสลิปไม่สำเร็จ');
    } catch (error) {
      _showSnack('ยืนยันสลิปไม่สำเร็จ: $error');
    } finally {
      if (mounted) {
        setState(() => _busyRequestId = null);
      }
    }
  }

  Future<void> _reject(String requestId) async {
    if (_busyRequestId != null) {
      return;
    }
    setState(() => _busyRequestId = requestId);
    try {
      await GuardedFunctions.call(
        'rejectManualWithdraw',
        parameters: <String, dynamic>{'withdrawRequestId': requestId},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ปฏิเสธคำขอแล้ว — คืนยอดให้ผู้ใช้')),
        );
      }
      unawaited(
        AdminActivityLog.logFinancial(
          action: 'reject_withdraw',
          targetType: AdminWorkSourceType.withdraw,
          targetId: requestId,
          labelTh: 'ปฏิเสธถอนเงิน $requestId',
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      _showSnack(error.message ?? 'ปฏิเสธไม่สำเร็จ');
    } catch (error) {
      _showSnack('ปฏิเสธไม่สำเร็จ: $error');
    } finally {
      if (mounted) {
        setState(() => _busyRequestId = null);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('คิวถอนเงิน')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _pendingStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('โหลดคิวไม่สำเร็จ: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = _sortDocs(snapshot.data!.docs);
          final bankDocs = _bankEligibleDocs(docs);

          if (docs.isEmpty) {
            return const Center(child: Text('ไม่มีคำขอรอดำเนินการ'));
          }

          final totalNetPayout = docs.fold<double>(
            0,
            (runningTotal, doc) =>
                runningTotal + _readWithdrawNetPayout(doc.data()),
          );

          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${docs.length} รายการ · รวมโอน ${totalNetPayout.toStringAsFixed(2)} บาท'
                        '${bankDocs.length >= _csvThreshold ? ' · แนะนำ CSV ธนาคาร' : ''}',
                      ),
                    ),
                    if (bankDocs.isNotEmpty)
                      FilledButton.icon(
                        onPressed: _exportingCsv
                            ? null
                            : () => _exportBankCsv(bankDocs),
                        icon: _exportingCsv
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.download_rounded),
                        label: const Text('Export CSV ธนาคาร'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _WithdrawRequestCard(
                      requestId: doc.id,
                      data: data,
                      busy: _busyRequestId == doc.id,
                      onConfirmSlip: (adminPayoutMethod) => _confirmWithSlip(
                        doc.id,
                        _readWithdrawNetPayout(data),
                        adminPayoutMethod,
                      ),
                      onReject: () => _reject(doc.id),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WithdrawRequestCard extends StatefulWidget {
  const _WithdrawRequestCard({
    required this.requestId,
    required this.data,
    required this.busy,
    required this.onConfirmSlip,
    required this.onReject,
  });

  final String requestId;
  final Map<String, dynamic> data;
  final bool busy;
  final void Function(String adminPayoutMethod) onConfirmSlip;
  final VoidCallback onReject;

  @override
  State<_WithdrawRequestCard> createState() => _WithdrawRequestCardState();
}

class _WithdrawRequestCardState extends State<_WithdrawRequestCard> {
  String? _adminPayoutMethod;
  String? _resolvedPromptPayId;
  bool _loadingPromptPay = false;
  bool? _hasVerifiedNationalId;
  bool _loadingKyc = false;

  @override
  void initState() {
    super.initState();
    _resolvePromptPayId();
    _resolveKycStatus();
  }

  @override
  void didUpdateWidget(covariant _WithdrawRequestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _resolvedPromptPayId = null;
      _hasVerifiedNationalId = null;
      _resolvePromptPayId();
      _resolveKycStatus();
    }
  }

  Future<void> _resolveKycStatus() async {
    final uid = widget.data['uid']?.toString().trim() ?? '';
    final actorType = widget.data['actorType']?.toString() ?? '';
    if (uid.isEmpty) {
      return;
    }
    setState(() => _loadingKyc = true);
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;
      if (actorType == 'merchant') {
        doc = await FirebaseFirestore.instance.collection('contracts').doc(uid).get();
      } else {
        doc = await FirebaseFirestore.instance.collection('riders').doc(uid).get();
        if (!doc.exists || normalizeNationalId(doc.data()?['verifiedNationalId']).length != 13) {
          doc = await FirebaseFirestore.instance
              .collection('rider_registrations')
              .doc(uid)
              .get();
        }
      }
      final id = normalizeNationalId(doc.data()?['verifiedNationalId']);
      if (mounted) {
        setState(() {
          _hasVerifiedNationalId =
              id.length == 13 && validateThaiNationalIdChecksum(id);
          _loadingKyc = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasVerifiedNationalId = false;
          _loadingKyc = false;
        });
      }
    }
  }

  Future<void> _resolvePromptPayId() async {
    final destination = widget.data['payoutDestination'] is Map
        ? Map<String, dynamic>.from(widget.data['payoutDestination'] as Map)
        : const <String, dynamic>{};
    final fromSnapshot = destination['promptPayId']?.toString().trim() ?? '';
    if (PromptPayQrPayload.isValidId(fromSnapshot)) {
      if (mounted) {
        setState(() => _resolvedPromptPayId = fromSnapshot);
      }
      return;
    }

    final hasHint = destination['hasPromptPay'] == true ||
        destination['promptPayMasked']?.toString().trim().isNotEmpty == true ||
        fromSnapshot.isNotEmpty;
    if (!hasHint) {
      return;
    }

    final uid = widget.data['uid']?.toString().trim() ?? '';
    final actorType = widget.data['actorType']?.toString() ?? '';
    if (uid.isEmpty) {
      if (fromSnapshot.isNotEmpty && mounted) {
        setState(() => _resolvedPromptPayId = fromSnapshot);
      }
      return;
    }

    setState(() => _loadingPromptPay = true);
    try {
      final profileData = await _loadPayoutProfileData(uid, actorType);
      final resolved = _pickPromptPayId(profileData) ?? fromSnapshot;
      if (mounted) {
        setState(() {
          _resolvedPromptPayId = resolved.isEmpty ? null : resolved;
          _loadingPromptPay = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedPromptPayId = fromSnapshot.isEmpty ? null : fromSnapshot;
          _loadingPromptPay = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _loadPayoutProfileData(
    String uid,
    String actorType,
  ) async {
    if (actorType == 'rider') {
      final doc = await FirebaseFirestore.instance.collection('riders').doc(uid).get();
      return doc.data() ?? const <String, dynamic>{};
    }

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final userData = userDoc.data() ?? const <String, dynamic>{};
    if (_pickPromptPayId(userData) != null) {
      return userData;
    }

    for (final collection in const <String>[
      'shop_registrations',
      'market_registrations',
      'restaurant_registrations',
      'pharmacy_registrations',
      'other_registrations',
    ]) {
      final direct = await FirebaseFirestore.instance.collection(collection).doc(uid).get();
      if (direct.exists) {
        final data = direct.data();
        if (data != null && _pickPromptPayId(data) != null) {
          return data;
        }
      }
      final ownerQuery = await FirebaseFirestore.instance
          .collection(collection)
          .where('ownerId', isEqualTo: uid)
          .limit(1)
          .get();
      if (ownerQuery.docs.isNotEmpty) {
        final data = ownerQuery.docs.first.data();
        if (_pickPromptPayId(data) != null) {
          return data;
        }
      }
    }
    return userData;
  }

  String? _pickPromptPayId(Map<String, dynamic> data) {
    final nationalId = _digitsOnly(
      data['promptPayNationalId'] ??
          data['promptPayNationalIdOrTaxId'] ??
          data['promptPayId'],
    );
    if (nationalId.length == 13) {
      return nationalId;
    }
    final phone = _digitsOnly(data['promptPayPhoneNumber']);
    if (phone.isNotEmpty) {
      return phone;
    }
    return null;
  }

  String _digitsOnly(Object? value) {
    return value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final gross = _readWithdrawAmount(widget.data['amount']);
    final fee = _readWithdrawFee(widget.data);
    final netPayout = _readWithdrawNetPayout(widget.data);
    final actorType = widget.data['actorType']?.toString() ?? '';
    final destination = widget.data['payoutDestination'] is Map
        ? Map<String, dynamic>.from(widget.data['payoutDestination'] as Map)
        : const <String, dynamic>{};

    final hasPromptPay =
        destination['promptPayId']?.toString().trim().isNotEmpty == true ||
        destination['hasPromptPay'] == true ||
        destination['promptPayMasked']?.toString().trim().isNotEmpty == true ||
        (_resolvedPromptPayId?.isNotEmpty == true);
    final hasBank =
        destination['accountNumber']?.toString().trim().isNotEmpty == true;

    final adminMethod = _adminPayoutMethod ??
        (hasPromptPay
            ? 'promptpay'
            : hasBank
                ? 'bank'
                : null);

    final promptPayId =
        (_resolvedPromptPayId ?? destination['promptPayId']?.toString() ?? '')
            .trim();
    final promptPayValid =
        promptPayId.isNotEmpty && PromptPayQrPayload.isValidId(promptPayId);
    final showPromptPayQr =
        (adminMethod == 'promptpay' || (!hasBank && hasPromptPay)) &&
        (promptPayValid || _loadingPromptPay || hasPromptPay);
    final actorLabel =
        actorType == 'merchant' ? 'ร้านค้า' : 'ไรเดอร์';

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              fee > 0
                  ? 'โอน ${netPayout.toStringAsFixed(2)} บาท · ${actorType == 'merchant' ? 'ร้านค้า' : 'ไรเดอร์'}'
                  : '${gross.toStringAsFixed(2)} บาท · ${actorType == 'merchant' ? 'ร้านค้า' : 'ไรเดอร์'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            AdminWorkClaimBar(
              sourceType: AdminWorkSourceType.withdraw,
              sourceId: widget.requestId,
              title: 'ถอน ${netPayout.toStringAsFixed(2)} บาท',
              branchId: widget.data['branchId']?.toString(),
            ),
            if (fee > 0) ...[
              const SizedBox(height: 4),
              Text(
                'หักจากกระเป๋า ${gross.toStringAsFixed(2)} บาท · ค่าบริการ ${fee.toStringAsFixed(0)} บาท',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
            const SizedBox(height: 4),
            Text('UID: ${widget.data['uid']}'),
            if (_loadingKyc)
              const Text(
                'กำลังตรวจ KYC...',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              )
            else if (_hasVerifiedNationalId == false)
              const Text(
                '⚠ ยังไม่ยืนยันเลขบัตร — ใบแจ้งยอด/ compliance อาจไม่ครบ',
                style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w600),
              )
            else if (_hasVerifiedNationalId == true)
              const Text(
                '✓ ยืนยันเลขบัตรแล้ว',
                style: TextStyle(color: Color(0xFF166534), fontWeight: FontWeight.w600),
              ),
            if (hasPromptPay) ...<Widget>[
              if (_loadingPromptPay)
                const Text(
                  'กำลังโหลดเลข PromptPay...',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                )
              else if (promptPayValid)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'PromptPay: ${PromptPayQrPayload.formatDisplayLabel(promptPayId)}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'คัดลอกเลข PromptPay',
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: PromptPayQrPayload.copyableDigits(promptPayId),
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('คัดลอกเลข PromptPay แล้ว'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded, size: 20),
                    ),
                  ],
                )
              else
                Text(
                  'PromptPay: ${destination['promptPayMasked'] ?? '-'} (ไม่พบเลขเต็มในโปรไฟล์)',
                  style: const TextStyle(color: Color(0xFFB45309)),
                ),
            ] else if (!hasBank)
              const Text(
                'ไม่มี PromptPay หรือบัญชีธนาคารในโปรไฟล์',
                style: TextStyle(color: Color(0xFFB45309)),
              ),
            if (hasBank) ...[
              Text('ธนาคาร: ${destination['bankName'] ?? '-'}'),
              Text('เลขบัญชี: ${destination['accountNumber'] ?? '-'}'),
              Text('ชื่อบัญชี: ${destination['accountName'] ?? '-'}'),
            ],
            if (hasPromptPay && hasBank) ...[
              const SizedBox(height: 12),
              const Text(
                'เลือกช่องทางที่โอน',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: <ButtonSegment<String>>[
                  ButtonSegment<String>(
                    value: 'promptpay',
                    label: const Text('PromptPay'),
                    enabled: hasPromptPay,
                  ),
                  ButtonSegment<String>(
                    value: 'bank',
                    label: const Text('ธนาคาร'),
                    enabled: hasBank,
                  ),
                ],
                selected: adminMethod == null ? <String>{} : <String>{adminMethod},
                onSelectionChanged: (selection) {
                  setState(() => _adminPayoutMethod = selection.first);
                },
              ),
            ],
            if (showPromptPayQr) ...<Widget>[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.busy || _loadingPromptPay || !promptPayValid
                      ? null
                      : () => showAdminPromptPayQrSheet(
                            context,
                            promptPayId: promptPayId,
                            amount: netPayout,
                            actorLabel: actorLabel,
                          ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: _loadingPromptPay
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.qr_code_2_rounded),
                  label: Text(
                    _loadingPromptPay
                        ? 'กำลังเตรียม QR PromptPay...'
                        : 'QR PromptPay · ${netPayout.toStringAsFixed(2)} บาท',
                  ),
                ),
              ),
              if (!promptPayValid && !_loadingPromptPay)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'ไม่สามารถสร้าง QR ได้ — ตรวจสอบ PromptPay ในโปรไฟล์ผู้ขอถอน',
                    style: TextStyle(color: Color(0xFFB45309), fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.busy ? null : widget.onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('ปฏิเสธ'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.busy || adminMethod == null
                        ? null
                        : () => widget.onConfirmSlip(adminMethod),
                    icon: widget.busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('ยืนยันสลิป'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
