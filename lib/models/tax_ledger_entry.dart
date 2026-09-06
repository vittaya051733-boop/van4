import 'package:cloud_firestore/cloud_firestore.dart';

enum TaxLedgerEntryType {
  platformRevenue,
  inputVat,
  withdrawFee,
  adjustment,
}

enum TaxLedgerRevenueCategory {
  gp,
  shippingPlatform,
  marketService,
  marketCollection,
  withdrawFee,
  other,
}

enum TaxLedgerSource {
  orderDelivered,
  manual,
  expenseImport,
  withdrawConfirmed,
  adjustment,
}

enum TaxLedgerStatus {
  active,
  voided,
}

class TaxLedgerEntry {
  const TaxLedgerEntry({
    required this.id,
    required this.periodId,
    required this.entryType,
    this.revenueCategory,
    this.orderId,
    this.withdrawRequestId,
    this.expenseId,
    this.title,
    required this.amountGross,
    required this.amountExVat,
    required this.vatAmount,
    required this.vatRate,
    this.taxDeductible = true,
    required this.source,
    required this.status,
    this.at,
    this.createdBy,
    this.supplierTaxId,
    this.invoiceNumber,
  });

  final String id;
  final String periodId;
  final TaxLedgerEntryType entryType;
  final TaxLedgerRevenueCategory? revenueCategory;
  final String? orderId;
  final String? withdrawRequestId;
  final String? expenseId;
  final String? title;
  final double amountGross;
  final double amountExVat;
  final double vatAmount;
  final double vatRate;
  final bool taxDeductible;
  final TaxLedgerSource source;
  final TaxLedgerStatus status;
  final DateTime? at;
  final String? createdBy;
  final String? supplierTaxId;
  final String? invoiceNumber;

  bool get isOutput =>
      entryType == TaxLedgerEntryType.platformRevenue ||
      entryType == TaxLedgerEntryType.withdrawFee ||
      (entryType == TaxLedgerEntryType.adjustment && vatAmount >= 0);

  bool get isInput => entryType == TaxLedgerEntryType.inputVat;

  factory TaxLedgerEntry.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return TaxLedgerEntry(
      id: doc.id,
      periodId: (data['periodId'] ?? '').toString(),
      entryType: _parseEntryType(data['entryType']),
      revenueCategory: _parseRevenueCategory(data['revenueCategory']),
      orderId: _nullableString(data['orderId']),
      withdrawRequestId: _nullableString(data['withdrawRequestId']),
      expenseId: _nullableString(data['expenseId']),
      title: _nullableString(data['title']),
      amountGross: _readMoney(data['amountGross']),
      amountExVat: _readMoney(data['amountExVat']),
      vatAmount: _readMoney(data['vatAmount']),
      vatRate: _readMoney(data['vatRate']),
      taxDeductible: data['taxDeductible'] != false,
      source: _parseSource(data['source']),
      status: data['status'] == 'void'
          ? TaxLedgerStatus.voided
          : TaxLedgerStatus.active,
      at: _readDateTime(data['at']),
      createdBy: _nullableString(data['createdBy']),
      supplierTaxId: _nullableString(data['supplierTaxId']),
      invoiceNumber: _nullableString(data['invoiceNumber']),
    );
  }
}

TaxLedgerEntryType _parseEntryType(Object? raw) {
  switch (raw?.toString()) {
    case 'input_vat':
      return TaxLedgerEntryType.inputVat;
    case 'withdraw_fee':
      return TaxLedgerEntryType.withdrawFee;
    case 'adjustment':
      return TaxLedgerEntryType.adjustment;
    default:
      return TaxLedgerEntryType.platformRevenue;
  }
}

TaxLedgerRevenueCategory? _parseRevenueCategory(Object? raw) {
  switch (raw?.toString()) {
    case 'gp':
      return TaxLedgerRevenueCategory.gp;
    case 'shipping_platform':
      return TaxLedgerRevenueCategory.shippingPlatform;
    case 'market_service':
      return TaxLedgerRevenueCategory.marketService;
    case 'market_collection':
      return TaxLedgerRevenueCategory.marketCollection;
    case 'withdraw_fee':
      return TaxLedgerRevenueCategory.withdrawFee;
    case 'other':
      return TaxLedgerRevenueCategory.other;
    default:
      return null;
  }
}

TaxLedgerSource _parseSource(Object? raw) {
  switch (raw?.toString()) {
    case 'manual':
      return TaxLedgerSource.manual;
    case 'expense_import':
      return TaxLedgerSource.expenseImport;
    case 'withdraw_confirmed':
      return TaxLedgerSource.withdrawConfirmed;
    case 'adjustment':
      return TaxLedgerSource.adjustment;
    default:
      return TaxLedgerSource.orderDelivered;
  }
}

String entryTypeToFirestore(TaxLedgerEntryType type) {
  switch (type) {
    case TaxLedgerEntryType.inputVat:
      return 'input_vat';
    case TaxLedgerEntryType.withdrawFee:
      return 'withdraw_fee';
    case TaxLedgerEntryType.adjustment:
      return 'adjustment';
    case TaxLedgerEntryType.platformRevenue:
      return 'platform_revenue';
  }
}

String revenueCategoryToFirestore(TaxLedgerRevenueCategory category) {
  switch (category) {
    case TaxLedgerRevenueCategory.gp:
      return 'gp';
    case TaxLedgerRevenueCategory.shippingPlatform:
      return 'shipping_platform';
    case TaxLedgerRevenueCategory.marketService:
      return 'market_service';
    case TaxLedgerRevenueCategory.marketCollection:
      return 'market_collection';
    case TaxLedgerRevenueCategory.withdrawFee:
      return 'withdraw_fee';
    case TaxLedgerRevenueCategory.other:
      return 'other';
  }
}

String sourceToFirestore(TaxLedgerSource source) {
  switch (source) {
    case TaxLedgerSource.manual:
      return 'manual';
    case TaxLedgerSource.expenseImport:
      return 'expense_import';
    case TaxLedgerSource.withdrawConfirmed:
      return 'withdraw_confirmed';
    case TaxLedgerSource.adjustment:
      return 'adjustment';
    case TaxLedgerSource.orderDelivered:
      return 'order_delivered';
  }
}

String revenueCategoryLabelTh(TaxLedgerRevenueCategory category) {
  switch (category) {
    case TaxLedgerRevenueCategory.gp:
      return 'GP สินค้า';
    case TaxLedgerRevenueCategory.shippingPlatform:
      return 'ส่วนแบ่งค่าส่ง';
    case TaxLedgerRevenueCategory.marketService:
      return 'ค่าธรรมเนียมแพลตฟอร์ม/บิล';
    case TaxLedgerRevenueCategory.marketCollection:
      return 'ค่ารวบรวมหลายร้าน';
    case TaxLedgerRevenueCategory.withdrawFee:
      return 'ค่าธรรมเนียมถอน';
    case TaxLedgerRevenueCategory.other:
      return 'อื่นๆ';
  }
}

String entryTypeLabelTh(TaxLedgerEntryType type) {
  switch (type) {
    case TaxLedgerEntryType.platformRevenue:
      return 'รายได้แพลตฟอร์ม';
    case TaxLedgerEntryType.inputVat:
      return 'ภาษีซื้อ';
    case TaxLedgerEntryType.withdrawFee:
      return 'ค่าธรรมเนียมถอน';
    case TaxLedgerEntryType.adjustment:
      return 'ปรับปรุง';
  }
}

double _readMoney(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.replaceAll(',', '').trim()) ?? 0;
  }
  return 0;
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) {
    return null;
  }
  return text;
}

DateTime? _readDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}
