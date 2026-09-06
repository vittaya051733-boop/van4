import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/admin_activity_log_entry.dart';
import '../models/admin_work_member_stats.dart';
import '../models/admin_work_task.dart';
import 'admin_firestore.dart';
import 'admin_work_task_service.dart';

class AdminWorkStatsSnapshot {
  const AdminWorkStatsSnapshot({
    required this.members,
    required this.statsResetAt,
    required this.resetByEmail,
  });

  final List<AdminWorkMemberStats> members;
  final DateTime? statsResetAt;
  final String? resetByEmail;
}

class AdminWorkStatsService {
  AdminWorkStatsService._();

  static const String _metaDocPath = 'admin_work_meta/global';

  static bool _isAfterReset(DateTime? value, DateTime? resetAt) {
    if (resetAt == null) {
      return true;
    }
    if (value == null) {
      return false;
    }
    return !value.isBefore(resetAt);
  }

  static String _memberKey({String? uid, String? email}) {
    final trimmedUid = uid?.trim();
    if (trimmedUid != null && trimmedUid.isNotEmpty) {
      return trimmedUid;
    }
    return email?.trim().toLowerCase() ?? '';
  }

  static AdminWorkStatsSnapshot compose({
    required List<AdminWorkTask> tasks,
    required List<AdminActivityLogEntry> logs,
    required DateTime? statsResetAt,
    required String? resetByEmail,
  }) {
    final bucket = <String, _MutableMemberStats>{};

    void touch({
      required String uid,
      required String email,
      required String displayName,
    }) {
      final key = _memberKey(uid: uid, email: email);
      if (key.isEmpty) {
        return;
      }
      final existing = bucket[key];
      if (existing != null) {
        if (existing.displayName == existing.email && displayName.trim().isNotEmpty) {
          existing.displayName = displayName.trim();
        }
        return;
      }
      bucket[key] = _MutableMemberStats(
        uid: uid,
        email: email,
        displayName: displayName.trim().isNotEmpty ? displayName.trim() : email,
      );
    }

    for (final task in tasks) {
      if (task.isDone && _isAfterReset(task.completedAt, statsResetAt)) {
        final uid = task.completedByUid ?? task.claimedByUid ?? '';
        final email = task.completedByEmail ?? task.claimedByEmail ?? '';
        touch(uid: uid, email: email, displayName: task.claimedByLabel);
        bucket[_memberKey(uid: uid, email: email)]?.successCount++;
      }

      if (task.isFailed && _isAfterReset(task.failedAt, statsResetAt)) {
        final uid = task.failedByUid ?? task.claimedByUid ?? '';
        final email = task.failedByEmail ?? task.claimedByEmail ?? '';
        touch(uid: uid, email: email, displayName: task.claimedByLabel);
        bucket[_memberKey(uid: uid, email: email)]?.failCount++;
      }

      if (task.isClaimed && _isAfterReset(task.claimedAt, statsResetAt)) {
        final uid = task.claimedByUid ?? '';
        final email = task.claimedByEmail ?? '';
        touch(uid: uid, email: email, displayName: task.claimedByLabel);
        final entry = bucket[_memberKey(uid: uid, email: email)];
        if (entry != null) {
          entry.inProgressCount++;
          if (task.title.trim().isNotEmpty) {
            entry.inProgressTitles.add(task.title.trim());
          }
        }
      }
    }

    for (final log in logs) {
      if (!_isAfterReset(log.at, statsResetAt)) {
        continue;
      }
      final isRejectWrite =
          log.action == 'write' && log.labelTh.contains('ปฏิเสธ');
      final isFailAction = log.action == 'fail';
      if (!isRejectWrite && !isFailAction) {
        continue;
      }
      touch(
        uid: log.actorUid,
        email: log.actorEmail,
        displayName: log.actorEmail,
      );
      bucket[_memberKey(uid: log.actorUid, email: log.actorEmail)]?.failCount++;
    }

    final members = bucket.values
        .map((entry) => entry.toImmutable())
        .where((entry) => entry.totalHandled > 0)
        .toList(growable: false)
      ..sort((left, right) {
        final progressCompare =
            right.inProgressCount.compareTo(left.inProgressCount);
        if (progressCompare != 0) {
          return progressCompare;
        }
        return right.successCount.compareTo(left.successCount);
      });

    return AdminWorkStatsSnapshot(
      members: members,
      statsResetAt: statsResetAt,
      resetByEmail: resetByEmail,
    );
  }

  static Stream<AdminWorkStatsSnapshot> watchTeamStats() {
    return Stream<AdminWorkStatsSnapshot>.multi((controller) {
      List<AdminWorkTask>? tasks;
      List<AdminActivityLogEntry>? logs;
      DateTime? statsResetAt;
      String? resetByEmail;

      void emitIfReady() {
        if (tasks == null || logs == null) {
          return;
        }
        controller.add(
          compose(
            tasks: tasks!,
            logs: logs!,
            statsResetAt: statsResetAt,
            resetByEmail: resetByEmail,
          ),
        );
      }

      final subs = <StreamSubscription<dynamic>>[
        AdminWorkTaskService.watchTasks().listen(
          (value) {
            tasks = value;
            emitIfReady();
          },
          onError: controller.addError,
        ),
        AdminWorkTaskService.watchLogs().listen(
          (value) {
            logs = value;
            emitIfReady();
          },
          onError: controller.addError,
        ),
        AdminFirestore.instance.doc(_metaDocPath).snapshots().listen(
          (snapshot) {
            final data = snapshot.data();
            statsResetAt = _readTime(data?['statsResetAt']);
            resetByEmail = data?['resetByEmail']?.toString();
            emitIfReady();
          },
          onError: controller.addError,
        ),
      ];

      controller.onCancel = () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      };
    });
  }

  static DateTime? _readTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

class _MutableMemberStats {
  _MutableMemberStats({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  final String uid;
  final String email;
  String displayName;
  int successCount = 0;
  int failCount = 0;
  int inProgressCount = 0;
  final List<String> inProgressTitles = <String>[];

  AdminWorkMemberStats toImmutable() {
    return AdminWorkMemberStats(
      uid: uid,
      email: email,
      displayName: displayName,
      successCount: successCount,
      failCount: failCount,
      inProgressCount: inProgressCount,
      inProgressTitles: List<String>.unmodifiable(inProgressTitles),
    );
  }
}
