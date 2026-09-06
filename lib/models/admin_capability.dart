/// Work-topic IDs stored on `admins.allowedCaps`.
class AdminCapability {
  AdminCapability._();

  static const String overview = 'overview';
  static const String orders = 'orders';
  static const String shops = 'shops';
  static const String riders = 'riders';
  static const String customers = 'customers';
  static const String promotions = 'promotions';
  static const String workInbox = 'work_inbox';
  static const String withdraw = 'withdraw';
  static const String social = 'social';
  static const String branches = 'branches';
  static const String homeShelves = 'home_shelves';
  static const String pricing = 'pricing';
  static const String catalog = 'catalog';
  static const String announcements = 'announcements';
  static const String settlementGp = 'settlement_gp';
  static const String creditHub = 'credit_hub';
  static const String financeRoi = 'finance_roi';
  static const String taxCompliance = 'tax_compliance';
  static const String ecosystemHealth = 'ecosystem_health';
  static const String teamPermissions = 'team_permissions';
  static const String kycCompliance = 'kyc_compliance';
  static const String disputeHub = 'dispute_hub';
  static const String opsReports = 'ops_reports';

  /// Menus branch_admin already had before allowedCaps existed.
  static const List<String> legacyBranchAdminCaps = <String>[
    overview,
    orders,
    shops,
    riders,
    customers,
    promotions,
    workInbox,
    withdraw,
    social,
  ];

  static const List<AdminCapabilityTopic> topics = <AdminCapabilityTopic>[
    AdminCapabilityTopic(id: overview, label: 'ภาพรวม / งานสด / ปัญหา'),
    AdminCapabilityTopic(id: orders, label: 'จัดการออเดอร์'),
    AdminCapabilityTopic(id: shops, label: 'ร้านค้า + อนุมัติร้าน'),
    AdminCapabilityTopic(id: riders, label: 'จัดการไรเดอร์'),
    AdminCapabilityTopic(id: customers, label: 'จัดการลูกค้า'),
    AdminCapabilityTopic(id: promotions, label: 'โปรโมชั่นและคูปอง'),
    AdminCapabilityTopic(id: workInbox, label: 'งานแอดมินรวม / แชทติดต่อ'),
    AdminCapabilityTopic(id: withdraw, label: 'คิวถอนเงิน + นำเข้า CSV'),
    AdminCapabilityTopic(id: social, label: 'โซเชียลแดชบอร์ด'),
    AdminCapabilityTopic(id: branches, label: 'จัดการสาขา'),
    AdminCapabilityTopic(id: homeShelves, label: 'หน้าแรก van2'),
    AdminCapabilityTopic(id: pricing, label: 'ตั้งค่าราคาและค่าส่ง'),
    AdminCapabilityTopic(id: catalog, label: 'จัดการหมวดสินค้า'),
    AdminCapabilityTopic(id: announcements, label: 'ประกาศแจ้งเตือนทั้งระบบ'),
    AdminCapabilityTopic(id: settlementGp, label: 'ตั้งค่าอัตราหัก GP'),
    AdminCapabilityTopic(id: creditHub, label: 'เครดิตระบบ'),
    AdminCapabilityTopic(id: financeRoi, label: 'บัญชีโปรเจกต์ / ROI'),
    AdminCapabilityTopic(id: taxCompliance, label: 'ศูนย์ภาษี / VAT'),
    AdminCapabilityTopic(id: kycCompliance, label: 'ศูนย์ยืนยันตัวตน KYC'),
    AdminCapabilityTopic(id: disputeHub, label: 'ศูนย์ข้อพิพาท / เคลม'),
    AdminCapabilityTopic(id: opsReports, label: 'รายงาน Ops'),
    AdminCapabilityTopic(id: ecosystemHealth, label: 'สุขภาพระบบ'),
  ];

  static Set<String> allIds() {
    return topics.map((topic) => topic.id).toSet();
  }

  static Set<String> parse(dynamic raw) {
    if (raw is! List) {
      return <String>{};
    }
    final allowed = allIds();
    return raw
        .map((item) => item.toString().trim())
        .where((id) => id.isNotEmpty && allowed.contains(id))
        .toSet();
  }

  static List<String> intersect(Iterable<String> requested, Iterable<String> allowed) {
    final allow = allowed.toSet();
    return requested.where(allow.contains).toSet().toList()..sort();
  }
}

class AdminCapabilityTopic {
  const AdminCapabilityTopic({required this.id, required this.label});

  final String id;
  final String label;
}
