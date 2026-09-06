import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../models/admin_tax_config.dart';
import '../models/tax_income_period.dart';
import '../models/tax_ledger_entry.dart';
import '../models/tax_vat_period.dart';
import '../services/admin_project_finance_service.dart';

class AdminTaxService {
  AdminTaxService._();

  static const String taxConfigPath = 'platform_config/tax';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  static DocumentReference<Map<String, dynamic>> get _taxConfigRef =>
      _firestore.doc(taxConfigPath);

  static CollectionReference<Map<String, dynamic>> get _ledgerRef =>
      _firestore.collection('tax_ledger_entries');

  static CollectionReference<Map<String, dynamic>> get _vatPeriodsRef =>
      _firestore.collection('tax_vat_periods');

  static CollectionReference<Map<String, dynamic>> get _incomePeriodsRef =>
      _firestore.collection('tax_income_periods');

  static String periodIdFromDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static Stream<AdminTaxConfig> streamTaxConfig() {
    return _taxConfigRef.snapshots().map(
          (snapshot) => AdminTaxConfig.fromMap(snapshot.data()),
        );
  }

  static Future<AdminTaxConfig> fetchTaxConfig() async {
    final snap = await _taxConfigRef.get();
    return AdminTaxConfig.fromMap(snap.data());
  }

