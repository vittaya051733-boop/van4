enum EcosystemHealthTone { ok, fail, unknown }

enum EcosystemHealthApp {
  shared,
  van1,
  van2,
  van3,
  van4,
}

class EcosystemHealthPoint {
  const EcosystemHealthPoint({
    required this.id,
    required this.app,
    required this.titleTh,
    required this.detailTh,
    required this.collection,
    this.priority = 2,
    this.probeKey,
  });

  final String id;
  final EcosystemHealthApp app;
  final String titleTh;
  final String detailTh;
  final String collection;
  final int priority;

  /// Key used by [EcosystemHealthService] live probes. Null = manual/unknown only.
  final String? probeKey;
}

class EcosystemHealthPointStatus {
  const EcosystemHealthPointStatus({
    required this.tone,
    this.message,
    this.updatedAt,
    this.source = 'init',
  });

  final EcosystemHealthTone tone;
  final String? message;
  final DateTime? updatedAt;
  final String source;

  EcosystemHealthPointStatus copyWith({
    EcosystemHealthTone? tone,
    String? message,
    DateTime? updatedAt,
    String? source,
  }) {
    return EcosystemHealthPointStatus(
      tone: tone ?? this.tone,
      message: message ?? this.message,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
    );
  }
}

class EcosystemHealthCounts {
  const EcosystemHealthCounts({
    required this.total,
    required this.ok,
    required this.fail,
    required this.unknown,
  });

  final int total;
  final int ok;
  final int fail;
  final int unknown;
}

/// Static connection map for MVP dashboard (aligned with ecosystem health checklist).
class EcosystemHealthCatalog {
  EcosystemHealthCatalog._();

