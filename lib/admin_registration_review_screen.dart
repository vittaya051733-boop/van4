import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_image_widgets.dart';
import 'admin_repository.dart';
import 'models/admin_document_review.dart';

Future<void> showAdminShopDocumentReview(
  BuildContext context, {
  required AdminShopRecord shop,
  VoidCallback? onChanged,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AdminShopDocumentReviewScreen(
        shop: shop,
        onChanged: onChanged,
      ),
    ),
  );
}

Future<void> showAdminRiderDocumentReview(
  BuildContext context, {
  required AdminRiderRecord rider,
  VoidCallback? onChanged,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AdminRiderDocumentReviewScreen(
        rider: rider,
        onChanged: onChanged,
      ),
    ),
  );
}

class AdminShopDocumentReviewScreen extends StatefulWidget {
  const AdminShopDocumentReviewScreen({
    super.key,
    required this.shop,
    this.onChanged,
  });

  final AdminShopRecord shop;
  final VoidCallback? onChanged;

  @override
  State<AdminShopDocumentReviewScreen> createState() =>
      _AdminShopDocumentReviewScreenState();
}

class _AdminShopDocumentReviewScreenState extends State<AdminShopDocumentReviewScreen> {
  var _loading = true;
  Map<String, dynamic> _registration = const <String, dynamic>{};
  Map<String, dynamic> _contract = const <String, dynamic>{};
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bundle = await AdminRepository.fetchShopRegistrationBundle(shop: widget.shop);
      if (!mounted) {
        return;
      }
      setState(() {
        _registration = Map<String, dynamic>.from(bundle['registration'] as Map? ?? const {});
        _contract = Map<String, dynamic>.from(bundle['contract'] as Map? ?? const {});
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดเอกสารไม่สำเร็จ: $error')),
        );
      }
    }
  }

  String? _readUrl(AdminDocumentFieldDef field) {
    final source = field.collection == 'contract' ? _contract : _registration;
    return source[field.imageUrlKey]?.toString().trim();
  }

  Future<void> _requestResubmit() async {
    final result = await showDocumentResubmitDialog(
      context,
      fields: AdminShopDocumentFields.all,
    );
    if (result == null) {
      return;
    }
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AdminRepository.requestShopDocumentResubmit(
        shop: widget.shop,
        adminUid: adminUid,
        fieldKeys: result.fieldKeys,
        reason: result.reason,
      );
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('แจ้งร้านให้ส่งเอกสารใหม่แล้ว')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewStatus = _registration['documentReviewStatus']?.toString();
    final resubmitReason = _registration['documentResubmitReason']?.toString();

    return Scaffold(
      appBar: AppBar(title: Text('ตรวจเอกสาร — ${widget.shop.displayName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (reviewStatus != null && reviewStatus.isNotEmpty)
                  Card(
                    color: const Color(0xFFFFF7ED),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline, color: Color(0xFFE65100)),
                      title: Text(documentReviewStatusLabelTh(reviewStatus)),
                      subtitle: resubmitReason?.isNotEmpty == true
                          ? Text(resubmitReason!)
                          : null,
                    ),
                  ),
                const SizedBox(height: 8),
                ...AdminShopDocumentFields.all.map(
                  (field) => _DocumentPreviewTile(
                    label: field.labelTh,
                    url: _readUrl(field),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _busy ? null : _requestResubmit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.replay_outlined),
            label: const Text('ขอส่งเอกสารใหม่'),
          ),
        ),
      ),
    );
  }
}

class AdminRiderDocumentReviewScreen extends StatefulWidget {
  const AdminRiderDocumentReviewScreen({
    super.key,
    required this.rider,
    this.onChanged,
  });

  final AdminRiderRecord rider;
  final VoidCallback? onChanged;

  @override
  State<AdminRiderDocumentReviewScreen> createState() =>
      _AdminRiderDocumentReviewScreenState();
}

