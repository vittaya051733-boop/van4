import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../admin_repository.dart';

/// แจ้งเตือน (พร้อมเสียง) เมื่อมีสินค้าที่ AI ประเมินว่าผิดกฎหมายเข้ามาใหม่
class AdminIllegalProductAlertService {
  AdminIllegalProductAlertService._();

  static final AdminIllegalProductAlertService instance =
      AdminIllegalProductAlertService._();

  static const String _channelId = 'van4_illegal_product_alerts';
  static const String _channelName = 'สินค้าผิดกฎหมาย (AI)';

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  StreamSubscription<List<AdminProductRecord>>? _subscription;
  final Set<String> _knownProductIds = <String>{};
  bool _baselineReady = false;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

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
      description: 'แจ้งเตือนเมื่อ AI พบสินค้าที่อาจผิดกฎหมาย',
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
    _knownProductIds.clear();

    _subscription = AdminRepository.streamIllegalAiProducts().listen(
      _handleProducts,
      onError: (Object error, StackTrace stack) {
        debugPrint('Illegal product alert stream error: $error\n$stack');
      },
    );
  }

  Future<void> stopMonitoring() async {
    await _subscription?.cancel();
    _subscription = null;
    _baselineReady = false;
    _knownProductIds.clear();
  }

  void _handleProducts(List<AdminProductRecord> products) {
    final currentIds = products.map((product) => product.id).toSet();

    if (!_baselineReady) {
      _knownProductIds
        ..clear()
        ..addAll(currentIds);
      _baselineReady = true;
      return;
    }

    final newProducts = products
        .where((product) => !_knownProductIds.contains(product.id))
        .toList(growable: false);

    _knownProductIds
      ..clear()
      ..addAll(currentIds);

    for (final product in newProducts) {
      unawaited(_notifyNewIllegalProduct(product));
    }
  }

  Future<void> _notifyNewIllegalProduct(AdminProductRecord product) async {
    final shopLabel = product.shopName ?? product.ownerUid ?? 'ไม่ระบุร้าน';
    final reason = (product.aiLegalAnalysisReason ?? '').trim();
    final body = reason.isNotEmpty
        ? '$shopLabel — $reason'
        : '$shopLabel — AI ประเมินว่าสินค้านี้อาจผิดกฎหมาย';

    await SystemSound.play(SystemSoundType.alert);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'แจ้งเตือนเมื่อ AI พบสินค้าที่อาจผิดกฎหมาย',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: 'สินค้าผิดกฎหมาย',
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

    await _localNotifications.show(
      _notificationIdForProduct(product.id),
      'พบสินค้ารอแอดมินตรวจสอบ (AI ประเมินว่าผิดกฎหมาย)',
      '${product.name}\n$body',
      details,
    );
  }

  int _notificationIdForProduct(String productId) {
    return productId.hashCode.abs() % 100000;
  }
}
