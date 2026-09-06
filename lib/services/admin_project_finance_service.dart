import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../admin_order_support.dart';
import '../admin_repository.dart';
import '../admin_settlement_support.dart';
import 'admin_tax_service.dart';

class AdminProjectFinanceConfig {
  const AdminProjectFinanceConfig({
    this.initialInvestmentBaht = 0,
    this.productUploadRevenuePerItem = 0,
  });

  final double initialInvestmentBaht;
  final double productUploadRevenuePerItem;

  factory AdminProjectFinanceConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const AdminProjectFinanceConfig();
    }
    return AdminProjectFinanceConfig(
      initialInvestmentBaht: _readMoney(data['initialInvestmentBaht']),
      productUploadRevenuePerItem:
          _readMoney(data['productUploadRevenuePerItem']),
    );
  }

  Map<String, dynamic> toMap({required String adminUid, String? adminEmail}) {
    return <String, dynamic>{
      'initialInvestmentBaht': initialInvestmentBaht,
      'productUploadRevenuePerItem': productUploadRevenuePerItem,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedByUid': adminUid,
      if (adminEmail != null && adminEmail.trim().isNotEmpty)
        'updatedByEmail': adminEmail.trim(),
    };
  }
}

class AdminProjectExpenseRecord {
  const AdminProjectExpenseRecord({
    required this.id,
    required this.title,
    required this.amountBaht,
    this.note,
    this.category,
    this.receiptImageUrl,
    this.createdAt,
    this.createdByEmail,
    this.amountExVat,
    this.vatAmount,
    this.vatRate,
    this.supplierTaxId,
    this.invoiceNumber,
    this.invoiceDate,
    this.taxDeductible = true,
  });

  final String id;
  final String title;
  final double amountBaht;
  final String? note;
  final String? category;
  final String? receiptImageUrl;
  final DateTime? createdAt;
  final String? createdByEmail;
  final double? amountExVat;
  final double? vatAmount;
  final double? vatRate;
  final String? supplierTaxId;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final bool taxDeductible;

  factory AdminProjectExpenseRecord.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    return AdminProjectExpenseRecord(
      id: doc.id,
      title: (data['title'] ?? 'รายจ่าย').toString(),
      amountBaht: _readMoney(data['amountBaht']),
      note: _nullableString(data['note']),
      category: _nullableString(data['category']),
      receiptImageUrl: _nullableString(data['receiptImageUrl']),
      createdAt: _readDateTime(data['createdAt']),
      createdByEmail: _nullableString(data['createdByEmail']),
      amountExVat: _nullableMoney(data['amountExVat']),
      vatAmount: _nullableMoney(data['vatAmount']),
      vatRate: _nullableMoney(data['vatRate']),
      supplierTaxId: _nullableString(data['supplierTaxId']),
      invoiceNumber: _nullableString(data['invoiceNumber']),
      invoiceDate: _readDateTime(data['invoiceDate']),
      taxDeductible: data['taxDeductible'] != false,
    );
  }
}

class AdminProjectFinanceSnapshot {
  const AdminProjectFinanceSnapshot({
    required this.config,
    required this.expenses,
    required this.totalExpensesBaht,
    required this.salesPlatformRevenueBaht,
    required this.productUploadCount,
    required this.productUploadRevenueBaht,
    required this.totalAutoRevenueBaht,
    required this.netProfitBaht,
    required this.roiPercent,
    required this.deliveredOrderCount,
  });

  final AdminProjectFinanceConfig config;
  final List<AdminProjectExpenseRecord> expenses;
  final double totalExpensesBaht;
  final double salesPlatformRevenueBaht;
  final int productUploadCount;
  final double productUploadRevenueBaht;
  final double totalAutoRevenueBaht;
  final double netProfitBaht;
  final double? roiPercent;
  final int deliveredOrderCount;
}

class AdminProjectFinanceService {
  AdminProjectFinanceService._();

  static const String _collection = 'project_finance';
  static const String _configDocId = 'config';
  static const String _expenseRecordType = 'expense';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection(_collection).doc(_configDocId);

  static CollectionReference<Map<String, dynamic>> get _collectionRef =>
      _firestore.collection(_collection);

  static Stream<AdminProjectFinanceConfig> streamConfig() {
    return _configRef.snapshots().map(
          (snapshot) => AdminProjectFinanceConfig.fromMap(snapshot.data()),
        );
  }

