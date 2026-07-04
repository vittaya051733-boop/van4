import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_image_widgets.dart';
import 'admin_repository.dart';
import 'utils/admin_support_call_launcher.dart';

class AdminSupportInboxScreen extends StatefulWidget {
  const AdminSupportInboxScreen({super.key});

  @override
  State<AdminSupportInboxScreen> createState() => _AdminSupportInboxScreenState();
}

class _AdminSupportInboxScreenState extends State<AdminSupportInboxScreen> {
  String? _sourceFilter;

  static const List<_SourceFilterOption> _filters = <_SourceFilterOption>[
    _SourceFilterOption(label: 'ทั้งหมด', sourceApp: null),
    _SourceFilterOption(label: 'ลูกค้า', sourceApp: 'van2'),
    _SourceFilterOption(label: 'ร้านค้า', sourceApp: 'van1'),
    _SourceFilterOption(label: 'ไรเดอร์', sourceApp: 'van3'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('ข้อความติดต่อแอดมิน'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: _filters.map((filter) {
                final selected = _sourceFilter == filter.sourceApp;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _sourceFilter = filter.sourceApp);
                    },
                  ),
                );
              }).toList(growable: false),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AdminSupportTicket>>(
              stream: AdminRepositorySupport.streamSupportTickets(
                sourceApp: _sourceFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('โหลดไม่สำเร็จ\n${snapshot.error}'),
                    ),
                  );
                }

                final tickets = snapshot.data ?? const <AdminSupportTicket>[];
                if (tickets.isEmpty) {
                  return const Center(
                    child: Text(
                      'ยังไม่มีข้อความติดต่อ',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: tickets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final ticket = tickets[index];
                    return AdminSupportTicketTile(
                      ticket: ticket,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => AdminSupportTicketDetailScreen(
                              ticket: ticket,
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSupportTicketDetailScreen extends StatefulWidget {
  const AdminSupportTicketDetailScreen({
    super.key,
    required this.ticket,
  });

  final AdminSupportTicket ticket;

  @override
  State<AdminSupportTicketDetailScreen> createState() =>
      _AdminSupportTicketDetailScreenState();
}

class _AdminSupportTicketDetailScreenState
    extends State<AdminSupportTicketDetailScreen> {
  late String _status;
  late bool _contactClosed;
  bool _updating = false;
  bool _closing = false;
  bool _sending = false;
  final _replyController = TextEditingController();
  final _picker = ImagePicker();
  final _scrollController = ScrollController();
  final List<File> _pendingImages = <File>[];

  @override
  void initState() {
    super.initState();
    _status = widget.ticket.status;
    _contactClosed = widget.ticket.isContactClosed;
    AdminRepositorySupport.markReadAsAdmin(widget.ticket.id);
  }

  @override
  void dispose() {
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _setStatus(String status) async {
    setState(() => _updating = true);
    try {
      await AdminRepositorySupport.updateSupportTicketStatus(
        ticketId: widget.ticket.id,
        status: status,
      );
      if (!mounted) {
        return;
      }
      setState(() => _status = status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('อัปเดตสถานะเป็น ${_statusLabel(status)}')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อัปเดตไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _updating = false);
      }
    }
  }

  Future<void> _pickImages() async {
    final remaining = 4 - _pendingImages.length;
    if (remaining <= 0) {
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) {
      return;
    }
    setState(() {
      _pendingImages.addAll(
        picked.take(remaining).map((file) => File(file.path)),
      );
    });
  }

  Future<void> _closeTicket() async {
    if (_contactClosed) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ปิดเรื่องและเก็บข้อมูล?'),
        content: const Text(
          'จะปิดการสนทนาและโทรติดต่อ แล้วเก็บคำถาม-คำตอบไว้ในคลังซัพพอร์ตสำหรับแชทบอทในอนาคต',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF6B7280),
            ),
            child: const Text('ปิดเรื่อง'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _closing = true);
    try {
      await AdminRepositorySupport.closeSupportTicket(ticket: widget.ticket);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'closed';
        _contactClosed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ปิดเรื่องแล้ว — เก็บข้อมูลไว้ในคลังซัพพอร์ต'),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปิดเรื่องไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _closing = false);
      }
    }
  }

  Future<void> _sendReply() async {
    if (_contactClosed) {
      return;
    }
    setState(() => _sending = true);
    try {
      final imageUrls = await AdminRepositorySupport.uploadSupportReplyImages(
        requesterUid: widget.ticket.requesterUid,
        ticketId: widget.ticket.id,
        localPaths: _pendingImages.map((file) => file.path).toList(growable: false),
      );
      await AdminRepositorySupport.replyToSupportTicket(
        ticket: widget.ticket,
        message: _replyController.text,
        imageUrls: imageUrls,
      );
      _replyController.clear();
      setState(() {
        _pendingImages.clear();
        if (_status == 'open') {
          _status = 'in_progress';
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ส่งคำตอบแล้ว — ผู้ใช้จะเห็นในแจ้งเตือน')),
        );
      }
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

  Future<void> _callRequester() async {
    if (_contactClosed) {
      return;
    }
    await AdminSupportCallLauncher.startVoiceCallToRequester(
      context: context,
      requesterUid: widget.ticket.requesterUid,
      requesterName: widget.ticket.requesterName,
      requesterPhone: widget.ticket.requesterPhone,
      sourceApp: widget.ticket.sourceApp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('ตอบกลับผู้ใช้'),
        actions: <Widget>[
          if (!_contactClosed)
            IconButton(
              tooltip: 'โทรผู้ใช้ (ในแอป)',
              onPressed: _callRequester,
              icon: const Icon(Icons.phone_in_talk_outlined),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _InfoCard(
                  children: <Widget>[
                    _BadgeRow(
                      sourceLabel: ticket.sourceLabel,
                      sourceApp: ticket.sourceApp,
                      status: _status,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      ticket.topicLabel,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'จาก: ${ticket.requesterName}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (ticket.requesterEmail != null &&
                        ticket.requesterEmail!.isNotEmpty)
                      Text(
                        ticket.requesterEmail!,
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                    if (ticket.requesterPhone != null &&
                        ticket.requesterPhone!.isNotEmpty)
                      Text(
                        'โทร: ${ticket.requesterPhone}',
                        style: const TextStyle(color: Color(0xFF6B7280)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _AdminMessageBubble(
                  isAdmin: false,
                  senderName: ticket.requesterName,
                  message: ticket.message,
                  imageUrls: ticket.imageUrls,
                ),
                StreamBuilder<List<AdminSupportMessage>>(
                  stream: AdminRepositorySupport.streamSupportMessages(ticket.id),
                  builder: (context, snapshot) {
                    final messages =
                        snapshot.data ?? const <AdminSupportMessage>[];
                    return Column(
                      children: messages
                          .map(
                            (item) => Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: _AdminMessageBubble(
                                isAdmin: item.isAdmin,
                                senderName: item.isAdmin ? 'แอดมิน' : item.senderName,
                                message: item.message,
                                imageUrls: item.imageUrls,
                              ),
                            ),
                          )
                          .toList(growable: false),
                    );
                  },
                ),
                const SizedBox(height: 16),
                if (_contactClosed)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: const Text(
                      'เรื่องนี้ปิดแล้ว — ดูประวัติได้อย่างเดียว (ข้อมูลถูกเก็บในคลังซัพพอร์ตแล้ว)',
                      style: TextStyle(
                        color: Color(0xFF4B5563),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  )
                else ...<Widget>[
                  Text(
                    'อัปเดตสถานะ',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <String>['open', 'in_progress', 'resolved']
                        .map(
                          (status) => ChoiceChip(
                            label: Text(_statusLabel(status)),
                            selected: _status == status,
                            onSelected: _updating || _closing
                                ? null
                                : (_) => _setStatus(status),
                          ),
                        )
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _closing || _updating ? null : _closeTicket,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6B7280),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _closing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.archive_outlined),
                      label: Text(
                        _closing ? 'กำลังปิดเรื่อง...' : 'ปิดเรื่องและเก็บข้อมูล',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!_contactClosed)
            _AdminReplyComposer(
              controller: _replyController,
              pendingImages: _pendingImages,
              sending: _sending,
              onPickImages: _pickImages,
              onRemoveImage: (index) => setState(() => _pendingImages.removeAt(index)),
              onSend: _sendReply,
            ),
        ],
      ),
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({
    required this.isAdmin,
    required this.senderName,
    required this.message,
    required this.imageUrls,
  });

  final bool isAdmin;
  final String senderName;
  final String message;
  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    final bg = isAdmin ? const Color(0xFFFFF3E0) : const Color(0xFFF1F5F9);
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              senderName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 4),
            Text(message, style: const TextStyle(height: 1.4)),
            if (imageUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: imageUrls
                    .map(
                      (url) => AdminSafeNetworkImage(
                        url: url,
                        width: 88,
                        height: 88,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AdminReplyComposer extends StatelessWidget {
  const _AdminReplyComposer({
    required this.controller,
    required this.pendingImages,
    required this.sending,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onSend,
  });

  final TextEditingController controller;
  final List<File> pendingImages;
  final bool sending;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (pendingImages.isNotEmpty)
                SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pendingImages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              pendingImages[index],
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: IconButton.filledTonal(
                              visualDensity: VisualDensity.compact,
                              iconSize: 16,
                              onPressed: sending ? null : () => onRemoveImage(index),
                              icon: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              Row(
                children: <Widget>[
                  IconButton(
                    onPressed: sending ? null : onPickImages,
                    icon: const Icon(Icons.photo_library_outlined),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !sending,
                      maxLines: 4,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'พิมพ์คำตอบถึงผู้ใช้...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: sending ? null : onSend,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                    ),
                    child: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminSupportTicketTile extends StatelessWidget {
  const AdminSupportTicketTile({
    super.key,
    required this.ticket,
    required this.onTap,
  });

  final AdminSupportTicket ticket;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (ticket.inboxPreviewImageUrls.isNotEmpty) ...<Widget>[
                AdminWorkInboxThumbnail(imageUrls: ticket.inboxPreviewImageUrls),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _BadgeRow(
                      sourceLabel: ticket.sourceLabel,
                      sourceApp: ticket.sourceApp,
                      status: ticket.status,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      ticket.topicLabel,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.requesterName,
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ticket.lastMessagePreview?.trim().isNotEmpty == true
                          ? ticket.lastMessagePreview!.trim()
                          : ticket.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.35),
                    ),
                    if (ticket.unreadForAdmin)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'มีข้อความใหม่',
                            style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeRow extends StatelessWidget {
  const _BadgeRow({
    required this.sourceLabel,
    required this.sourceApp,
    required this.status,
  });

  final String sourceLabel;
  final String sourceApp;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: <Widget>[
        _ChipBadge(
          label: sourceLabel,
          color: _sourceColor(sourceApp),
        ),
        _ChipBadge(
          label: _statusLabel(status),
          color: _statusColor(status),
        ),
      ],
    );
  }
}

class _ChipBadge extends StatelessWidget {
  const _ChipBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SourceFilterOption {
  const _SourceFilterOption({
    required this.label,
    required this.sourceApp,
  });

  final String label;
  final String? sourceApp;
}

Color _sourceColor(String sourceApp) {
  return switch (sourceApp) {
    'van1' => const Color(0xFF2563EB),
    'van2' => const Color(0xFFEA580C),
    'van3' => const Color(0xFF059669),
    _ => const Color(0xFF6B7280),
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'open' => const Color(0xFFDC2626),
    'in_progress' => const Color(0xFFD97706),
    'resolved' => const Color(0xFF059669),
    'closed' => const Color(0xFF6B7280),
    _ => const Color(0xFF6B7280),
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'open' => 'รอดำเนินการ',
    'in_progress' => 'กำลังติดตาม',
    'resolved' => 'แก้ไขแล้ว',
    'closed' => 'ปิดเรื่อง',
    _ => status,
  };
}