class _AdminRiderDocumentReviewScreenState extends State<AdminRiderDocumentReviewScreen> {
  var _loading = true;
  Map<String, dynamic> _data = const <String, dynamic>{};
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final bundle = await AdminRepository.fetchRiderRegistrationBundle(widget.rider.id);
      if (!mounted) {
        return;
      }
      final registration =
          Map<String, dynamic>.from(bundle['registration'] as Map? ?? const {});
      final rider = Map<String, dynamic>.from(bundle['rider'] as Map? ?? const {});
      setState(() {
        _data = <String, dynamic>{...rider, ...registration};
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โหลดเอกสารไม่สำเร็จ: $error')),
        );
      }
    }
  }

  Future<void> _requestResubmit() async {
    final result = await showDocumentResubmitDialog(
      context,
      fields: AdminRiderDocumentFields.all,
    );
    if (result == null) {
      return;
    }
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AdminRepository.requestRiderDocumentResubmit(
        riderId: widget.rider.id,
        adminUid: adminUid,
        fieldKeys: result.fieldKeys,
        reason: result.reason,
      );
      widget.onChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('แจ้งไรเดอร์ให้ส่งเอกสารใหม่แล้ว')),
        );
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewStatus = _data['documentReviewStatus']?.toString();
    final resubmitReason = _data['documentResubmitReason']?.toString();

    return Scaffold(
      appBar: AppBar(title: Text('ตรวจเอกสาร — ${widget.rider.displayName}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (reviewStatus != null && reviewStatus.isNotEmpty)
                  Card(
                    color: const Color(0xFFFFF7ED),
                    child: ListTile(
                      leading: const Icon(Icons.info_outline, color: Color(0xFFE65100)),
                      title: Text(documentReviewStatusLabelTh(reviewStatus)),
                      subtitle: resubmitReason?.isNotEmpty == true
                          ? Text(resubmitReason!)
                          : null,
                    ),
                  ),
                const SizedBox(height: 8),
                ...AdminRiderDocumentFields.all.map(
                  (field) => _DocumentPreviewTile(
                    label: field.labelTh,
                    url: _data[field.imageUrlKey]?.toString().trim(),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _busy ? null : _requestResubmit,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.replay_outlined),
            label: const Text('ขอส่งเอกสารใหม่'),
          ),
        ),
      ),
    );
  }
}

class DocumentResubmitResult {
  const DocumentResubmitResult({
    required this.fieldKeys,
    required this.reason,
  });

  final List<String> fieldKeys;
  final String reason;
}

Future<DocumentResubmitResult?> showDocumentResubmitDialog(
  BuildContext context, {
  required List<AdminDocumentFieldDef> fields,
}) async {
  final selected = <String>{};
  final reasonController = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('ขอส่งเอกสารใหม่'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('เลือกเอกสารที่ต้องส่งใหม่'),
                  const SizedBox(height: 8),
                  ...fields.map(
                    (field) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(field.labelTh),
                      value: selected.contains(field.key),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selected.add(field.key);
                          } else {
                            selected.remove(field.key);
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'เหตุผล (เช่น ภาพไม่ชัด / เอกสารไม่ตรง)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: selected.isEmpty || reasonController.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(dialogContext, true),
                child: const Text('แจ้งให้ส่งใหม่'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true) {
    reasonController.dispose();
    return null;
  }

  final result = DocumentResubmitResult(
    fieldKeys: selected.toList(),
    reason: reasonController.text.trim(),
  );
  reasonController.dispose();
  return result;
}

class _DocumentPreviewTile extends StatelessWidget {
  const _DocumentPreviewTile({
    required this.label,
    this.url,
  });

  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Icon(
                  hasUrl ? Icons.check_circle_outline : Icons.warning_amber_outlined,
                  color: hasUrl ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (hasUrl)
              GestureDetector(
                onTap: () => showAdminImagePreview(context, url!),
                child: AdminSafeNetworkImage(
                  url: url!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: BorderRadius.circular(12),
                ),
              )
            else
              Container(
                width: double.infinity,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('ยังไม่มีไฟล์', style: TextStyle(color: Color(0xFF6B7280))),
              ),
          ],
        ),
      ),
    );
  }
}
