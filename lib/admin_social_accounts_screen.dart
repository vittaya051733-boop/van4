import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/social_models.dart';
import 'services/admin_social_service.dart';

class AdminSocialAccountsScreen extends StatefulWidget {
  const AdminSocialAccountsScreen({super.key});

  @override
  State<AdminSocialAccountsScreen> createState() =>
      _AdminSocialAccountsScreenState();
}

class _AdminSocialAccountsScreenState extends State<AdminSocialAccountsScreen> {
  bool _connecting = false;

  Future<void> _connect(String platform) async {
    setState(() => _connecting = true);
    try {
      final returnUrl = Uri.base.removeFragment().toString();
      final url = await AdminSocialService.instance.getSocialOAuthUrl(
        platform: platform,
        returnUrl: returnUrl,
      );
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, webOnlyWindowName: '_self')) {
        throw StateError('เปิดหน้า OAuth ไม่สำเร็จ');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เชื่อมบัญชีไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  Future<void> _disconnect(SocialAccountRecord account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยกเลิกการเชื่อม'),
        content: Text('ยกเลิกการเชื่อม ${account.displayName}?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await AdminSocialService.instance.disconnectAccount(account.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ยกเลิกการเชื่อมแล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ล้มเหลว: $error')),
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
        title: const Text('บัญชีโซเชียล'),
      ),
      body: StreamBuilder<List<SocialAccountRecord>>(
        stream: AdminSocialService.instance.streamAccounts(),
        builder: (context, snapshot) {
          final accounts = snapshot.data ?? const <SocialAccountRecord>[];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              const Text(
                'เชื่อมบัญชีครั้งเดียว แล้วโพสต์วิดีโอไปหลายแพลตฟอร์มได้จาก van4',
                style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 16),
              _ConnectCard(
                title: 'Facebook + Instagram',
                subtitle: 'Meta Business (Page + IG Reels)',
                icon: Icons.facebook,
                loading: _connecting,
                onConnect: () => _connect(SocialPlatformKey.meta),
              ),
              const SizedBox(height: 12),
              _ConnectCard(
                title: 'YouTube',
                subtitle: 'Shorts / วิดีโอ',
                icon: Icons.play_circle_outline,
                loading: _connecting,
                onConnect: () => _connect(SocialPlatformKey.youtube),
              ),
              const SizedBox(height: 12),
              _ConnectCard(
                title: 'TikTok',
                subtitle: 'Content Posting API',
                icon: Icons.music_note_outlined,
                loading: _connecting,
                onConnect: () => _connect(SocialPlatformKey.tiktok),
              ),
              const SizedBox(height: 24),
              Text(
                'บัญชีที่เชื่อมแล้ว (${accounts.length})',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              if (accounts.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('ยังไม่มีบัญชีที่เชื่อม'),
                  ),
                )
              else
                ...accounts.map(
                  (account) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(_platformIcon(account.platform)),
                      ),
                      title: Text(account.displayName),
                      subtitle: Text(
                        '${account.platform}'
                        '${account.igUsername != null && account.igUsername!.isNotEmpty ? ' • @${account.igUsername}' : ''}',
                      ),
                      trailing: IconButton(
                        tooltip: 'ยกเลิกการเชื่อม',
                        onPressed: () => _disconnect(account),
                        icon: const Icon(Icons.link_off_outlined),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case SocialPlatformKey.meta:
        return Icons.facebook;
      case SocialPlatformKey.youtube:
        return Icons.play_circle_outline;
      case SocialPlatformKey.tiktok:
        return Icons.music_note_outlined;
      default:
        return Icons.share_outlined;
    }
  }
}

class _ConnectCard extends StatelessWidget {
  const _ConnectCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onConnect,
    required this.loading,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onConnect;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFE65100)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(subtitle),
        trailing: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : FilledButton(
                onPressed: onConnect,
                child: const Text('เชื่อม'),
              ),
      ),
    );
  }
}
