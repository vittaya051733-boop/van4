import 'package:flutter/material.dart';

import 'admin_internal_chat_repository.dart';
import 'admin_internal_thread_screen.dart';
import 'models/admin_peer_profile.dart';
import 'services/admin_firestore.dart';
import 'services/ecosystem_health_service.dart';

class AdminInternalChatHubScreen extends StatefulWidget {
  const AdminInternalChatHubScreen({
    super.key,
    this.embedded = false,
  });

  final bool embedded;

  @override
  State<AdminInternalChatHubScreen> createState() =>
      _AdminInternalChatHubScreenState();
}

class _AdminInternalChatHubScreenState extends State<AdminInternalChatHubScreen> {
  bool _openingTeam = false;
  bool _openingDm = false;
  int _directoryReloadToken = 0;

  Future<void> _openTeamThread() async {
    if (_openingTeam) {
      return;
    }
    setState(() => _openingTeam = true);
    try {
      final threadId = await AdminInternalChatRepository.ensureTeamThread();
      EcosystemHealthService.instance.reportOk(
        pointId: 'V4-CHAT',
        source: 'admin_chat_hub',
      );
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AdminInternalThreadScreen(
            threadId: threadId,
            title: 'ห้องทีมแอดมิน',
            isTeam: true,
          ),
        ),
      );
    } catch (error) {
      EcosystemHealthService.instance.reportFailure(
        pointId: 'V4-CHAT',
        error: error,
        source: 'admin_chat_hub',
      );
      if (mounted) {
        _showError(AdminFirestore.userMessage(error, fallback: 'เปิดห้องทีมไม่สำเร็จ'));
      }
    } finally {
      if (mounted) {
        setState(() => _openingTeam = false);
      }
    }
  }

  Future<void> _openDm(AdminPeerProfile peer) async {
    if (_openingDm) {
      return;
    }
    setState(() => _openingDm = true);
    try {
      final threadId = await AdminInternalChatRepository.ensureDmThread(peer);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => AdminInternalThreadScreen(
            threadId: threadId,
            title: peer.displayName,
            peer: peer,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showError(AdminFirestore.userMessage(error, fallback: 'เปิดแชทไม่สำเร็จ'));
      }
    } finally {
      if (mounted) {
        setState(() => _openingDm = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  void _reloadDirectory() {
    setState(() => _directoryReloadToken += 1);
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _openingTeam ? null : _openTeamThread,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE0B2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.groups_outlined, color: Color(0xFFE65100)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Text(
                            'ห้องทีมแอดมิน',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _openingTeam
                                ? 'กำลังเปิดห้อง...'
                                : 'แชทรวมทุกแอดมิน • ส่งรูปและไฟล์ได้',
                            style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (_openingTeam)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFE65100)),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'แชทส่วนตัวกับแอดมิน',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF9A3412),
                ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminDirectoryEntry>>(
            key: ValueKey<int>(_directoryReloadToken),
            stream: AdminInternalChatRepository.streamAdminDirectory(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Icon(Icons.cloud_off_outlined, size: 40, color: Color(0xFFB45309)),
                        const SizedBox(height: 12),
                        Text(
                          AdminFirestore.userMessage(
                            snapshot.error!,
                            fallback: 'โหลดรายชื่อแอดมินไม่สำเร็จ',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB45309)),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _reloadDirectory,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final admins = snapshot.data ?? const <AdminDirectoryEntry>[];
              if (admins.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'ยังไม่มีแอดมินคนอื่นในระบบ\n(ต้องมี admins/{email} และ authUid หลังล็อกอิน van4)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: admins.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final admin = admins[index];
                  final peer = admin.toPeerProfile();
                  final disabled = peer == null || _openingDm;
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: disabled ? null : () => _openDm(peer),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: <Widget>[
                            CircleAvatar(
                              backgroundColor: const Color(0xFFFFE0B2),
                              child: Text(
                                admin.displayName.isNotEmpty
                                    ? admin.displayName.characters.first.toUpperCase()
                                    : 'A',
                                style: const TextStyle(color: Color(0xFFE65100)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    admin.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  Text(
                                    disabled && peer == null
                                        ? 'ยังไม่เคยล็อกอิน van4'
                                        : admin.email,
                                    style: TextStyle(
                                      color: peer == null
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF6B7280),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (peer != null && !_openingDm)
                              const Icon(Icons.chat_bubble_outline, color: Color(0xFFE65100))
                            else if (peer == null)
                              const Icon(Icons.schedule, color: Color(0xFF9CA3AF))
                            else
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('แชทแอดมิน'),
      ),
      body: body,
    );
  }
}
