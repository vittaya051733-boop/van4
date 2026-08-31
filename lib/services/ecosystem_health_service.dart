import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/ecosystem_health_point.dart';
import 'admin_firestore.dart';
import 'admin_project_finance_service.dart';

/// In-memory ecosystem health for van4 admin.
/// van1/van2/van3 statuses come from [ecosystem_heartbeats]; shared/van4 from probes.
class EcosystemHealthService extends ChangeNotifier {
  EcosystemHealthService._();

  static final EcosystemHealthService instance = EcosystemHealthService._();

  /// Sessions older than this are treated as offline / red.
  /// Slightly above the 45s pulse so brief OS freezes / app switches do not flash red.
  static const Duration heartbeatStaleAfter = Duration(minutes: 5);

  final Map<String, EcosystemHealthPointStatus> _statuses =
      <String, EcosystemHealthPointStatus>{
    for (final point in EcosystemHealthCatalog.points)
      point.id: const EcosystemHealthPointStatus(
        tone: EcosystemHealthTone.unknown,
      ),
  };

  final Map<EcosystemHealthApp, DateTime?> _latestHeartbeatAt =
      <EcosystemHealthApp, DateTime?>{};
  final Map<EcosystemHealthApp, String?> _latestHeartbeatUid =
      <EcosystemHealthApp, String?>{};
  final Map<EcosystemHealthApp, QuerySnapshot<Map<String, dynamic>>?>
      _latestSnapshots =
      <EcosystemHealthApp, QuerySnapshot<Map<String, dynamic>>?>{};

  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>
      _heartbeatSubs =
      <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
  Timer? _staleTimer;

  bool _watchingHeartbeats = false;
  bool _probing = false;
  DateTime? _lastProbeAt;
  String? _lastProbeError;

  bool get isProbing => _probing;
  DateTime? get lastProbeAt => _lastProbeAt;
  String? get lastProbeError => _lastProbeError;
  bool get isWatchingHeartbeats => _watchingHeartbeats;

  DateTime? latestHeartbeatAt(EcosystemHealthApp app) =>
      _latestHeartbeatAt[app];

  String? latestHeartbeatUid(EcosystemHealthApp app) =>
      _latestHeartbeatUid[app];

  EcosystemHealthPointStatus statusOf(String pointId) {
    return _statuses[pointId] ??
        const EcosystemHealthPointStatus(tone: EcosystemHealthTone.unknown);
  }

  EcosystemHealthCounts counts({EcosystemHealthApp? app}) {
    final points = EcosystemHealthCatalog.points.where(
      (p) => app == null || p.app == app,
    );
    var ok = 0;
    var fail = 0;
    var unknown = 0;
    for (final point in points) {
      switch (statusOf(point.id).tone) {
        case EcosystemHealthTone.ok:
          ok++;
        case EcosystemHealthTone.fail:
          fail++;
        case EcosystemHealthTone.unknown:
          unknown++;
      }
    }
    return EcosystemHealthCounts(
      total: ok + fail + unknown,
      ok: ok,
      fail: fail,
      unknown: unknown,
    );
  }

  List<EcosystemHealthPoint> failingPoints({EcosystemHealthApp? app}) {
    return EcosystemHealthCatalog.points
        .where(
          (p) =>
              (app == null || p.app == app) &&
              statusOf(p.id).tone == EcosystemHealthTone.fail,
        )
        .toList(growable: false);
  }

  void reportFailure({
    required String pointId,
    required Object error,
    String source = 'screen',
  }) {
    final message = AdminFirestore.userMessage(error);
    _statuses[pointId] = EcosystemHealthPointStatus(
      tone: EcosystemHealthTone.fail,
      message: message,
      updatedAt: DateTime.now(),
      source: source,
    );
    notifyListeners();
  }

  void reportOk({
    required String pointId,
    String source = 'screen',
    String? message,
  }) {
    _statuses[pointId] = EcosystemHealthPointStatus(
      tone: EcosystemHealthTone.ok,
      message: message ?? 'เชื่อมต่อได้',
      updatedAt: DateTime.now(),
      source: source,
    );
    notifyListeners();
  }

