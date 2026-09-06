import 'package:flutter/material.dart';

import 'models/admin_activity_log_entry.dart';
import 'models/admin_session.dart';
import 'models/admin_work_member_stats.dart';
import 'models/admin_work_task.dart';
import 'services/admin_work_stats_service.dart';
import 'services/admin_work_task_service.dart';
import 'utils/admin_callable_errors.dart';

String _formatWorkLogTime(DateTime? value) {
  if (value == null) {
    return '-';
  }
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
}

class AdminWorkLogScreen extends StatefulWidget {
  const AdminWorkLogScreen({super.key});

  @override
  State<AdminWorkLogScreen> createState() => _AdminWorkLogScreenState();
}

class _AdminWorkLogScreenState extends State<AdminWorkLogScreen> {
  bool _resetting = false;

  Future<void> _confirmResetStats() async {
    if (!AdminSessionService.instance.isSuperAdmin || _resetting) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('รีเซ็ตสถิติบันทึกงาน?'),
        content: const Text(
          'จะนับสำเร็จ/ไม่สำเร็จใหม่ตั้งแต่ตอนนี้\nงานที่กำลังทำยังคงอยู่',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('รีเซ็ต'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _resetting = true);
    try {
      await AdminWorkTaskService.resetTeamStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('รีเซ็ตสถิติแล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AdminCallableErrors.message(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _resetting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoped = AdminSessionService.instance.isBranchScoped;
    final isSuperAdmin = AdminSessionService.instance.isSuperAdmin;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: const Color(0xFFE65100),
          foregroundColor: Colors.white,
          title: const Text('บันทึกงาน'),
          actions: <Widget>[
            if (isSuperAdmin)
              IconButton(
                tooltip: 'รีเซ็ตสถิติ (ซูเปอร์แอดมิน)',
                onPressed: _resetting ? null : _confirmResetStats,
                icon: _resetting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.restart_alt_rounded),
              ),
          ],
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFFFCCBC),
            indicatorColor: Colors.white,
            tabs: <Tab>[
              Tab(text: 'สรุปทีม'),
              Tab(text: 'งานที่รับ'),
              Tab(text: 'ไทม์ไลน์'),
            ],
          ),
        ),
        body: Column(
          children: <Widget>[
            if (scoped)
              Container(
                width: double.infinity,
                color: const Color(0xFFFFF7ED),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'แสดงเฉพาะสาขา ${AdminSessionService.instance.assignedBranchId ?? '-'}',
                  style: const TextStyle(
                    color: Color(0xFF9A3412),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Expanded(
              child: TabBarView(
                children: <Widget>[
                  _TeamStatsTab(),
                  _ClaimedTasksTab(),
                  _ActivityTimelineTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamStatsTab extends StatelessWidget {
  const _TeamStatsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminWorkStatsSnapshot>(
      stream: AdminWorkStatsService.watchTeamStats(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('โหลดสรุปไม่สำเร็จ: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.members.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'ยังไม่มีสถิติงานในช่วงนี้\nรับงานแล้วกด เสร็จ / ไม่สำเร็จ เพื่อสะสมตัวเลข',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), height: 1.4),
              ),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            if (data.statsResetAt != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: Text(
                  'นับตั้งแต่ ${_formatWorkLogTime(data.statsResetAt)}'
                  '${data.resetByEmail != null ? ' · รีเซ็ตโดย ${data.resetByEmail}' : ''}',
                  style: const TextStyle(color: Color(0xFF9A3412), fontSize: 12),
                ),
              ),
            ...data.members.map(
              (member) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _MemberStatsCard(member: member),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MemberStatsCard extends StatelessWidget {
  const _MemberStatsCard({required this.member});

  final AdminWorkMemberStats member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE0B2)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            member.displayName,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          if (member.email.isNotEmpty && member.email != member.displayName)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                member.email,
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _CountChip(
                label: 'สำเร็จ',
                count: member.successCount,
                color: const Color(0xFF166534),
                background: const Color(0xFFDCFCE7),
              ),
              _CountChip(
                label: 'ไม่สำเร็จ',
                count: member.failCount,
                color: const Color(0xFFB91C1C),
                background: const Color(0xFFFEE2E2),
              ),
              _CountChip(
                label: 'กำลังทำ',
                count: member.inProgressCount,
                color: const Color(0xFF9A3412),
                background: const Color(0xFFFFE0B2),
              ),
            ],
          ),
          if (member.inProgressTitles.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Text(
              'กำลังทำอยู่',
              style: TextStyle(
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 6),
            ...member.inProgressTitles.take(5).map(
                  (title) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text('• ', style: TextStyle(color: Color(0xFF6B7280))),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(color: Color(0xFF374151), height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (member.inProgressTitles.length > 5)
              Text(
                '+ อีก ${member.inProgressTitles.length - 5} งาน',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.label,
    required this.count,
    required this.color,
    required this.background,
  });

  final String label;
  final int count;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

class _ClaimedTasksTab extends StatelessWidget {
  const _ClaimedTasksTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminWorkTask>>(
      stream: AdminWorkTaskService.watchTasks(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('โหลดงานไม่สำเร็จ: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snapshot.data!;
        if (tasks.isEmpty) {
          return const Center(child: Text('ยังไม่มีงานที่ถูกรับ'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final task = tasks[index];
            final done = task.isDone;
            final failed = task.isFailed;
            final statusLabel = done
                ? 'เสร็จ'
                : failed
                    ? 'ไม่สำเร็จ'
                    : 'กำลังทำ';
            final statusColor = done
                ? const Color(0xFF166534)
                : failed
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFFC2410C);
            final borderColor = done
                ? const Color(0xFFBBF7D0)
                : failed
                    ? const Color(0xFFFECACA)
                    : const Color(0xFFFED7AA);
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${task.sourceType} · ${task.sourceId}',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    done
                        ? 'ปิดโดย ${task.completedByEmail ?? '-'} · ${_formatWorkLogTime(task.completedAt)}'
                        : failed
                            ? 'ไม่สำเร็จโดย ${task.failedByEmail ?? '-'} · ${_formatWorkLogTime(task.failedAt)}'
                            : 'รับโดย ${task.claimedByLabel} · ${_formatWorkLogTime(task.claimedAt)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ActivityTimelineTab extends StatelessWidget {
  const _ActivityTimelineTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminActivityLogEntry>>(
      stream: AdminWorkTaskService.watchLogs(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('โหลดบันทึกไม่สำเร็จ: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data!;
        if (logs.isEmpty) {
          return const Center(child: Text('ยังไม่มีบันทึกการทำงาน'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: logs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final log = logs[index];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '${log.actionLabelTh} · ${_formatWorkLogTime(log.at)}',
                    style: const TextStyle(
                      color: Color(0xFF9A3412),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    log.labelTh,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${log.actorEmail} · ${log.actorRole} · ${log.branchId}',
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
