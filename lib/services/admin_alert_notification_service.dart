import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/admin_alert_item.dart';
import '../models/admin_alert_topic.dart';
import 'admin_alert_center_service.dart';
import 'admin_alert_preferences_service.dart';

/// Local notifications + sound for new admin alerts on focused topics only.
class AdminAlertNotificationService {
  AdminAlertNotificationService._();

  static final AdminAlertNotificationService instance =
      AdminAlertNotificationService._();

  static const String _channelId = 'van4_admin_alerts';
  static const String _channelName = 'แจ้งเตือนแอดมิน';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<AdminAlertCenterSnapshot>? _subscription;
  final Set<String> _knownAlertIds = <String>{};
  bool _baselineReady = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    await AdminAlertPreferencesService.instance.ensureLoaded();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(initializationSettings);
    await _ensureAndroidNotificationChannel();
    await _requestNotificationPermission();
    _initialized = true;
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid) {
      return;
    }
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _ensureAndroidNotificationChannel() async {
    if (!Platform.isAndroid) {
      return;
    }
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) {
      return;
    }

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'แจ้งเตือนเมื่อมีงานแอดมินที่เลือกโฟกัสไว้',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await androidPlugin.createNotificationChannel(channel);
  }

  Future<void> startMonitoring() async {
    await initialize();
    await _subscription?.cancel();
    _baselineReady = false;
    _knownAlertIds.clear();

    _subscription = AdminAlertCenterService.instance.streamAlerts().listen(
      _handleSnapshot,
      onError: (Object error, StackTrace stack) {
        debugPrint('Admin alert notification stream error: $error\n$stack');
      },
    );
  }

  Future<void> stopMonitoring() async {
    await _subscription?.cancel();
    _subscription = null;
    _baselineReady = false;
    _knownAlertIds.clear();
  }

  void _handleSnapshot(AdminAlertCenterSnapshot snapshot) {
    final currentIds = snapshot.items.map((item) => item.id).toSet();

    if (!_baselineReady) {
      _knownAlertIds
        ..clear()
        ..addAll(currentIds);
      _baselineReady = true;
      return;
    }

    final focusedTypes = AdminAlertPreferencesService.instance.focusedTypes;
    final newItems = snapshot.items
        .where(
          (item) =>
              !_knownAlertIds.contains(item.id) &&
              focusedTypes.contains(item.type),
        )
        .toList(growable: false);

    _knownAlertIds
      ..clear()
      ..addAll(currentIds);

    for (final item in newItems) {
      unawaited(_notifyNewAlert(item));
    }
  }

  Future<void> _notifyNewAlert(AdminAlertItem item) async {
    await SystemSound.play(SystemSoundType.alert);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'แจ้งเตือนงานแอดมินที่เลือกโฟกัส',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'แจ้งเตือนแอดมิน',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final topicLabel = AdminAlertTopic.label(item.type);
    await _localNotifications.show(
      _notificationIdForAlert(item.id),
      '$topicLabel — ${item.title}',
      item.subtitle,
      details,
    );
  }

  int _notificationIdForAlert(String alertId) {
    return alertId.hashCode.abs() % 100000;
  }
}