  static Future<void> saveTaxConfig(AdminTaxConfig config) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('ต้องเข้าสู่ระบบแอดมินก่อน');
    }
    await _taxConfigRef.set(
      <String, dynamic>{
        ...config.toMap(adminUid: user.uid, adminEmail: user.email),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Stream<List<TaxLedgerEntry>> streamLedgerForPeriod(String periodId) {
    return _ledgerRef
        .where('periodId', isEqualTo: periodId)
        .snapshots()
        .map(_mapLedgerDocs);
  }

  static Future<List<TaxLedgerEntry>> fetchLedgerForPeriod(String periodId) async {
    final snap = await _ledgerRef.where('periodId', isEqualTo: periodId).get();
    return _mapLedgerDocs(snap);
  }

  static List<TaxLedgerEntry> _mapLedgerDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.toList(growable: false)
      ..sort((a, b) {
        final aAt = a.data()['at'];
        final bAt = b.data()['at'];
        if (aAt is Timestamp && bAt is Timestamp) {
          return bAt.compareTo(aAt);
        }
        return 0;
      });
    return docs.map(TaxLedgerEntry.fromSnapshot).toList(growable: false);
  }

  static Future<void> ensureVatPeriodOpen(String periodId) async {
    final ref = _vatPeriodsRef.doc(periodId);
    final snap = await ref.get();
    if (snap.exists) {
      return;
    }
    await ref.set(
      <String, dynamic>{
        'status': vatPeriodStatusToFirestore(TaxVatPeriodStatus.open),
        'outputVatTotal': 0,
        'inputVatTotal': 0,
        'netVatPayable': 0,
        'outputLineCount': 0,
        'inputLineCount': 0,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Stream<List<TaxVatPeriod>> streamVatPeriods() {
    return _vatPeriodsRef.snapshots().map((snapshot) {
      final docs = snapshot.docs.toList(growable: false)
        ..sort((a, b) => b.id.compareTo(a.id));
      return docs.map(TaxVatPeriod.fromSnapshot).toList(growable: false);
    });
  }

  static Future<void> setVatPeriodStatus(
    String periodId,
    TaxVatPeriodStatus status,
  ) async {
    await ensureVatPeriodOpen(periodId);
    await _vatPeriodsRef.doc(periodId).set(
      <String, dynamic>{
        'status': vatPeriodStatusToFirestore(status),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<Map<String, dynamic>> closeVatPeriodViaCf(String periodId) async {
    final callable = _functions.httpsCallable('adminCloseVatPeriod');
    final result = await callable.call(<String, dynamic>{'periodId': periodId});
    final data = result.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return <String, dynamic>{'success': true};
  }

  static Future<void> voidLedgerEntryViaCf({
    required String entryId,
    String? reason,
  }) async {
    final callable = _functions.httpsCallable('adminVoidTaxLedgerEntry');
    await callable.call(<String, dynamic>{
      'entryId': entryId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  static Future<void> createManualEntry({
    required String periodId,
    required TaxLedgerEntryType entryType,
    TaxLedgerRevenueCategory? revenueCategory,
    required String title,
    required double amountGross,
    required AdminTaxConfig taxConfig,
    bool taxDeductible = true,
    String? supplierTaxId,
    String? invoiceNumber,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('ต้องเข้าสู่ระบบแอดมินก่อน');
    }
    await ensureVatPeriodOpen(periodId);

    final split = entryType == TaxLedgerEntryType.inputVat
        ? TaxAmountSplit.compute(
            grossOrNet: amountGross,
            config: taxConfig,
            inputIsGross: true,
          )
        : TaxAmountSplit.compute(
            grossOrNet: amountGross,
            config: taxConfig,
          );

    final docRef = _ledgerRef.doc();
    await docRef.set(<String, dynamic>{
      'periodId': periodId,
      'entryType': entryTypeToFirestore(entryType),
      if (revenueCategory != null)
        'revenueCategory': revenueCategoryToFirestore(revenueCategory),
      'title': title.trim(),
      'amountGross': split.amountGross,
      'amountExVat': split.amountExVat,
      'vatAmount': split.vatAmount,
      'vatRate': split.vatRate,
      'taxDeductible': taxDeductible,
      'source': entryType == TaxLedgerEntryType.adjustment
          ? sourceToFirestore(TaxLedgerSource.adjustment)
          : sourceToFirestore(TaxLedgerSource.manual),
      'status': 'active',
      if (supplierTaxId != null && supplierTaxId.trim().isNotEmpty)
        'supplierTaxId': supplierTaxId.trim(),
      if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
        'invoiceNumber': invoiceNumber.trim(),
      'at': FieldValue.serverTimestamp(),
      'createdBy': user.email ?? user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> syncExpenseLedger({
    required String expenseId,
    required String title,
    required double amountBaht,
    required AdminTaxConfig taxConfig,
    double? amountExVat,
    double? vatAmount,
    double? vatRate,
    String? supplierTaxId,
    String? invoiceNumber,
    DateTime? invoiceDate,
    bool taxDeductible = true,
    DateTime? at,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('ต้องเข้าสู่ระบบแอดมินก่อน');
    }

    final when = at ?? DateTime.now();
    final periodId = periodIdFromDate(when);
    await ensureVatPeriodOpen(periodId);

    final exVat = amountExVat ?? amountBaht;
    final vat = vatAmount ?? 0;
    final gross = amountExVat != null ? exVat + vat : amountBaht;
    final rate = vatRate ?? taxConfig.defaultVatRate;

    await _ledgerRef.doc('expense_$expenseId').set(
      <String, dynamic>{
        'periodId': periodId,
        'entryType': entryTypeToFirestore(TaxLedgerEntryType.inputVat),
        'expenseId': expenseId,
        'title': title.trim(),
        'amountGross': _roundMoney(gross),
        'amountExVat': _roundMoney(exVat),
        'vatAmount': _roundMoney(vat),
        'vatRate': rate,
        'taxDeductible': taxDeductible,
        'source': sourceToFirestore(TaxLedgerSource.expenseImport),
        'status': 'active',
        if (supplierTaxId != null && supplierTaxId.trim().isNotEmpty)
          'supplierTaxId': supplierTaxId.trim(),
        if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
          'invoiceNumber': invoiceNumber.trim(),
        if (invoiceDate != null) 'invoiceDate': Timestamp.fromDate(invoiceDate),
        'at': Timestamp.fromDate(when),
        'createdBy': user.email ?? user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<void> deleteExpenseLedger(String expenseId) async {
    await _ledgerRef.doc('expense_$expenseId').delete();
  }

  static TaxPeriodSummary summarizePeriod(List<TaxLedgerEntry> entries) {
    var outputVat = 0.0;
    var inputVat = 0.0;
    var revenueExVat = 0.0;
    var expenseExVat = 0.0;
    var outputCount = 0;
    var inputCount = 0;

    for (final entry in entries) {
      if (entry.status != TaxLedgerStatus.active) {
        continue;
      }
      if (entry.isInput) {
        inputVat += entry.vatAmount;
        if (entry.taxDeductible) {
          expenseExVat += entry.amountExVat;
        }
        inputCount += 1;
      } else {
        outputVat += entry.vatAmount;
        revenueExVat += entry.amountExVat;
        outputCount += 1;
      }
    }

    return TaxPeriodSummary(
      outputVatTotal: _roundMoney(outputVat),
      inputVatTotal: _roundMoney(inputVat),
      netVatPayable: _roundMoney(outputVat - inputVat),
      revenueExVat: _roundMoney(revenueExVat),
      expenseDeductible: _roundMoney(expenseExVat),
      outputLineCount: outputCount,
      inputLineCount: inputCount,
    );
  }

  static Future<TaxIncomePeriod> buildOrSaveIncomePeriod(String periodId) async {
    final match = RegExp(r'^(\d{4})-q(\d)$').firstMatch(periodId);
    if (match == null) {
      throw ArgumentError('periodId ต้องเป็น yyyy-qN');
    }
    final year = int.parse(match.group(1)!);
    final quarter = int.parse(match.group(2)!);
    final startMonth = (quarter - 1) * 3 + 1;
    final linked = List<String>.generate(
      3,
      (index) => '$year-${(startMonth + index).toString().padLeft(2, '0')}',
      growable: false,
    );

    var revenueExVat = 0.0;
    var expenseDeductible = 0.0;

    for (final vatPeriodId in linked) {
      final entries = await fetchLedgerForPeriod(vatPeriodId);
      final summary = summarizePeriod(entries);
      revenueExVat += summary.revenueExVat;
      expenseDeductible += summary.expenseDeductible;
    }

    final estimatedTaxableProfit =
        _roundMoney(revenueExVat - expenseDeductible);
    final doc = <String, dynamic>{
      'revenueExVat': revenueExVat,
      'expenseDeductible': expenseDeductible,
      'estimatedTaxableProfit': estimatedTaxableProfit,
      'linkedVatPeriodIds': linked,
      'status': 'open',
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _incomePeriodsRef.doc(periodId).set(doc, SetOptions(merge: true));
    final snap = await _incomePeriodsRef.doc(periodId).get();
    return TaxIncomePeriod.fromSnapshot(snap);
  }

  static Stream<List<TaxIncomePeriod>> streamIncomePeriods() {
    return _incomePeriodsRef.snapshots().map((snapshot) {
      final docs = snapshot.docs.toList(growable: false)
        ..sort((a, b) => b.id.compareTo(a.id));
      return docs.map(TaxIncomePeriod.fromSnapshot).toList(growable: false);
    });
  }

  static Future<void> exportVatCsvBundle(String periodId) async {
    final entries = await fetchLedgerForPeriod(periodId);
    final active = entries
        .where((entry) => entry.status == TaxLedgerStatus.active)
        .toList(growable: false);
    final summary = summarizePeriod(active);

    final sales = active.where((entry) => entry.isOutput).toList(growable: false);
    final purchases = active.where((entry) => entry.isInput).toList(growable: false);

    final files = <XFile>[
      XFile.fromData(
        utf8.encode(_buildSalesRegisterCsv(sales)),
        mimeType: 'text/csv',
        name: 'vat_sales_register_$periodId.csv',
      ),
      XFile.fromData(
        utf8.encode(_buildPurchaseRegisterCsv(purchases)),
        mimeType: 'text/csv',
        name: 'vat_purchase_register_$periodId.csv',
      ),
      XFile.fromData(
        utf8.encode(_buildVatSummaryCsv(periodId, summary)),
        mimeType: 'text/csv',
        name: 'vat_summary_$periodId.csv',
      ),
    ];

    await Share.shareXFiles(
      files,
      subject: 'สรุป VAT $periodId',
      text: 'ส่งออก CSV งวด VAT $periodId สำหรับบัญชี',
    );
  }

  static Future<void> exportIncomePnlCsv(String periodId) async {
    final income = await buildOrSaveIncomePeriod(periodId);
    final linked = income.linkedVatPeriodIds;
    final revenueByCategory = <String, double>{};
    final expenseByCategory = <String, double>{};

    for (final vatPeriodId in linked) {
      final entries = await fetchLedgerForPeriod(vatPeriodId);
      for (final entry in entries) {
        if (entry.status != TaxLedgerStatus.active) {
          continue;
        }
        if (entry.isOutput) {
          final key = entry.revenueCategory != null
              ? revenueCategoryToFirestore(entry.revenueCategory!)
              : 'other';
          revenueByCategory[key] =
              (revenueByCategory[key] ?? 0) + entry.amountExVat;
        } else if (entry.taxDeductible) {
          final key = entry.title ?? 'expense';
          expenseByCategory[key] =
              (expenseByCategory[key] ?? 0) + entry.amountExVat;
        }
      }
    }

    final buffer = StringBuffer()
      ..writeln('section,key,amount_ex_vat')
      ..writeln('summary,revenue_ex_vat,${income.revenueExVat.toStringAsFixed(2)}')
      ..writeln('summary,expense_deductible,${income.expenseDeductible.toStringAsFixed(2)}')
      ..writeln('summary,estimated_taxable_profit,${income.estimatedTaxableProfit.toStringAsFixed(2)}');

    revenueByCategory.forEach((key, value) {
      buffer.writeln('revenue,$key,${value.toStringAsFixed(2)}');
    });
    expenseByCategory.forEach((key, value) {
      final safeKey = key.replaceAll(',', ' ');
      buffer.writeln('expense,$safeKey,${value.toStringAsFixed(2)}');
    });

    await Share.shareXFiles(
      <XFile>[
        XFile.fromData(
          utf8.encode(buffer.toString()),
          mimeType: 'text/csv',
          name: 'income_pnl_$periodId.csv',
        ),
      ],
      subject: 'สรุปภาษีเงินได้ $periodId',
      text: 'ส่งออก P&L รายไตรมาส $periodId',
    );
  }

  static String _buildSalesRegisterCsv(List<TaxLedgerEntry> sales) {
    final buffer = StringBuffer()
      ..writeln('date,order_id,type,gross,ex_vat,vat,source');
    for (final entry in sales) {
      buffer.writeln([
        _formatDate(entry.at),
        entry.orderId ?? entry.withdrawRequestId ?? '',
        entryTypeToFirestore(entry.entryType),
        entry.amountGross.toStringAsFixed(2),
        entry.amountExVat.toStringAsFixed(2),
        entry.vatAmount.toStringAsFixed(2),
        sourceToFirestore(entry.source),
      ].join(','));
    }
    return buffer.toString();
  }

  static String _buildPurchaseRegisterCsv(List<TaxLedgerEntry> purchases) {
    final buffer = StringBuffer()
      ..writeln('date,supplier_tax_id,invoice_no,gross,ex_vat,vat,deductible,title');
    for (final entry in purchases) {
      buffer.writeln([
        _formatDate(entry.at),
        entry.supplierTaxId ?? '',
        entry.invoiceNumber ?? '',
        entry.amountGross.toStringAsFixed(2),
        entry.amountExVat.toStringAsFixed(2),
        entry.vatAmount.toStringAsFixed(2),
        entry.taxDeductible ? 'yes' : 'no',
        (entry.title ?? '').replaceAll(',', ' '),
      ].join(','));
    }
    return buffer.toString();
  }

  static String _buildVatSummaryCsv(String periodId, TaxPeriodSummary summary) {
    return '''
period,output_vat,input_vat,net_vat_payable,output_lines,input_lines
$periodId,${summary.outputVatTotal.toStringAsFixed(2)},${summary.inputVatTotal.toStringAsFixed(2)},${summary.netVatPayable.toStringAsFixed(2)},${summary.outputLineCount},${summary.inputLineCount}
''';
  }

  static String _formatDate(DateTime? value) {
    if (value == null) {
      return '';
    }
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  static double _roundMoney(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}

class TaxPeriodSummary {
  const TaxPeriodSummary({
    required this.outputVatTotal,
    required this.inputVatTotal,
    required this.netVatPayable,
    required this.revenueExVat,
    required this.expenseDeductible,
    required this.outputLineCount,
    required this.inputLineCount,
  });

  final double outputVatTotal;
  final double inputVatTotal;
  final double netVatPayable;
  final double revenueExVat;
  final double expenseDeductible;
  final int outputLineCount;
  final int inputLineCount;
}

String formatBahtTax(double value) => formatBaht(value);
