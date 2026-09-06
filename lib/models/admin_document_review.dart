/// ฟิลด์เอกสารที่แอดมินตรวจก่อนอนุมัติร้าน/ไรเดอร์
class AdminDocumentFieldDef {
  const AdminDocumentFieldDef({
    required this.key,
    required this.labelTh,
    required this.imageUrlKey,
    this.collection = 'registration',
  });

  final String key;
  final String labelTh;
  final String imageUrlKey;
  /// `registration` | `contract` | `rider`
  final String collection;
}

abstract final class AdminShopDocumentFields {
  static const shopImage = AdminDocumentFieldDef(
    key: 'shopImageUrl',
    labelTh: 'รูปหน้าร้าน',
    imageUrlKey: 'shopImageUrl',
  );
  static const bookBank = AdminDocumentFieldDef(
    key: 'bookBankImageUrl',
    labelTh: 'สมุดบัญชีธนาคาร',
    imageUrlKey: 'bookBankImageUrl',
  );
  static const idCardFront = AdminDocumentFieldDef(
    key: 'contract:idCardFrontImageUrl',
    labelTh: 'บัตรประชาชน (หน้า)',
    imageUrlKey: 'idCardFrontImageUrl',
    collection: 'contract',
  );
  static const idCardBack = AdminDocumentFieldDef(
    key: 'contract:idCardBackImageUrl',
    labelTh: 'บัตรประชาชน (หลัง)',
    imageUrlKey: 'idCardBackImageUrl',
    collection: 'contract',
  );
  static const signature = AdminDocumentFieldDef(
    key: 'contract:signatureImageUrl',
    labelTh: 'ลายเซ็นสัญญา',
    imageUrlKey: 'signatureImageUrl',
    collection: 'contract',
  );

  static const all = <AdminDocumentFieldDef>[
    shopImage,
    bookBank,
    idCardFront,
    idCardBack,
    signature,
  ];

  static AdminDocumentFieldDef? byKey(String key) {
    for (final field in all) {
      if (field.key == key) {
        return field;
      }
    }
    return null;
  }
}

abstract final class AdminRiderDocumentFields {
  static const idCardFront = AdminDocumentFieldDef(
    key: 'idCardFrontImageUrl',
    labelTh: 'บัตรประชาชน (หน้า)',
    imageUrlKey: 'idCardFrontImageUrl',
    collection: 'rider',
  );
  static const idCardBack = AdminDocumentFieldDef(
    key: 'idCardBackImageUrl',
    labelTh: 'บัตรประชาชน (หลัง)',
    imageUrlKey: 'idCardBackImageUrl',
    collection: 'rider',
  );
  static const driverLicense = AdminDocumentFieldDef(
    key: 'driverLicenseImageUrl',
    labelTh: 'ใบขับขี่',
    imageUrlKey: 'driverLicenseImageUrl',
    collection: 'rider',
  );
  static const motorcycle = AdminDocumentFieldDef(
    key: 'motorcycleImageUrl',
    labelTh: 'รูปยานพาหนะ',
    imageUrlKey: 'motorcycleImageUrl',
    collection: 'rider',
  );
  static const bookBank = AdminDocumentFieldDef(
    key: 'bookBankImageUrl',
    labelTh: 'สมุดบัญชีธนาคาร',
    imageUrlKey: 'bookBankImageUrl',
    collection: 'rider',
  );
  static const profilePhoto = AdminDocumentFieldDef(
    key: 'profilePhotoUrl',
    labelTh: 'รูปโปรไฟล์',
    imageUrlKey: 'profilePhotoUrl',
    collection: 'rider',
  );

  static const all = <AdminDocumentFieldDef>[
    idCardFront,
    idCardBack,
    driverLicense,
    motorcycle,
    bookBank,
    profilePhoto,
  ];

  static AdminDocumentFieldDef? byKey(String key) {
    for (final field in all) {
      if (field.key == key) {
        return field;
      }
    }
    return null;
  }
}

String documentReviewStatusLabelTh(String? status) {
  switch (status) {
    case 'resubmit_requested':
      return 'รอส่งเอกสารใหม่';
    case 'resubmitted':
      return 'ส่งเอกสารใหม่แล้ว';
    case 'approved':
      return 'เอกสารผ่าน';
    default:
      return 'รอตรวจ';
  }
}
