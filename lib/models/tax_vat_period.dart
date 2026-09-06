import 'package:cloud_firestore/cloud_firestore.dart';

enum TaxVatPeriodStatus {
  open,
  review,
  closed,
}

class TaxVatPeriod {
  const TaxVatPeriod({
    required this.id,
    required this.status,
    required this.outputVatTotal,
    required this.inputVatTotal,
    required this.netVatPayable,
    required this.outputLineCount,
    required this.inputLineCount,
    this.closedAt,
    this.closedBy,
  });

  final String id;
  final TaxVatPeriodStatus status;
  final double outputVatTotal;
  final double inputVatTotal;
  final double netVatPayable;
  final int outputLineCount;
  final int inputLineCount;
  final DateTime? closedAt;
  final String? closedBy;

  factory TaxVatPeriod.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return TaxVatPeriod(
      id: doc.id,
      status: _parseStatus(data['status']),
      outputVatTotal: _readMoney(data['outputVatTotal']),
      inputVatTotal: _readMoney(data['inputVatTotal']),
      netVatPayable: _readMoney(data['netVatPayable']),
      outputLineCount: _readInt(data['outputLineCount']),
      inputLineCount: _readInt(data['inputLineCount']),
      closedAt: _readDateTime(data['closedAt']),
      closedBy: _nullableString(data['closedBy']),
    );
  }
}

TaxVatPeriodStatus _parseStatus(Object? raw) {
  switch (raw?.toString()) {
    case 'review':
      return TaxVatPeriodStatus.review;
    case 'closed':
      return TaxVatPeriodStatus.closed;
    default:
      return TaxVatPeriodStatus.open;
  }
}

String vatPeriodStatusToFirestore(TaxVatPeriodStatus status) {
  switch (status) {
    case TaxVatPeriodStatus.review:
      return 'review';
    case TaxVatPeriodStatus.closed:
      return 'closed';
    case TaxVatPeriodStatus.open:
      return 'open';
  }
}

String vatPeriodStatusLabelTh(TaxVatPeriodStatus status) {
  switch (status) {
    case TaxVatPeriodStatus.open:
      return 'เปิดรับรายการ';
    case TaxVatPeriodStatus.review:
      return 'ตรวจสอบ';
    case TaxVatPeriodStatus.closed:
      return 'ปิดงวดแล้ว';
  }
}

double _readMoney(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return 0;
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
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
