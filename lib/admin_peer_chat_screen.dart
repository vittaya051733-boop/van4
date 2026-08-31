import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_image_widgets.dart';
import 'models/admin_peer_chat_message.dart';
import 'models/admin_peer_profile.dart';
import 'services/admin_peer_chat_service.dart';
import 'utils/admin_support_call_launcher.dart';

class AdminPeerChatScreen extends StatefulWidget {
  const AdminPeerChatScreen({
    super.key,
    required this.peer,
    this.orderId,
    this.orderCode,
    this.contextLabel,
    this.phoneNumber,
    this.sourceApp,
  });

  final AdminPeerProfile peer;
  final String? orderId;
  final String? orderCode;
  final String? contextLabel;
  final String? phoneNumber;
  final String? sourceApp;

  @override
  State<AdminPeerChatScreen> createState() => _AdminPeerChatScreenState();
}

class _AdminPeerChatScreenState extends State<AdminPeerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  AdminPeerProfile? _adminProfile;
  String? _chatId;
  bool _sending = false;
  bool _calling = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final admin = await AdminPeerChatService.currentAdminProfile();
      AdminPeerChatService.assertDistinctPeers(admin, widget.peer);
      final chatId = await AdminPeerChatService.prepareChatRoom(
        admin: admin,
        peer: widget.peer,
        orderId: widget.orderId,
        orderCode: widget.orderCode,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _adminProfile = admin;
        _chatId = chatId;
      });
    } catch (error) {
      if (mounted) {
        _snack('เปิดแชทไม่สำเร็จ: $error');
      }
    }
  }

  Future<void> _sendText() async {
    final admin = _adminProfile;
    if (admin == null || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      await AdminPeerChatService.sendText(
        sender: admin,
        target: widget.peer,
        text: _messageController.text,
        orderId: widget.orderId,
        orderCode: widget.orderCode,
      );
      _messageController.clear();
      await _scrollToBottom();
    } catch (error) {
      _snack('ส่งไม่สำเร็จ: $error');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    final admin = _adminProfile;
    if (admin == null || _sending) {
      return;
    }
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) {
      return;
    }
    setState(() => _sending = true);
    try {
      await AdminPeerChatService.sendImage(
        sender: admin,
        target: widget.peer,
        file: File(picked.path),
        orderId: widget.orderId,
        orderCode: widget.orderCode,
      );
      await _scrollToBottom();
    } catch (error) {
      _snack('ส่งรูปไม่สำเร็จ: $error');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _startCall() async {
    setState(() => _calling = true);
    try {
      await AdminSupportCallLauncher.startVoiceCallToPeer(
        context: context,
        peer: widget.peer,
        phoneNumber: widget.phoneNumber,
        sourceApp: widget.sourceApp,
      );
    } finally {
      if (mounted) {
        setState(() => _calling = false);
      }
    }
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final adminUid = _adminProfile?.uid ?? FirebaseAuth.instance.currentUser?.uid ?? '';
    final subtitle = widget.contextLabel?.trim();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.peer.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'โทร',
            onPressed: _calling ? null : _startCall,
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
            child: _chatId == null
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<List<AdminPeerChatMessage>>(
                    stream: AdminPeerChatService.streamMessages(_chatId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final messages =
                          snapshot.data ?? const <AdminPeerChatMessage>[];
                      if (messages.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'เริ่มแชทกับร้านได้เลย\nร้านจะเห็นในแอป van1 (หน้าแชท)',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (_scrollController.hasClients) {
                          _scrollController.jumpTo(
                            _scrollController.position.maxScrollExtent,
                          );
                        }
                      });
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMine = message.senderId == adminUid;
                          return Align(
                            alignment:
                                isMine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                              ),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isMine
                                    ? const Color(0xFFFFF3E0)
                                    : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _MessageBody(message: message),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'ส่งรูป',
                    onPressed: _sending ? null : _pickAndSendImage,
                    icon: const Icon(Icons.image_outlined),
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
                      onSubmitted: _sending ? null : (_) => _sendText(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _sendText,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      minimumSize: const Size(48, 48),
                      padding: EdgeInsets.zero,
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
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

class _MessageBody extends StatelessWidget {
  const _MessageBody({required this.message});

  final AdminPeerChatMessage message;

  @override
  Widget build(BuildContext context) {
    if (message.type == 'image' &&
        message.mediaUrl != null &&
        message.mediaUrl!.trim().isNotEmpty) {
      return AdminSafeAvatar(
        imageUrl: message.mediaUrl,
        size: 180,
        borderRadius: 10,
      );
    }
    return Text(message.text ?? '');
  }
}