  static const List<EcosystemHealthPoint> points = <EcosystemHealthPoint>[
    // Shared
    EcosystemHealthPoint(
      id: 'L1-FS-RULES',
      app: EcosystemHealthApp.shared,
      titleTh: 'Firestore เชื่อมต่อได้',
      detailTh: 'อ่านจากเซิร์ฟเวอร์ได้ — ถ้า unavailable ทั้งระบบจะแดง',
      collection: 'Firestore (default)',
      priority: 1,
      probeKey: 'firestore_ping',
    ),
    EcosystemHealthPoint(
      id: 'L1-AUTH-ADMIN',
      app: EcosystemHealthApp.shared,
      titleTh: 'สิทธิ์แอดมิน',
      detailTh: 'อ่าน admins/{email} ได้หลังล็อกอิน',
      collection: 'admins',
      priority: 1,
      probeKey: 'admins',
    ),

    // van3
    EcosystemHealthPoint(
      id: 'V3-HB',
      app: EcosystemHealthApp.van3,
      titleTh: 'Heartbeat จากแอปไรเดอร์',
      detailTh: 'van3 เขียน ecosystem_heartbeats หลังล็อกอิน — เขียวเมื่อสด ≤5 นาที',
      collection: 'ecosystem_heartbeats/van3/sessions',
      priority: 1,
    ),
    EcosystemHealthPoint(
      id: 'V3-ORDERS',
      app: EcosystemHealthApp.van3,
      titleTh: 'งานไรเดอร์ (orders)',
      detailTh: 'heartbeat จาก van3 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'orders',
      priority: 1,
      probeKey: 'orders',
    ),
    EcosystemHealthPoint(
      id: 'V3-RIDERS',
      app: EcosystemHealthApp.van3,
      titleTh: 'สถานะออนไลน์ไรเดอร์',
      detailTh: 'heartbeat จาก van3 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'riders',
      priority: 1,
      probeKey: 'riders',
    ),
    EcosystemHealthPoint(
      id: 'V3-CREDITS',
      app: EcosystemHealthApp.van3,
      titleTh: 'เครดิตไรเดอร์',
      detailTh: 'heartbeat จาก van3 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'credits',
      priority: 1,
      probeKey: 'credits',
    ),
    EcosystemHealthPoint(
      id: 'V3-FCM',
      app: EcosystemHealthApp.van3,
      titleTh: 'Push งานใหม่ (FCM)',
      detailTh: 'ยังต้องเทสมือ — ยังไม่มี probe อัตโนมัติ',
      collection: 'FCM / pushAppNotification',
      priority: 1,
    ),

    // van2
    EcosystemHealthPoint(
      id: 'V2-HB',
      app: EcosystemHealthApp.van2,
      titleTh: 'Heartbeat จากแอปลูกค้า',
      detailTh: 'van2 เขียน ecosystem_heartbeats หลังล็อกอิน — เขียวเมื่อสด ≤5 นาที',
      collection: 'ecosystem_heartbeats/van2/sessions',
      priority: 1,
    ),
    EcosystemHealthPoint(
      id: 'V2-ORDERS',
      app: EcosystemHealthApp.van2,
      titleTh: 'ออเดอร์ลูกค้า',
      detailTh: 'heartbeat จาก van2 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'orders',
      priority: 1,
      probeKey: 'orders',
    ),
    EcosystemHealthPoint(
      id: 'V2-CATALOG',
      app: EcosystemHealthApp.van2,
      titleTh: 'Catalog / หน้าแรก',
      detailTh: 'heartbeat จาก van2 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'products / public_shops',
      priority: 1,
      probeKey: 'products',
    ),
    EcosystemHealthPoint(
      id: 'V2-COUPONS',
      app: EcosystemHealthApp.van2,
      titleTh: 'คูปอง / โปรโมชั่น',
      detailTh: 'heartbeat จาก van2 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'coupons',
      priority: 2,
      probeKey: 'coupons',
    ),
    EcosystemHealthPoint(
      id: 'V2-PRICING',
      app: EcosystemHealthApp.van2,
      titleTh: 'ราคา / ค่าส่ง',
      detailTh: 'heartbeat จาก van2 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'pricing_config',
      priority: 2,
      probeKey: 'pricing',
    ),
    EcosystemHealthPoint(
      id: 'V2-NOTIF',
      app: EcosystemHealthApp.van2,
      titleTh: 'แจ้งเตือนลูกค้า',
      detailTh: 'heartbeat จาก van2 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'app_notifications',
      priority: 2,
      probeKey: 'notifications',
    ),

    // van1
    EcosystemHealthPoint(
      id: 'V1-HB',
      app: EcosystemHealthApp.van1,
      titleTh: 'Heartbeat จากแอปร้าน',
      detailTh: 'van1 เขียน ecosystem_heartbeats หลังล็อกอิน — เขียวเมื่อสด ≤5 นาที',
      collection: 'ecosystem_heartbeats/van1/sessions',
      priority: 1,
    ),
    EcosystemHealthPoint(
      id: 'V1-ORDERS',
      app: EcosystemHealthApp.van1,
      titleTh: 'ออเดอร์ร้าน',
      detailTh: 'heartbeat จาก van1 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'orders',
      priority: 1,
      probeKey: 'orders',
    ),
    EcosystemHealthPoint(
      id: 'V1-PRODUCTS',
      app: EcosystemHealthApp.van1,
      titleTh: 'สินค้าของร้าน',
      detailTh: 'heartbeat จาก van1 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'products',
      priority: 1,
      probeKey: 'products',
    ),
    EcosystemHealthPoint(
      id: 'V1-CREDITS',
      app: EcosystemHealthApp.van1,
      titleTh: 'กระเป๋าร้าน',
      detailTh: 'heartbeat จาก van1 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'merchant_wallets / credits',
      priority: 2,
      probeKey: 'credits',
    ),
    EcosystemHealthPoint(
      id: 'V1-NOTIF',
      app: EcosystemHealthApp.van1,
      titleTh: 'แจ้งเตือนร้าน',
      detailTh: 'heartbeat จาก van1 ถ้ารันอยู่ — ไม่มีแล้วใช้การอ่านจากแอดมิน',
      collection: 'app_notifications',
      priority: 2,
      probeKey: 'notifications',
    ),

    // van4
    EcosystemHealthPoint(
      id: 'V4-PROJECT-ROI',
      app: EcosystemHealthApp.van4,
      titleTh: 'บัญชีโปรเจกต์ / ROI',
      detailTh: 'หน้าโหลด project_finance — ถ้า unavailable จะแดง (ตามจอที่เคยหลุด)',
      collection: 'project_finance',
      priority: 1,
      probeKey: 'project_finance',
    ),
    EcosystemHealthPoint(
      id: 'V4-ORDERS',
      app: EcosystemHealthApp.van4,
      titleTh: 'Dashboard ออเดอร์',
      detailTh: 'แอดมินอ่านรายการ orders',
      collection: 'orders',
      priority: 1,
      probeKey: 'orders',
    ),
    EcosystemHealthPoint(
      id: 'V4-SUPPORT',
      app: EcosystemHealthApp.van4,
      titleTh: 'งานติดต่อแอดมิน',
      detailTh: 'admin_support_tickets inbox',
      collection: 'admin_support_tickets',
      priority: 1,
      probeKey: 'support',
    ),
    EcosystemHealthPoint(
      id: 'V4-PROMO',
      app: EcosystemHealthApp.van4,
      titleTh: 'โปรโมชั่น / คูปอง (แอดมิน)',
      detailTh: 'เขียน/อ่าน coupons, promotion_display_config',
      collection: 'coupons / promotion_display_config',
      priority: 2,
      probeKey: 'coupons',
    ),
    EcosystemHealthPoint(
      id: 'V4-CHAT',
      app: EcosystemHealthApp.van4,
      titleTh: 'แชทภายในแอดมิน',
      detailTh: 'admin_internal_threads — รายงานจากจอเมื่อ error',
      collection: 'admin_internal_threads',
      priority: 2,
      probeKey: 'admin_chat',
    ),
    EcosystemHealthPoint(
      id: 'V4-WITHDRAW',
      app: EcosystemHealthApp.van4,
      titleTh: 'คิวถอนเงิน',
      detailTh: 'withdraw_requests',
      collection: 'withdraw_requests',
      priority: 2,
      probeKey: 'withdraw',
    ),
  ];

  static String appLabelTh(EcosystemHealthApp app) {
    return switch (app) {
      EcosystemHealthApp.shared => 'โครงสร้างร่วม',
      EcosystemHealthApp.van1 => 'van1 ร้าน',
      EcosystemHealthApp.van2 => 'van2 ลูกค้า',
      EcosystemHealthApp.van3 => 'van3 ไรเดอร์',
      EcosystemHealthApp.van4 => 'van4 แอดมิน',
    };
  }
}
