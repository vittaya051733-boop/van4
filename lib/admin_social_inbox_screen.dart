import 'package:flutter/material.dart';

import 'models/social_models.dart';
import 'services/admin_social_service.dart';

class AdminSocialInboxScreen extends StatefulWidget {
  const AdminSocialInboxScreen({super.key});

  @override
  State<AdminSocialInboxScreen> createState() => _AdminSocialInboxScreenState();
}

class _AdminSocialInboxScreenState extends State<AdminSocialInboxScreen> {
  String _filter = 'open';

  Future<void> _reply(SocialCommentRecord comment) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ตอบคอมเมนต์'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'ข้อความตอบกลับ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('ส่ง'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (confirmed == null || confirmed.isEmpty) {
      return;
    }

    try {
      await AdminSocialService.instance.replyComment(
        commentId: comment.id,
        message: confirmed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ตอบคอมเมนต์แล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ตอบไม่สำเร็จ: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('กล่องคอมเมนต์รวม'),
      ),
      body: Column(
        children: <Widget>[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: <Widget>[
                ChoiceChip(
                  label: const Text('รอตอบ'),
                  selected: _filter == 'open',
                  onSelected: (_) => setState(() => _filter = 'open'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('ตอบแล้ว'),
                  selected: _filter == 'replied',
                  onSelected: (_) => setState(() => _filter = 'replied'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('ทั้งหมด'),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<SocialCommentRecord>>(
              stream: AdminSocialService.instance.streamComments(
                replyStatus: _filter == 'all' ? null : _filter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snapshot.data ?? const <SocialCommentRecord>[];
                if (comments.isEmpty) {
                  return const Center(
                    child: Text('ยังไม่มีคอมเมนต์ — sync ทุก 10 นาที + webhook Meta'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: comments.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Card(
                      child: ListTile(
                        isThreeLine: true,
                        leading: CircleAvatar(
                          backgroundImage: comment.authorAvatarUrl != null &&
                                  comment.authorAvatarUrl!.isNotEmpty
                              ? NetworkImage(comment.authorAvatarUrl!)
                              : null,
                          child: comment.authorAvatarUrl == null ||
                                  comment.authorAvatarUrl!.isEmpty
                              ? const Icon(Icons.person_outline)
                              : null,
                        ),
                        title: Text(comment.authorName ?? 'ผู้ใช้'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              SocialPlatformTarget.label(comment.platform),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(comment.text),
                            if (comment.ourReply != null &&
                                comment.ourReply!.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 6),
                              Text(
                                'ตอบ: ${comment.ourReply}',
                                style: const TextStyle(
                                  color: Color(0xFF9A3412),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: comment.replyStatus == 'open'
                            ? IconButton(
                                tooltip: 'ตอบ',
                                onPressed: () => _reply(comment),
                                icon: const Icon(Icons.reply_outlined),
                              )
                            : const Icon(Icons.check, color: Colors.green),
                      ),
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