  static Stream<List<AdminProjectExpenseRecord>> streamExpenses() {
    return _expensesQuery().snapshots().map(_mapExpenseDocs);
  }

  static Query<Map<String, dynamic>> _expensesQuery() {
    return _collectionRef.where('recordType', isEqualTo: _expenseRecordType);
  }

  static List<AdminProjectExpenseRecord> _mapExpenseDocs(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final docs = snapshot.docs.toList(growable: false)
      ..sort((a, b) {
        final aCreated = a.data()['createdAt'];
        final bCreated = b.data()['createdAt'];
        if (aCreated is Timestamp && bCreated is Timestamp) {
          return bCreated.compareTo(aCreated);
        }
        return 0;
      });
    return docs.map(AdminProjectExpenseRecord.fromSnapshot).toList(growable: false);
  }

  static Future<void> saveConfig(AdminProjectFinanceConfig config) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('ต้องเข้าสู่ระบบแอดมินก่อน');
    }

    await _configRef.set(
      <String, dynamic>{
        'recordType': 'config',
        ...config.toMap(adminUid: user.uid, adminEmail: user.email),
      },
      SetOptions(merge: true),
    );
  }

  static Future<String> addExpense({
    required String title,
    required double amountBaht,
    String? note,
    String? category,
    String? localReceiptPath,
    double? amountExVat,
    double? vatAmount,
    double? vatRate,
    String? supplierTaxId,
    String? invoiceNumber,
    DateTime? invoiceDate,
    bool taxDeductible = true,
    bool hasVatBreakdown = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('ต้องเข้าสู่ระบบแอดมินก่อน');
    }

    final docRef = _collectionRef.doc();
    String? receiptImageUrl;

    if (localReceiptPath != null && localReceiptPath.trim().isNotEmpty) {
      receiptImageUrl = await _uploadReceipt(
        expenseId: docRef.id,
        localPath: localReceiptPath.trim(),
      );
    }

    await docRef.set(<String, dynamic>{
      'recordType': _expenseRecordType,
      'title': title.trim(),
      'amountBaht': amountBaht,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      if (category != null && category.trim().isNotEmpty)
        'category': category.trim(),
      if (receiptImageUrl != null) 'receiptImageUrl': receiptImageUrl,
      if (hasVatBreakdown && amountExVat != null) 'amountExVat': amountExVat,
      if (hasVatBreakdown && vatAmount != null) 'vatAmount': vatAmount,
      if (hasVatBreakdown && vatRate != null) 'vatRate': vatRate,
      if (supplierTaxId != null && supplierTaxId.trim().isNotEmpty)
        'supplierTaxId': supplierTaxId.trim(),
      if (invoiceNumber != null && invoiceNumber.trim().isNotEmpty)
        'invoiceNumber': invoiceNumber.trim(),
      if (invoiceDate != null) 'invoiceDate': Timestamp.fromDate(invoiceDate),
      'taxDeductible': taxDeductible,
      'createdAt': FieldValue.serverTimestamp(),
      'createdByUid': user.uid,
      if (user.email != null && user.email!.trim().isNotEmpty)
        'createdByEmail': user.email!.trim(),
    });

    try {
      final taxConfig = await AdminTaxService.fetchTaxConfig();
      await AdminTaxService.syncExpenseLedger(
        expenseId: docRef.id,
        title: title,
        amountBaht: amountBaht,
        taxConfig: taxConfig,
        amountExVat: hasVatBreakdown ? amountExVat : null,
        vatAmount: hasVatBreakdown ? vatAmount : null,
        vatRate: hasVatBreakdown ? vatRate : null,
        supplierTaxId: supplierTaxId,
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        taxDeductible: taxDeductible,
      );
    } catch (_) {}

    return docRef.id;
  }

  static Future<void> deleteExpense(String expenseId) async {
    if (expenseId == _configDocId) {
      throw StateError('ไม่สามารถลบเอกสาร config ได้');
    }
    final doc = await _collectionRef.doc(expenseId).get();
    final receiptUrl = _nullableString(doc.data()?['receiptImageUrl']);
    await _collectionRef.doc(expenseId).delete();
    try {
      await AdminTaxService.deleteExpenseLedger(expenseId);
    } catch (_) {}
    if (receiptUrl != null) {
      try {
        await FirebaseStorage.instance.refFromURL(receiptUrl).delete();
      } catch (_) {}
    }
  }

  static Future<AdminProjectFinanceSnapshot> buildSnapshot({
    AdminProjectFinanceConfig? config,
    List<AdminProjectExpenseRecord>? expenses,
  }) async {
    AdminProjectFinanceConfig resolvedConfig = config ?? const AdminProjectFinanceConfig();
    if (config == null) {
      try {
        resolvedConfig = AdminProjectFinanceConfig.fromMap(
          (await _configRef.get()).data(),
        );
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') {
          rethrow;
        }
      }
    }

    List<AdminProjectExpenseRecord> resolvedExpenses =
        expenses ?? const <AdminProjectExpenseRecord>[];
    if (expenses == null) {
      try {
        resolvedExpenses = _mapExpenseDocs(await _expensesQuery().get());
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          try {
            final allDocs = await _collectionRef.get();
            resolvedExpenses = allDocs.docs
                .where((doc) => doc.id != _configDocId)
                .map(AdminProjectExpenseRecord.fromSnapshot)
                .toList(growable: false);
          } on FirebaseException {
            resolvedExpenses = const <AdminProjectExpenseRecord>[];
          }
        } else {
          rethrow;
        }
      }
    }

    var rates = AdminSettlementFeeRates.defaults;
    try {
      rates = await AdminSettlementSupport.fetchSettlementFeeRates();
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }
    }

    var deliveredOrders = const <AdminOrderRecord>[];
    try {
      final orders = await AdminRepository.streamOrders(limit: 500).first;
      deliveredOrders = orders
          .where(
            (order) => resolveAdminOrderCategory(order) == AdminOrderCategory.success,
          )
          .toList(growable: false);
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }
    }

    var productUploadCount = 0;
    try {
      productUploadCount =
          (await _firestore.collection('products').count().get()).count ?? 0;
    } on FirebaseException catch (error) {
      if (error.code != 'permission-denied') {
        rethrow;
      }
    }

    final salesPlatformRevenueBaht = deliveredOrders.fold<double>(
      0,
      (sum, order) =>
          sum + order.gpDeduction(rates) + order.shippingPlatformFee(rates),
    );

    final productUploadRevenueBaht =
        productUploadCount * resolvedConfig.productUploadRevenuePerItem;

    final totalExpensesBaht = resolvedExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amountBaht,
    );
    final totalAutoRevenueBaht =
        salesPlatformRevenueBaht + productUploadRevenueBaht;
    final netProfitBaht = totalAutoRevenueBaht - totalExpensesBaht;
    final roiPercent = calculateRoiPercent(
      initialInvestmentBaht: resolvedConfig.initialInvestmentBaht,
      netProfitBaht: netProfitBaht,
    );

    return AdminProjectFinanceSnapshot(
      config: resolvedConfig,
      expenses: resolvedExpenses,
      totalExpensesBaht: totalExpensesBaht,
      salesPlatformRevenueBaht: salesPlatformRevenueBaht,
      productUploadCount: productUploadCount,
      productUploadRevenueBaht: productUploadRevenueBaht,
      totalAutoRevenueBaht: totalAutoRevenueBaht,
      netProfitBaht: netProfitBaht,
      roiPercent: roiPercent,
      deliveredOrderCount: deliveredOrders.length,
    );
  }

  static double? calculateRoiPercent({
    required double initialInvestmentBaht,
    required double netProfitBaht,
  }) {
    if (initialInvestmentBaht <= 0) {
      return null;
    }
    return (netProfitBaht / initialInvestmentBaht) * 100;
  }

  static Future<String> _uploadReceipt({
    required String expenseId,
    required String localPath,
  }) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      throw StateError('ไม่พบไฟล์ใบเสร็จ');
    }

    final fileName = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : 'receipt.jpg';
    final storagePath =
        'project_finance/receipts/$expenseId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}

double? _nullableMoney(Object? value) {
  if (value == null) {
    return null;
  }
  return _readMoney(value);
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

String formatBaht(double value, {int fractionDigits = 2}) {
  final text = value.toStringAsFixed(fractionDigits);
  final parts = text.split('.');
  final whole = parts.first;
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(whole[i]);
  }
  if (fractionDigits <= 0) {
    return buffer.toString();
  }
  return '${buffer.toString()}.${parts.last}';
}
