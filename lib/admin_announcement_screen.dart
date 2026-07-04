import 'package:flutter/material.dart';

import 'admin_announcement_support.dart';

class AdminAnnouncementScreen extends StatefulWidget {
  const AdminAnnouncementScreen({super.key});

  @override
  State<AdminAnnouncementScreen> createState() => _AdminAnnouncementScreenState();
}

class _AdminAnnouncementScreenState extends State<AdminAnnouncementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _targetVan1 = ValueNotifier<bool>(false);
  final _targetVan2 = ValueNotifier<bool>(false);
  final _targetVan3 = ValueNotifier<bool>(false);
  final _sendEmail = ValueNotifier<bool>(false);
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _targetVan1.dispose();
    _targetVan2.dispose();
    _targetVan3.dispose();
    _sendEmail.dispose();
    super.dispose();
  }

  List<String> _selectedTargets() {
    final targets = <String>[];
    if (_targetVan1.value) {
      targets.add('van1');
    }
    if (_targetVan2.value) {
      targets.add('van2');
    }
    if (_targetVan3.value) {
      targets.add('van3');
    }
    return targets;
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final targets = _selectedTargets();
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกอย่างน้อย 1 ฝั่ง')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final labels = targets
            .map((app) => AdminAnnouncementSupport.targetLabels[app] ?? app)
            .join(', ');
        return AlertDialog(
          title: const Text('ยืนยันส่งประกาศ'),
          content: Text(
            'ส่งไปยัง: $labels\n\n'
            'ช่องทาง: แจ้งเตือนในแอป'
            '${_sendEmail.value ? ' + อีเมล' : ''}',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('ส่งประกาศ'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _sending = true);
    try {
      final result = await AdminAnnouncementSupport.publishAnnouncement(
        title: _titleController.text,
        body: _bodyController.text,
        targetApps: targets,
        sendEmail: _sendEmail.value,
      );
      if (!mounted) {
        return;
      }
      _titleController.clear();
      _bodyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.sendEmail
                ? 'ส่งประกาศแล้ว ${result.recipientCount} รายการ (แจ้งเตือนในแอป + กำลังส่งอีเมล)'
                : 'ส่งประกาศแล้ว ${result.recipientCount} รายการ',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ส่งไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ประกาศแจ้งเตือน')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Text(
                  'ส่งประกาศไปยังปุ่มแจ้งเตือนในแอปร้านค้า / ลูกค้า / ไรเดอร์ (เลือกส่งอีเมลเพิ่มได้)',
                  style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
                ),
                const SizedBox(height: 16),
                const Text(
                  'เลือกฝั่งผู้รับ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                _TargetCheckbox(
                  label: 'ร้านค้า (van1)',
                  notifier: _targetVan1,
                ),
                _TargetCheckbox(
                  label: 'ลูกค้า (van2)',
                  notifier: _targetVan2,
                ),
                _TargetCheckbox(
                  label: 'ไรเดอร์ (van3) — อนุมัติแล้วเท่านั้น',
                  notifier: _targetVan3,
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<bool>(
                  valueListenable: _sendEmail,
                  builder: (context, checked, _) {
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: checked,
                      onChanged: (value) => _sendEmail.value = value == true,
                      title: const Text('ส่งอีเมลด้วย'),
                      subtitle: const Text(
                        'ใช้อีเมลที่ลงทะเบียนในระบบ (SMTP เดียวกับ OTP)',
                        style: TextStyle(fontSize: 12),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'หัวข้อประกาศ',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 120,
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'กรุณากรอกหัวข้อ' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียด',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 1000,
                  validator: (value) =>
                      value?.trim().isEmpty == true ? 'กรุณากรอกรายละเอียด' : null,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.campaign_rounded),
                  label: Text(_sending ? 'กำลังส่ง...' : 'ส่งประกาศ'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'ประกาศล่าสุด',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 10),
          StreamBuilder<List<AdminAnnouncementRecord>>(
            stream: AdminAnnouncementSupport.streamAnnouncements(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data ?? const <AdminAnnouncementRecord>[];
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'ยังไม่มีประกาศ',
                    style: TextStyle(color: Color(0xFF6B7280)),
                  ),
                );
              }
              return Column(
                children: items
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _AnnouncementHistoryCard(item: item),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TargetCheckbox extends StatelessWidget {
  const _TargetCheckbox({
    required this.label,
    required this.notifier,
  });

  final String label;
  final ValueNotifier<bool> notifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: notifier,
      builder: (context, checked, _) {
        return CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: checked,
          onChanged: (value) => notifier.value = value == true,
          title: Text(label),
          controlAffinity: ListTileControlAffinity.leading,
        );
      },
    );
  }
}

class _AnnouncementHistoryCard extends StatelessWidget {
  const _AnnouncementHistoryCard({required this.item});

  final AdminAnnouncementRecord item;

  @override
  Widget build(BuildContext context) {
    final targets = item.targetApps
        .map((app) => AdminAnnouncementSupport.targetLabels[app] ?? app)
        .join(', ');
    final timeLabel = item.createdAt == null
        ? ''
        : '${item.createdAt!.day}/${item.createdAt!.month}/${item.createdAt!.year + 543} '
            '${item.createdAt!.hour.toString().padLeft(2, '0')}:'
            '${item.createdAt!.minute.toString().padLeft(2, '0')}';

    final emailLabel = item.sendEmail
        ? ' • อีเมล: ${item.emailDeliveryStatus ?? 'pending'}'
            '${item.emailSentCount != null ? ' (${item.emailSentCount})' : ''}'
        : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            item.body,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '$targets • ${item.recipientCount} รายการ'
            '${timeLabel.isEmpty ? '' : ' • $timeLabel'}'
            '$emailLabel',
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
