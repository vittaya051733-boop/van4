import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/admin_session.dart';
import '../models/admin_work_task.dart';
import '../services/admin_work_task_service.dart';
import '../utils/admin_callable_errors.dart';

class AdminWorkClaimBar extends StatefulWidget {
  const AdminWorkClaimBar({
    super.key,
    required this.sourceType,
    required this.sourceId,
    required this.title,
    this.branchId,
    this.compact = false,
  });

  final String sourceType;
  final String sourceId;
  final String title;
  final String? branchId;
  final bool compact;

  @override
  State<AdminWorkClaimBar> createState() => _AdminWorkClaimBarState();
}

class _AdminWorkClaimBarState extends State<AdminWorkClaimBar> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action, String success) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AdminCallableErrors.message(error))),
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return StreamBuilder<AdminWorkTask?>(
      stream: AdminWorkTaskService.watchTask(
        sourceType: widget.sourceType,
        sourceId: widget.sourceId,
      ),
      builder: (context, snapshot) {
        final task = snapshot.data;
        final claimedByOther =
            task != null && task.isClaimed && task.claimedByUid != uid;
        final claimedByMe =
            task != null && task.isClaimed && task.claimedByUid == uid;
        final canOwnerTakeOver =
            AdminSessionService.instance.isOwner && claimedByOther;

        final children = <Widget>[];
        if (claimedByOther) {
          children.add(
            Text(
              'กำลังทำ: ${task.claimedByLabel}',
              style: const TextStyle(
                color: Color(0xFF9A3412),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          );
        } else if (claimedByMe) {
          children.add(
            const Text(
              'กำลังทำ: คุณ',
              style: TextStyle(
                color: Color(0xFF166534),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          );
        } else if (task != null && task.isDone) {
          children.add(
            Text(
              'เสร็จแล้ว${task.completedByEmail != null ? ' · ${task.completedByEmail}' : ''}',
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          );
        } else if (task != null && task.isFailed) {
          children.add(
            Text(
              'ไม่สำเร็จ${task.failedByEmail != null ? ' · ${task.failedByEmail}' : ''}',
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          );
        }

        if (!claimedByOther || canOwnerTakeOver) {
          if (!claimedByMe && task?.isFailed != true && task?.isDone != true) {
            children.add(
              FilledButton(
                onPressed: _busy
                    ? null
                    : () => _run(
                          () => AdminWorkTaskService.claim(
                            sourceType: widget.sourceType,
                            sourceId: widget.sourceId,
                            title: widget.title,
                            branchId: widget.branchId,
                          ),
                          canOwnerTakeOver ? 'รับงานแทนแล้ว' : 'รับงานแล้ว',
                        ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(canOwnerTakeOver ? 'รับทับ' : 'รับงาน'),
              ),
            );
          }
        }

        if (claimedByMe || (AdminSessionService.instance.isOwner && claimedByOther)) {
          children.add(
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => AdminWorkTaskService.complete(
                          sourceType: widget.sourceType,
                          sourceId: widget.sourceId,
                        ),
                        'ปิดงานแล้ว',
                      ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('เสร็จ'),
            ),
          );
          children.add(
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => AdminWorkTaskService.fail(
                          sourceType: widget.sourceType,
                          sourceId: widget.sourceId,
                        ),
                        'บันทึกไม่สำเร็จแล้ว',
                      ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB91C1C),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: const Text('ไม่สำเร็จ'),
            ),
          );
        }

        if (children.isEmpty) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: EdgeInsets.only(top: widget.compact ? 8 : 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        );
      },
    );
  }
}
