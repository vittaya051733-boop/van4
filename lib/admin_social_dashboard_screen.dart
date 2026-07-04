import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'admin_social_accounts_screen.dart';
import 'admin_social_inbox_screen.dart';
import 'admin_social_oauth_feedback.dart';
import 'models/social_models.dart';
import 'services/admin_social_service.dart';

class AdminSocialDashboardScreen extends StatefulWidget {
  const AdminSocialDashboardScreen({super.key});

  @override
  State<AdminSocialDashboardScreen> createState() =>
      _AdminSocialDashboardScreenState();
}

class _AdminSocialDashboardScreenState extends State<AdminSocialDashboardScreen> {
  final _captionController = TextEditingController();
  final _hashtagsController = TextEditingController();
  final Map<String, bool> _selectedTargets = <String, bool>{
    for (final target in SocialPlatformTarget.all) target: true,
  };

  PlatformFile? _videoFile;
  bool _publishing = false;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        showSocialOAuthReturnFeedback(context);
      }
    });
  }

  @override
  void dispose() {
    _captionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    setState(() => _videoFile = result.files.first);
  }

  List<String> _selectedPlatforms() {
    return _selectedTargets.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
  }

  Future<void> _publish() async {
    final caption = _captionController.text.trim();
    if (caption.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาใส่ caption')),
      );
      return;
    }
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเลือกวิดีโอ')),
      );
      return;
    }

    final selected = _selectedPlatforms();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เลือกอย่างน้อย 1 แพลตฟอร์ม')),
      );
      return;
    }

    final bytes = _videoFile!.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อ่านไฟล์วิดีโอไม่สำเร็จ')),
      );
      return;
    }

    setState(() {
      _publishing = true;
      _uploadProgress = null;
    });

    try {
      const uuid = Uuid();
      final postId = uuid.v4();
      final fileName = _videoFile!.name.isNotEmpty
          ? _videoFile!.name
          : '$postId.mp4';

      setState(() => _uploadProgress = 0.2);
      final storagePath = await AdminSocialService.instance.uploadSocialVideo(
        postId: postId,
        bytes: bytes,
        fileName: fileName,
      );

      setState(() => _uploadProgress = 0.6);
      final hashtags = _hashtagsController.text
          .split(RegExp(r'[\s,]+'))
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .map((tag) => tag.startsWith('#') ? tag : '#$tag')
          .toList(growable: false);

      await AdminSocialService.instance.createPost(
        postId: postId,
        caption: caption,
        sourceVideoPath: storagePath,
        selectedPlatforms: selected,
        hashtags: hashtags,
      );

      if (!mounted) {
        return;
      }
      _captionController.clear();
      _hashtagsController.clear();
      setState(() {
        _videoFile = null;
        _uploadProgress = 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กำลังโพสต์ไปทุกแพลตฟอร์มที่เลือก')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('โพสต์ไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _publishing = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _retryPlatform(SocialPostRecord post, String target) async {
    try {
      await AdminSocialService.instance.retryPlatform(
        postId: post.id,
        platformTarget: target,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('กำลังลองใหม่: ${SocialPlatformTarget.label(target)}'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ลองใหม่ไม่สำเร็จ: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFE65100),
          foregroundColor: Colors.white,
          title: const Text('โซเชียลแดชบอร์ด'),
          actions: <Widget>[
            IconButton(
              tooltip: 'บัญชีโซเชียล',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminSocialAccountsScreen(),
                ),
              ),
              icon: const Icon(Icons.link),
            ),
            IconButton(
              tooltip: 'กล่องคอมเมนต์',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminSocialInboxScreen(),
                ),
              ),
              icon: const Icon(Icons.inbox_outlined),
            ),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFFFE0B2),
            tabs: <Widget>[
              Tab(text: 'สร้างโพสต์'),
              Tab(text: 'ประวัติโพสต์'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _buildComposerTab(),
            _buildHistoryTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const Text(
          'อัปโหลดวิดีโอครั้งเดียว แล้วโพสต์พร้อมกันหลายแพลตฟอร์ม\n'
          'แนะนำ: MP4 9:16, ≤60 วินาที, ≤500MB',
          style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _publishing ? null : _pickVideo,
          icon: const Icon(Icons.video_library_outlined),
          label: Text(_videoFile == null ? 'เลือกวิดีโอ' : _videoFile!.name),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _captionController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Caption',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _hashtagsController,
          decoration: const InputDecoration(
            labelText: 'Hashtags (คั่นด้วยเว้นวรรค)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'แพลตฟอร์ม',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        ...SocialPlatformTarget.all.map(
          (target) => CheckboxListTile(
            value: _selectedTargets[target] ?? false,
            onChanged: _publishing
                ? null
                : (value) => setState(() => _selectedTargets[target] = value == true),
            title: Text(SocialPlatformTarget.label(target)),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (_uploadProgress != null) ...<Widget>[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _uploadProgress),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _publishing ? null : _publish,
          icon: _publishing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send_outlined),
          label: Text(_publishing ? 'กำลังอัปโหลด/โพสต์...' : 'โพสต์ทุกแพลตฟอร์ม'),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return StreamBuilder<List<SocialPostRecord>>(
      stream: AdminSocialService.instance.streamPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final posts = snapshot.data ?? const <SocialPostRecord>[];
        if (posts.isEmpty) {
          return const Center(child: Text('ยังไม่มีโพสต์'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            post.caption,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Chip(
                          label: Text(SocialPostStatus.label(post.status)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...post.selectedPlatforms.map((target) {
                      final result = post.platformResults[target];
                      final status = result?.status ?? 'pending';
                      final failed = status == 'failed';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: Icon(
                          failed ? Icons.error_outline : Icons.check_circle_outline,
                          color: failed ? Colors.red : Colors.green,
                        ),
                        title: Text(SocialPlatformTarget.label(target)),
                        subtitle: Text(
                          result?.error ?? result?.url ?? status,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: failed
                            ? TextButton(
                                onPressed: () => _retryPlatform(post, target),
                                child: const Text('ลองใหม่'),
                              )
                            : null,
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