  void startHeartbeatWatch() {
    if (_watchingHeartbeats) {
      return;
    }
    _watchingHeartbeats = true;
    _staleTimer?.cancel();
    _staleTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      for (final entry in _latestSnapshots.entries) {
        final snap = entry.value;
        if (snap != null) {
          _onHeartbeatSnapshot(entry.key, snap);
        }
      }
    });
    for (final app in const <EcosystemHealthApp>[
      EcosystemHealthApp.van1,
      EcosystemHealthApp.van2,
      EcosystemHealthApp.van3,
    ]) {
      final appId = switch (app) {
        EcosystemHealthApp.van1 => 'van1',
        EcosystemHealthApp.van2 => 'van2',
        EcosystemHealthApp.van3 => 'van3',
        _ => null,
      };
      if (appId == null) {
        continue;
      }
      final sub = AdminFirestore.instance
          .collection('ecosystem_heartbeats')
          .doc(appId)
          .collection('sessions')
          .snapshots()
          .listen(
            (snap) => _onHeartbeatSnapshot(app, snap),
            onError: (Object error) {
              if (kDebugMode) {
                debugPrint('heartbeat watch $appId failed: $error');
              }
              _markAppMissingHeartbeat(
                app,
                message: AdminFirestore.userMessage(error),
              );
              notifyListeners();
            },
          );
      _heartbeatSubs.add(sub);
    }
  }

  void stopHeartbeatWatch() {
    _staleTimer?.cancel();
    _staleTimer = null;
    for (final sub in _heartbeatSubs) {
      unawaited(sub.cancel());
    }
    _heartbeatSubs.clear();
    _watchingHeartbeats = false;
  }

  void _onHeartbeatSnapshot(
    EcosystemHealthApp app,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    _latestSnapshots[app] = snap;
    if (snap.docs.isEmpty) {
      _latestHeartbeatAt[app] = null;
      _latestHeartbeatUid[app] = null;
      _markAppMissingHeartbeat(
        app,
        message:
            'ยังไม่มี heartbeat — ติดตั้ง APK ใหม่แล้วเปิดแอปหลังล็อกอิน (หน้าแรก)',
        asFailure: false,
      );
      notifyListeners();
      return;
    }

    DocumentSnapshot<Map<String, dynamic>>? freshest;
    DateTime? freshestAt;
    for (final doc in snap.docs) {
      final at = _readUpdatedAt(doc.data()['updatedAt']);
      if (at == null) {
        continue;
      }
      if (freshestAt == null || at.isAfter(freshestAt)) {
        freshestAt = at;
        freshest = doc;
      }
    }

    if (freshest == null || freshestAt == null) {
      _markAppMissingHeartbeat(app, message: 'heartbeat ไม่มี updatedAt');
      notifyListeners();
      return;
    }

    _latestHeartbeatAt[app] = freshestAt;
    _latestHeartbeatUid[app] = freshest.id;
    final data = freshest.data() ?? <String, dynamic>{};
    final stale = DateTime.now().difference(freshestAt) > heartbeatStaleAfter;
    final pointsMap = _readBoolMap(data['points']);
    final firestoreOk = data['firestoreOk'] == true;
    final lastError = (data['lastError'] as String?)?.trim();
    final platform = (data['platform'] as String?)?.trim();

    final hbPointId = switch (app) {
      EcosystemHealthApp.van1 => 'V1-HB',
      EcosystemHealthApp.van2 => 'V2-HB',
      EcosystemHealthApp.van3 => 'V3-HB',
      _ => null,
    };
    if (hbPointId != null) {
      if (stale) {
        _statuses[hbPointId] = EcosystemHealthPointStatus(
          tone: EcosystemHealthTone.fail,
          message:
              'Heartbeat ค้าง (${_agoLabel(freshestAt)}) — แอปอาจปิดหรือหลุดเน็ต',
          updatedAt: freshestAt,
          source: 'heartbeat',
        );
      } else {
        _statuses[hbPointId] = EcosystemHealthPointStatus(
          tone: EcosystemHealthTone.ok,
          message: [
            'สด ${_agoLabel(freshestAt)}',
            if (platform != null && platform.isNotEmpty) platform,
            'uid ${freshest.id}',
          ].join(' · '),
          updatedAt: freshestAt,
          source: 'heartbeat',
        );
      }
    }

    for (final point in EcosystemHealthCatalog.points.where(
      (p) => p.app == app && !p.id.endsWith('-HB'),
    )) {
      if (point.id == 'V3-FCM') {
        // Still manual — do not overwrite screen/init unknown with heartbeat.
        continue;
      }
      if (stale) {
        _statuses[point.id] = EcosystemHealthPointStatus(
          tone: EcosystemHealthTone.fail,
          message: 'ไม่มี heartbeat สดจากแอป (${_agoLabel(freshestAt)})',
          updatedAt: freshestAt,
          source: 'heartbeat',
        );
        continue;
      }
      final ok = pointsMap[point.id];
      if (ok == true) {
        _statuses[point.id] = EcosystemHealthPointStatus(
          tone: EcosystemHealthTone.ok,
          message: 'แอปอ่านได้จริง',
          updatedAt: freshestAt,
          source: 'heartbeat',
        );
      } else if (ok == false) {
        _statuses[point.id] = EcosystemHealthPointStatus(
          tone: EcosystemHealthTone.fail,
          message: (lastError != null && lastError.isNotEmpty)
              ? lastError
              : (firestoreOk
                  ? 'แอปอ่านจุดนี้ไม่ได้'
                  : 'แอปรายงาน Firestore มีปัญหา'),
          updatedAt: freshestAt,
          source: 'heartbeat',
        );
      } else {
        _statuses[point.id] = EcosystemHealthPointStatus(
          tone: EcosystemHealthTone.unknown,
          message: 'แอปยังไม่รายงานจุดนี้',
          updatedAt: freshestAt,
          source: 'heartbeat',
        );
      }
    }

    notifyListeners();
  }

  void _markAppMissingHeartbeat(
    EcosystemHealthApp app, {
    required String message,
    bool asFailure = true,
  }) {
    final hbPointId = switch (app) {
      EcosystemHealthApp.van1 => 'V1-HB',
      EcosystemHealthApp.van2 => 'V2-HB',
      EcosystemHealthApp.van3 => 'V3-HB',
      _ => null,
    };
    if (hbPointId == null) {
      return;
    }
    // Only the HB chip reflects "app online". Collection points stay from probe
    // until a real heartbeat overwrites them.
    _statuses[hbPointId] = EcosystemHealthPointStatus(
      tone: asFailure ? EcosystemHealthTone.fail : EcosystemHealthTone.unknown,
      message: message,
      updatedAt: DateTime.now(),
      source: 'heartbeat',
    );
  }

  bool _hasFreshHeartbeat(EcosystemHealthApp app) {
    final at = _latestHeartbeatAt[app];
    if (at == null) {
      return false;
    }
    return DateTime.now().difference(at) <= heartbeatStaleAfter;
  }

  Future<void> refreshHeartbeatsOnce() async {
    startHeartbeatWatch();
    for (final app in const <EcosystemHealthApp>[
      EcosystemHealthApp.van1,
      EcosystemHealthApp.van2,
      EcosystemHealthApp.van3,
    ]) {
      final appId = switch (app) {
        EcosystemHealthApp.van1 => 'van1',
        EcosystemHealthApp.van2 => 'van2',
        EcosystemHealthApp.van3 => 'van3',
        _ => null,
      };
      if (appId == null) {
        continue;
      }
      try {
        final snap = await AdminFirestore.instance
            .collection('ecosystem_heartbeats')
            .doc(appId)
            .collection('sessions')
            .get(const GetOptions(source: Source.server));
        _onHeartbeatSnapshot(app, snap);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('heartbeat fetch $appId failed: $error');
        }
        _markAppMissingHeartbeat(
          app,
          message: AdminFirestore.userMessage(error),
          asFailure: true,
        );
      }
    }
  }

  Future<void> runProbes() async {
    if (_probing) {
      return;
    }
    _probing = true;
    _lastProbeError = null;
    notifyListeners();

    final probeResults = <String, EcosystemHealthPointStatus>{};

    Future<void> probe(
      String key,
      Future<void> Function() action,
    ) async {
      try {
        await AdminFirestore.runWithRetry(action, attempts: 3, label: key);
        probeResults[key] = EcosystemHealthPointStatus(
          tone: EcosystemHealthTone.ok,
          message: 'อ่านได้จากเซิร์ฟเวอร์ (van4)',
          updatedAt: DateTime.now(),
          source: 'probe',
        );
      } catch (error) {
        probeResults[key] = EcosystemHealthPointStatus(
          tone: EcosystemHealthTone.fail,
          message: AdminFirestore.userMessage(error),
          updatedAt: DateTime.now(),
          source: 'probe',
        );
        if (kDebugMode) {
          debugPrint('EcosystemHealth probe $key failed: $error');
        }
      }
    }

    try {
      // Pull heartbeats first so van1/2/3 can show real app status.
      await refreshHeartbeatsOnce();

      await probe('firestore_ping', () async {
        await AdminFirestore.instance
            .collection('admins')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('admins', () async {
        await AdminFirestore.instance
            .collection('admins')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('orders', () async {
        await AdminFirestore.instance
            .collection('orders')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('riders', () async {
        await AdminFirestore.instance
            .collection('riders')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('credits', () async {
        await AdminFirestore.instance
            .collection('credits')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('products', () async {
        await AdminFirestore.instance
            .collection('products')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('coupons', () async {
        await AdminFirestore.instance
            .collection('coupons')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('pricing', () async {
        await AdminFirestore.instance
            .collection('pricing_config')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('notifications', () async {
        await AdminFirestore.instance
            .collection('app_notifications')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('support', () async {
        await AdminFirestore.instance
            .collection('admin_support_tickets')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('withdraw', () async {
        await AdminFirestore.instance
            .collection('withdraw_requests')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('admin_chat', () async {
        await AdminFirestore.instance
            .collection('admin_internal_threads')
            .limit(1)
            .get(const GetOptions(source: Source.server));
      });
      await probe('project_finance', () async {
        await AdminProjectFinanceService.buildSnapshot();
      });

      for (final point in EcosystemHealthCatalog.points) {
        if (point.id == 'V3-FCM' || point.id.endsWith('-HB')) {
          continue;
        }
        // Prefer live app heartbeat when fresh.
        if ((point.app == EcosystemHealthApp.van1 ||
                point.app == EcosystemHealthApp.van2 ||
                point.app == EcosystemHealthApp.van3) &&
            _hasFreshHeartbeat(point.app) &&
            _statuses[point.id]?.source == 'heartbeat') {
          continue;
        }
        final key = point.probeKey;
        if (key == null) {
          continue;
        }
        final result = probeResults[key];
        if (result == null) {
          continue;
        }
        final fromApp = point.app == EcosystemHealthApp.van1 ||
            point.app == EcosystemHealthApp.van2 ||
            point.app == EcosystemHealthApp.van3;
        _statuses[point.id] = EcosystemHealthPointStatus(
          tone: result.tone,
          message: fromApp && result.tone == EcosystemHealthTone.ok
              ? 'แอดมินอ่านได้ — ถ้ารันแอปจะยืนยันด้วย heartbeat'
              : result.message,
          updatedAt: result.updatedAt,
          source: 'probe',
        );
      }

      // Re-apply heartbeats last so fresh app signals win.
      await refreshHeartbeatsOnce();

      _lastProbeAt = DateTime.now();
    } catch (error) {
      _lastProbeError = error.toString();
    } finally {
      _probing = false;
      notifyListeners();
    }
  }

  static DateTime? _readUpdatedAt(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }

  static Map<String, bool> _readBoolMap(Object? value) {
    if (value is! Map) {
      return const <String, bool>{};
    }
    final out = <String, bool>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      final v = entry.value;
      if (v is bool) {
        out[key] = v;
      }
    }
    return out;
  }

  static String _agoLabel(DateTime at) {
    final seconds = DateTime.now().difference(at).inSeconds;
    if (seconds < 5) {
      return 'เมื่อกี้';
    }
    if (seconds < 60) {
      return '$seconds วินาทีที่แล้ว';
    }
    final minutes = (seconds / 60).floor();
    return '$minutes นาทีที่แล้ว';
  }
}
