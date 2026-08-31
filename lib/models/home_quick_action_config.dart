class HomeQuickActionSpec {
  const HomeQuickActionSpec({
    required this.id,
    required this.labelTh,
    this.serviceType,
    this.hidesHomeProducts = false,
  });

  final String id;
  final String labelTh;
  final String? serviceType;
  final bool hidesHomeProducts;

  String get adminSubtitle {
    if (hidesHomeProducts) {
      return 'ปิดแล้วไม่แสดงปุ่ม และไม่แสดงสินค้าหมวดนี้บนหน้าแรก van2';
    }
    return 'ปิดแล้วไม่แสดงปุ่มบนหน้าแรก van2';
  }
}

class HomeQuickActionConfig {
  const HomeQuickActionConfig(this._enabled);

  static const List<HomeQuickActionSpec> specs = <HomeQuickActionSpec>[
    HomeQuickActionSpec(id: 'travel', labelTh: 'เดินทาง'),
    HomeQuickActionSpec(
      id: 'restaurant',
      labelTh: 'ร้านอาหาร',
      serviceType: 'ร้านอาหาร',
      hidesHomeProducts: true,
    ),
    HomeQuickActionSpec(
      id: 'market',
      labelTh: 'ตลาด',
      serviceType: 'ตลาด',
      hidesHomeProducts: true,
    ),
    HomeQuickActionSpec(
      id: 'shop',
      labelTh: 'ร้านค้า',
      serviceType: 'ร้านค้า',
      hidesHomeProducts: true,
    ),
    HomeQuickActionSpec(
      id: 'pharmacy',
      labelTh: 'ร้านขายยา',
      serviceType: 'ร้านขายยา',
      hidesHomeProducts: true,
    ),
    HomeQuickActionSpec(id: 'shop-map', labelTh: 'แผนที่'),
    HomeQuickActionSpec(
      id: 'nationwide-shipping',
      labelTh: 'สินค้าส่งทั่วประเทศ',
    ),
    HomeQuickActionSpec(id: 'more', labelTh: 'เพิ่มเติม'),
  ];

  static const Set<String> ids = <String>{
    'travel',
    'restaurant',
    'market',
    'shop',
    'pharmacy',
    'shop-map',
    'nationwide-shipping',
    'more',
  };

  static const HomeQuickActionConfig defaults = HomeQuickActionConfig(
    <String, bool>{},
  );

  final Map<String, bool> _enabled;

  factory HomeQuickActionConfig.fromEnabledById(Map<String, bool> enabled) {
    return HomeQuickActionConfig(Map<String, bool>.from(enabled));
  }

  factory HomeQuickActionConfig.fromFirestore(Map<String, dynamic>? data) {
    final raw = data?['quickActions'];
    if (raw is! Map) {
      return defaults;
    }

    final enabled = <String, bool>{};
    for (final entry in raw.entries) {
      final id = entry.key.toString().trim();
      if (!ids.contains(id)) {
        continue;
      }
      enabled[id] = entry.value != false;
    }
    return HomeQuickActionConfig(enabled);
  }

  bool isEnabled(String id) => _enabled[id] != false;

  String get signature {
    return specs.map((spec) => '${spec.id}:${isEnabled(spec.id)}').join(',');
  }

  Map<String, bool> get enabledById {
    return <String, bool>{
      for (final spec in specs) spec.id: isEnabled(spec.id),
    };
  }

  int get visibleCount => specs.where((spec) => isEnabled(spec.id)).length;
}
