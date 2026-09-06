import 'package:cloud_firestore/cloud_firestore.dart';

enum TaxIncomePeriodStatus {
  open,
  review,
  closed,
}

class TaxIncomePeriod {
  const TaxIncomePeriod({
    required this.id,
    required this.status,
    required this.revenueExVat,
    required this.expenseDeductible,
    required this.estimatedTaxableProfit,
    required this.linkedVatPeriodIds,
    this.closedAt,
  });

  final String id;
  final TaxIncomePeriodStatus status;
  final double revenueExVat;
  final double expenseDeductible;
  final double estimatedTaxableProfit;
  final List<String> linkedVatPeriodIds;
  final DateTime? closedAt;

  factory TaxIncomePeriod.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final linked = data['linkedVatPeriodIds'];
    return TaxIncomePeriod(
      id: doc.id,
      status: _parseStatus(data['status']),
      revenueExVat: _readMoney(data['revenueExVat']),
      expenseDeductible: _readMoney(data['expenseDeductible']),
      estimatedTaxableProfit: _readMoney(data['estimatedTaxableProfit']),
      linkedVatPeriodIds: linked is List
          ? linked.map((item) => item.toString()).toList(growable: false)
          : const <String>[],
      closedAt: _readDateTime(data['closedAt']),
    );
  }
}

TaxIncomePeriodStatus _parseStatus(Object? raw) {
  switch (raw?.toString()) {
    case 'review':
      return TaxIncomePeriodStatus.review;
    case 'closed':
      return TaxIncomePeriodStatus.closed;
    default:
      return TaxIncomePeriodStatus.open;
  }
}

String incomePeriodIdFromDate(DateTime date) {
  final quarter = ((date.month - 1) ~/ 3) + 1;
  return '${date.year}-q$quarter';
}

List<String> linkedVatPeriodIdsForQuarter(DateTime date) {
  final quarter = ((date.month - 1) ~/ 3);
  final startMonth = quarter * 3 + 1;
  return List<String>.generate(3, (index) {
    final month = startMonth + index;
    return '${date.year}-${month.toString().padLeft(2, '0')}';
  }, growable: false);
}

double _readMoney(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return 0;
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
