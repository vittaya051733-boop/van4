import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'admin_internal_chat_repository.dart';
import 'models/admin_peer_profile.dart';
import 'services/admin_call_service.dart';
import 'admin_voice_call_screen.dart';

class AdminInternalThreadScreen extends StatefulWidget {
  const AdminInternalThreadScreen({
    super.key,
    required this.threadId,
    required this.title,
    this.peer,
    this.isTeam = false,
  });

  final String threadId;
  final String title;
  final AdminPeerProfile? peer;
  final bool isTeam;

  @override
  State<AdminInternalThreadScreen> createState() =>
      _AdminInternalThreadScreenState();
}

class _AdminInternalThreadScreenState extends State<AdminInternalThreadScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final List<File> _pendingImages = <File>[];
  final List<PlatformFile> _pendingFiles = <PlatformFile>[];
  bool _sending = false;
  bool _calling = false;

  @override
  void initState() {
    super.initState();
    AdminInternalChatRepository.markThreadRead(widget.threadId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = AdminInternalChatRepository.maxImages - _pendingImages.length;
    if (remaining <= 0) {
      _snack('แนบรูปได้สูงสุด ${AdminInternalChatRepository.maxImages} รูป');
      return;
    }
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty) return;
    setState(() {
      _pendingImages.addAll(
        picked.take(remaining).map((item) => File(item.path)),
      );
    });
  }

  Future<void> _pickFiles() async {
    final remaining = AdminInternalChatRepository.maxFiles - _pendingFiles.length;
    if (remaining <= 0) {
      _snack('แนบไฟล์ได้สูงสุด ${AdminInternalChatRepository.maxFiles} ไฟล์');
      return;
    }
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _pendingFiles.addAll(result.files.take(remaining));
    });
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    try {
      await AdminInternalChatRepository.sendMessage(
        threadId: widget.threadId,
        message: _messageController.text,
        imageLocalPaths: _pendingImages.map((file) => file.path).toList(growable: false),
        fileLocalItems: _pendingFiles
            .where((file) => file.path != null)
            .map(
              (file) => (
                path: file.path!,
                name: file.name,
                mimeType: file.extension,
              ),
            )
            .toList(growable: false),
      );
      _messageController.clear();
      setState(() {
        _pendingImages.clear();
        _pendingFiles.clear();
      });
      await AdminInternalChatRepository.markThreadRead(widget.threadId);
      if (_scrollController.hasClients) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (error) {
      _snack('ส่งไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _startVoiceCall() async {
    final peer = widget.peer;
    if (peer == null || widget.isTeam) {
      _snack('โทรได้เฉพาะแชทส่วนตัวกับแอดมิน');
      return;
    }
    setState(() => _calling = true);
    try {
      final caller = await AdminCallService.currentAdminProfile();
      final callData = await AdminCallService.initiateVoiceCall(
        caller: caller,
        callee: peer,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AdminVoiceCallScreen(
            channelId: (callData['channelId'] as String?) ?? '',
            token: (callData['token'] as String?) ?? '',
            appId: (callData['appId'] as String?) ?? '',
            peer: peer,
          ),
        ),
      );
    } catch (error) {
      _snack('เริ่มการโทรไม่สำเร็จ: $error');
    } finally {
      if (mounted) setState(() => _calling = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: <Widget>[
          if (!widget.isTeam && widget.peer != null)
            IconButton(
              tooltip: 'โทรแอดมิน (Agora)',
              onPressed: _calling ? null : _startVoiceCall,
              icon: _calling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.phone_in_talk_outlined),
            ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<List<AdminInternalMessage>>(
              stream: AdminInternalChatRepository.streamMessages(widget.threadId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? const <AdminInternalMessage>[];
                if (messages.isEmpty) {
                  return const Center(
                    child: Text(
                      'เริ่มแชทได้เลย — ส่งข้อความ รูป หรือไฟล์',
                      style: TextStyle(color: Colors.black54),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _MessageBubble(message: messages[index]);
                  },
                );
              },
            ),
          ),
          if (_pendingImages.isNotEmpty || _pendingFiles.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: <Widget>[
                  ..._pendingImages.map(
                    (file) => Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                      child: Stack(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(file, width: 56, height: 56, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () => setState(() => _pendingImages.remove(file)),
                              child: const CircleAvatar(
                                radius: 10,
                                backgroundColor: Colors.black54,
                                child: Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ..._pendingFiles.map(
                    (file) => Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                      child: Chip(
                        label: Text(file.name, overflow: TextOverflow.ellipsis),
                        onDeleted: () => setState(() => _pendingFiles.remove(file)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'แนบรูป',
                    onPressed: _sending ? null : _pickImages,
                    icon: const Icon(Icons.image_outlined),
                  ),
                  IconButton(
                    tooltip: 'แนบไฟล์',
                    onPressed: _sending ? null : _pickFiles,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AdminInternalMessage message;

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final isMine = message.senderUid == currentUid;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFFFE0B2) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (!isMine)
              Text(
                message.senderName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            if (message.message.isNotEmpty)
              Text(message.message, style: const TextStyle(height: 1.35)),
            if (message.imageUrls.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: message.imageUrls
                    .map(
                      (url) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(url, width: 120, height: 120, fit: BoxFit.cover),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            if (message.attachments.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              ...message.attachments.map(
                (attachment) => TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(attachment.url);
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  icon: const Icon(Icons.insert_drive_file_outlined, size: 18),
                  label: Text(attachment.name, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
