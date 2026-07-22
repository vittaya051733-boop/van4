import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_repository.dart';
import 'admin_order_support.dart';

/// โปรไฟล์บัญชีธนาคารสำหรับโอนเงิน
class AdminBankProfile {
  const AdminBankProfile({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    this.bookBankImageUrl,
  });

  final String bankName;
  final String accountNumber;
  final String accountName;
  final String? bookBankImageUrl;

  bool get isComplete =>
      bankName.trim().isNotEmpty &&
      accountNumber.trim().isNotEmpty &&
      accountName.trim().isNotEmpty;

  static AdminBankProfile? fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return null;
    }
    final bankName = _firstString(data, const <String>[
      'bankName',
      'bank',
      'refundBankName',
    ]);
    final accountNumber = _firstString(data, const <String>[
      'accountNumber',
      'bankAccountNumber',
      'refundBankAccountNumber',
    ]);
    final accountName = _firstString(data, const <String>[
      'accountOwner',
      'accountName',
      'refundAccountName',
      'displayName',
    ]);
    if (bankName == null && accountNumber == null && accountName == null) {
      return null;
    }
    return AdminBankProfile(
      bankName: bankName ?? '',
      accountNumber: accountNumber ?? '',
      accountName: accountName ?? '',
      bookBankImageUrl: _firstString(data, const <String>[
        'bookBankImageUrl',
        'bookBankImage',
      ]),
    );
  }

  static String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) {
        continue;
      }
      final text = value.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return null;
  }
}

class AdminLeaderProfile {
  const AdminLeaderProfile({
    required this.displayName,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  final String displayName;
  final String bankName;
  final String accountNumber;
  final String accountName;

  bool get isComplete =>
      displayName.trim().isNotEmpty &&
      bankName.trim().isNotEmpty &&
      accountNumber.trim().isNotEmpty &&
      accountName.trim().isNotEmpty;

  static const AdminLeaderProfile empty = AdminLeaderProfile(
    displayName: '',
    bankName: '',
    accountNumber: '',
    accountName: '',
  );

  factory AdminLeaderProfile.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return AdminLeaderProfile.empty;
    }
    return AdminLeaderProfile(
      displayName: data['displayName']?.toString().trim() ?? '',
      bankName: data['bankName']?.toString().trim() ?? '',
      accountNumber: data['accountNumber']?.toString().trim() ?? '',
      accountName: data['accountName']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'displayName': displayName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class AdminSettlementBankDirectory {
  const AdminSettlementBankDirectory({
    required this.shopsByOwnerId,
    required this.ridersById,
    required this.leader,
  });

  final Map<String, AdminBankProfile> shopsByOwnerId;
  final Map<String, AdminBankProfile> ridersById;
  final AdminLeaderProfile leader;
}

class PayoutImportRow {
  const PayoutImportRow({
    required this.payoutType,
    required this.orderCode,
    required this.orderId,
    required this.transferStatus,
    required this.transferReference,
    required this.paidAt,
    required this.lineNumber,
  });

  final String payoutType;
  final String orderCode;
  final String orderId;
  final String transferStatus;
  final String transferReference;
  final String paidAt;
  final int lineNumber;
}

class PayoutImportResult {
  const PayoutImportResult({
    required this.updated,
    required this.skipped,
    required this.errors,
  });

  final int updated;
  final int skipped;
  final List<String> errors;
}

class AdminSettlementSupport {
  AdminSettlementSupport._();

  static const String leaderDocPath = 'platform_config/leader';
  static const String settlementDocPath = 'platform_config/settlement';

  static Future<AdminSettlementFeeRates> fetchSettlementFeeRates() async {
    final doc =
        await FirebaseFirestore.instance.doc(settlementDocPath).get();
    return AdminSettlementFeeRates.fromFirestore(doc.data());
  }

  static Future<void> saveSettlementFeeRates(
    AdminSettlementFeeRates rates,
  ) async {
    await FirebaseFirestore.instance.doc(settlementDocPath).set(
      <String, dynamic>{
        'gpRatePercent': rates.gpRatePercent,
        'riderPlatformRatePercent': rates.riderPlatformRatePercent,
        'leaderRatePercent': rates.leaderRatePercent,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  static Future<AdminSettlementBankDirectory> loadBankDirectory({
    required List<AdminOrderRecord> orders,
  }) async {
    final shopOwnerIds = orders
        .map((order) => order.shopOwnerId?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    final riderIds = orders
        .map((order) => order.driverId?.trim())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();

    final shops = await fetchShopBankProfiles(shopOwnerIds);
    final riders = await fetchRiderBankProfiles(riderIds);
    final leader = await fetchLeaderProfile();
    return AdminSettlementBankDirectory(
      shopsByOwnerId: shops,
      ridersById: riders,
      leader: leader,
    );
  }

  static Future<Map<String, AdminBankProfile>> fetchShopBankProfiles(
    Set<String> ownerIds,
  ) async {
    if (ownerIds.isEmpty) {
      return const <String, AdminBankProfile>{};
    }

    final firestore = FirebaseFirestore.instance;
    final result = <String, AdminBankProfile>{};
    for (final collection in AdminRepository.shopCollections) {
      final pending = ownerIds.where((id) => !result.containsKey(id)).toList();
      if (pending.isEmpty) {
        break;
      }
      for (var i = 0; i < pending.length; i += 30) {
        final chunk = pending.skip(i).take(30).toList(growable: false);
        final snapshot = await firestore
            .collection(collection)
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snapshot.docs) {
          final profile = AdminBankProfile.fromMap(doc.data());
          if (profile != null && profile.isComplete) {
            result[doc.id] = profile;
          }
        }
      }
    }
    return result;
  }

  static Future<Map<String, AdminBankProfile>> fetchRiderBankProfiles(
    Set<String> riderIds,
  ) async {
    if (riderIds.isEmpty) {
      return const <String, AdminBankProfile>{};
    }

    final firestore = FirebaseFirestore.instance;
    final result = <String, AdminBankProfile>{};
    final ids = riderIds.toList(growable: false);
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.skip(i).take(30).toList(growable: false);
      final riders = await firestore
          .collection('riders')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in riders.docs) {
        final profile = AdminBankProfile.fromMap(doc.data());
        if (profile != null && profile.isComplete) {
          result[doc.id] = profile;
        }
      }

      final registrations = await firestore
          .collection('rider_registrations')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in registrations.docs) {
        if (result.containsKey(doc.id)) {
          continue;
        }
        final profile = AdminBankProfile.fromMap(doc.data());
        if (profile != null && profile.isComplete) {
          result[doc.id] = profile;
        }
      }
    }
    return result;
  }

  static Future<AdminLeaderProfile> fetchLeaderProfile() async {
    final doc =
        await FirebaseFirestore.instance.doc(leaderDocPath).get();
    return AdminLeaderProfile.fromMap(doc.data());
  }

  static Future<void> saveLeaderProfile(AdminLeaderProfile profile) async {
    await FirebaseFirestore.instance
        .doc(leaderDocPath)
        .set(profile.toFirestore(), SetOptions(merge: true));
  }

  static Future<void> markSettlementExported({
    required List<AdminOrderRecord> orders,
    required String batchId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final now = FieldValue.serverTimestamp();
    for (final order in orders) {
      final ref = firestore.collection('orders').doc(order.id);
      batch.set(
        ref,
        <String, dynamic>{
          'settlement': <String, dynamic>{
            'exportBatchId': batchId,
            'exportedAt': now,
            if (order.isDeliveredSuccess) ...<String, dynamic>{
              'shopPayout': <String, dynamic>{
                'status': 'exported',
                'updatedAt': now,
              },
              'riderPayout': <String, dynamic>{
                'status': 'exported',
                'updatedAt': now,
              },
            },
            if (order.isRefundCase)
              'refundPayout': <String, dynamic>{
                'status': 'exported',
                'updatedAt': now,
              },
          },
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  static String buildBulkTransferCsv({
    required DateTime reportDate,
    required List<AdminOrderRecord> orders,
    required AdminSettlementBankDirectory banks,
    AdminSettlementFeeRates rates = AdminSettlementFeeRates.defaults,
  }) {
    final delivered = orders
        .where((order) => order.isDeliveredSuccess)
        .toList(growable: false);
    final refunds = orders
        .where((order) => order.isRefundCase)
        .toList(growable: false);
    final buffer = StringBuffer()
      ..writeln(
        'payout_type,order_number,recipient_name,bank_name,account_number,account_name,amount,order_breakdown,transfer_reference,transfer_status,paid_at',
      );

    final shopGroups = <String, List<AdminOrderRecord>>{};
    final riderGroups = <String, List<AdminOrderRecord>>{};
    for (final order in delivered) {
      final shopOwnerId = order.shopOwnerId?.trim() ?? '';
      if (shopOwnerId.isNotEmpty) {
        shopGroups.putIfAbsent(shopOwnerId, () => <AdminOrderRecord>[]).add(order);
      }
      final riderId = order.driverId?.trim() ?? '';
      if (riderId.isNotEmpty) {
        riderGroups.putIfAbsent(riderId, () => <AdminOrderRecord>[]).add(order);
      }
    }

    for (final entry in shopGroups.entries) {
      final shopOwnerId = entry.key;
      final shopOrders = entry.value;
      final shopBank = banks.shopsByOwnerId[shopOwnerId];
      var shopAmount = 0.0;
      final orderNumbers = <String>[];
      final breakdown = <String>[];
      for (final order in shopOrders) {
        final net = order.shopNetPayout(rates);
        if (net <= 0) {
          continue;
        }
        shopAmount += net;
        orderNumbers.add(order.displayOrderNumber);
        breakdown.add('${order.displayOrderNumber}:${_money(net)}');
      }
      if (shopAmount <= 0) {
        continue;
      }
      final shopName = shopOrders.first.shopName?.trim().isNotEmpty == true
          ? shopOrders.first.shopName!.trim()
          : shopOwnerId;
      buffer.writeln(
        [
          _csvCell('shop'),
          _csvCell(orderNumbers.join(', ')),
          _csvCell(shopName),
          _csvCell(shopBank?.bankName ?? ''),
          _csvCell(shopBank?.accountNumber ?? ''),
          _csvCell(shopBank?.accountName ?? ''),
          _csvCell(_money(shopAmount)),
          _csvCell(breakdown.join('; ')),
          _csvCell(''),
          _csvCell(''),
          _csvCell(''),
        ].join(','),
      );
    }

    for (final entry in riderGroups.entries) {
      final riderId = entry.key;
      final riderOrders = entry.value;
      final riderBank = banks.ridersById[riderId];
      var riderAmount = 0.0;
      final orderNumbers = <String>[];
      final breakdown = <String>[];
      for (final order in riderOrders) {
        final net = order.riderNetShippingIncome(rates);
        if (net <= 0) {
          continue;
        }
        riderAmount += net;
        orderNumbers.add(order.displayOrderNumber);
        breakdown.add('${order.displayOrderNumber}:${_money(net)}');
      }
      if (riderAmount <= 0) {
        continue;
      }
      final riderName = riderOrders.first.driverName?.trim().isNotEmpty == true
          ? riderOrders.first.driverName!.trim()
          : riderId;
      buffer.writeln(
        [
          _csvCell('rider'),
          _csvCell(orderNumbers.join(', ')),
          _csvCell(riderName),
          _csvCell(riderBank?.bankName ?? ''),
          _csvCell(riderBank?.accountNumber ?? ''),
          _csvCell(riderBank?.accountName ?? ''),
          _csvCell(_money(riderAmount)),
          _csvCell(breakdown.join('; ')),
          _csvCell(''),
          _csvCell(''),
          _csvCell(''),
        ].join(','),
      );
    }

    for (final order in refunds) {
      final amount = order.refundAmount;
      if (amount <= 0) {
        continue;
      }
      buffer.writeln(
        [
          _csvCell('refund'),
          _csvCell(order.displayOrderNumber),
          _csvCell(order.customerName ?? order.refundAccountName ?? ''),
          _csvCell(order.refundBankName ?? ''),
          _csvCell(order.refundBankAccountNumber ?? ''),
          _csvCell(order.refundAccountName ?? ''),
          _csvCell(_money(amount)),
          _csvCell(''),
          _csvCell(''),
          _csvCell(''),
        ].join(','),
      );
    }

    var leaderTotal = 0.0;
    for (final order in delivered) {
      leaderTotal += order.leaderDeduction(rates);
    }
    if (leaderTotal > 0 && banks.leader.isComplete) {
      buffer.writeln(
        [
          _csvCell('leader'),
          _csvCell('DAILY-${_formatReportDate(reportDate)}'),
          _csvCell(banks.leader.displayName),
          _csvCell(banks.leader.bankName),
          _csvCell(banks.leader.accountNumber),
          _csvCell(banks.leader.accountName),
          _csvCell(_money(leaderTotal)),
          _csvCell(''),
          _csvCell(''),
          _csvCell(''),
        ].join(','),
      );
    }

    buffer
      ..writeln()
      ..writeln('summary_field,value')
      ..writeln('report_date,${_csvCell(_formatReportDate(reportDate))}')
      ..writeln('delivered_orders,${delivered.length}')
      ..writeln('refund_orders,${refunds.length}')
      ..writeln('leader_daily_total,${_money(leaderTotal)}');

    return buffer.toString();
  }

  static List<PayoutImportRow> parsePayoutResultCsv(String raw) {
    final lines = const LineSplitter().convert(raw.trim());
    if (lines.isEmpty) {
      return const <PayoutImportRow>[];
    }

    final header = _parseCsvLine(lines.first);
    final headerIndex = <String, int>{
      for (var i = 0; i < header.length; i++) header[i].trim().toLowerCase(): i,
    };

    int colIndex(List<String> names, int fallback) {
      for (final name in names) {
        final index = headerIndex[name.toLowerCase()];
        if (index != null) {
          return index;
        }
      }
      return fallback;
    }

    final payoutTypeCol = colIndex(<String>['payout_type', 'ประเภท'], 0);
    final orderNumberCol = colIndex(
      <String>['order_number', 'order_code', 'หมายเลขออเดอร์', 'รหัสออเดอร์'],
      1,
    );
    final orderIdCol = colIndex(<String>['order_id', 'orderid'], -1);
    final statusCol = colIndex(<String>['transfer_status', 'สถานะโอน'], 9);
    final refCol = colIndex(<String>['transfer_reference', 'อ้างอิง'], 8);
    final paidAtCol = colIndex(<String>['paid_at', 'เวลาโอน'], 10);

    final rows = <PayoutImportRow>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('summary_field')) {
        continue;
      }
      final cells = _parseCsvLine(line);
      if (cells.isEmpty) {
        continue;
      }
      final payoutType = _cellAt(cells, payoutTypeCol).toLowerCase();
      if (payoutType.isEmpty || payoutType == 'payout_type') {
        continue;
      }
      rows.add(
        PayoutImportRow(
          payoutType: payoutType,
          orderCode: _cellAt(cells, orderNumberCol),
          orderId: _cellAt(cells, orderIdCol),
          transferStatus: _cellAt(cells, statusCol).toLowerCase(),
          transferReference: _cellAt(cells, refCol),
          paidAt: _cellAt(cells, paidAtCol),
          lineNumber: i + 1,
        ),
      );
    }
    return rows;
  }

  static Future<PayoutImportResult> applyPayoutImport(
    List<PayoutImportRow> rows,
  ) async {
    var updated = 0;
    var skipped = 0;
    final errors = <String>[];

    for (final row in rows) {
      if (row.payoutType == 'leader') {
        skipped++;
        continue;
      }
      if (row.transferStatus.isEmpty) {
        skipped++;
        continue;
      }
      if (row.orderId.isEmpty && row.orderCode.isEmpty) {
        errors.add('แถว ${row.lineNumber}: ต้องมี order_number หรือ order_id');
        continue;
      }
      final normalized = _normalizeTransferStatus(row.transferStatus);
      if (normalized == null) {
        errors.add('แถว ${row.lineNumber}: transfer_status ไม่รู้จัก (${row.transferStatus})');
        continue;
      }

      final field = switch (row.payoutType) {
        'shop' => 'shopPayout',
        'rider' => 'riderPayout',
        'refund' => 'refundPayout',
        _ => null,
      };
      if (field == null) {
        errors.add('แถว ${row.lineNumber}: payout_type ไม่รู้จัก (${row.payoutType})');
        continue;
      }

      List<String> orderCodes;
      if (row.orderCode.isNotEmpty) {
        orderCodes = _splitOrderCodes(row.orderCode);
      } else {
        orderCodes = const <String>[];
      }

      if (orderCodes.isEmpty) {
        try {
          final resolvedOrderId = await AdminRepository.resolveOrderDocumentId(
            orderId: row.orderId.isNotEmpty ? row.orderId : null,
            orderCode: null,
          );
          if (resolvedOrderId == null) {
            errors.add('แถว ${row.lineNumber}: ไม่พบออเดอร์');
            continue;
          }
          await _applyPayoutToOrder(
            orderDocumentId: resolvedOrderId,
            orderCode: row.orderCode,
            field: field,
            normalized: normalized,
            row: row,
          );
          updated++;
        } catch (error) {
          errors.add('แถว ${row.lineNumber}: $error');
        }
        continue;
      }

      for (final orderCode in orderCodes) {
        try {
          final resolvedOrderId = await AdminRepository.resolveOrderDocumentId(
            orderId: row.orderId.isNotEmpty ? row.orderId : null,
            orderCode: orderCode,
          );
          if (resolvedOrderId == null) {
            errors.add('แถว ${row.lineNumber}: ไม่พบออเดอร์ ($orderCode)');
            continue;
          }
          await _applyPayoutToOrder(
            orderDocumentId: resolvedOrderId,
            orderCode: orderCode,
            field: field,
            normalized: normalized,
            row: row,
          );
          updated++;
        } catch (error) {
          errors.add('แถว ${row.lineNumber}: $error');
        }
      }
    }

    return PayoutImportResult(
      updated: updated,
      skipped: skipped,
      errors: errors,
    );
  }

  static String? _normalizeTransferStatus(String raw) {
    return switch (raw.trim().toLowerCase()) {
      'paid' || 'success' || 'successful' || 'โอนแล้ว' || 'สำเร็จ' => 'paid',
      'failed' || 'fail' || 'ไม่สำเร็จ' => 'failed',
      'exported' || 'ส่งออกแล้ว' => 'exported',
      'pending' || 'รอโอน' => 'pending',
      _ => null,
    };
  }

  static String readPayoutStatus(AdminOrderRecord order, String type) =>
      _readPayoutStatus(order, type);

  static String _readPayoutStatus(AdminOrderRecord order, String type) {
    final settlement = order.rawData['settlement'];
    if (settlement is! Map) {
      return 'pending';
    }
    final key = switch (type) {
      'shop' => 'shopPayout',
      'rider' => 'riderPayout',
      'refund' => 'refundPayout',
      _ => '',
    };
    final payout = settlement[key];
    if (payout is Map) {
      return payout['status']?.toString() ?? 'pending';
    }
    return 'pending';
  }

  static Future<void> _applyPayoutToOrder({
    required String orderDocumentId,
    required String orderCode,
    required String field,
    required String normalized,
    required PayoutImportRow row,
  }) async {
    final payload = <String, dynamic>{
      'status': normalized,
      'orderCode': orderCode,
      'transferReference': row.transferReference,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (normalized == 'paid') {
      payload['paidAt'] = row.paidAt.isNotEmpty
          ? row.paidAt
          : FieldValue.serverTimestamp();
    }

    await FirebaseFirestore.instance.collection('orders').doc(orderDocumentId).set(
      <String, dynamic>{
        'settlement': <String, dynamic>{
          field: payload,
        },
      },
      SetOptions(merge: true),
    );

    if (normalized == 'paid' && (field == 'shopPayout' || field == 'riderPayout')) {
      final orderSnap = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderDocumentId)
          .get();
      final orderData = orderSnap.data() ?? <String, dynamic>{};
      final settlement = _readSettlementMap(orderData['settlement']);
      final payout = _readSettlementMap(settlement?[field]);
      final amount = _readAmount(payout?['amount']) ?? 0;
      if (amount > 0) {
        await _enqueuePayoutPaidNotification(
          orderId: orderDocumentId,
          orderData: orderData,
          payoutType: field == 'shopPayout' ? 'shop' : 'rider',
          amount: amount,
        );
      }
    }
  }

  static Future<void> _enqueuePayoutPaidNotification({
    required String orderId,
    required Map<String, dynamic> orderData,
    required String payoutType,
    required double amount,
  }) async {
    final orderCode = orderData['orderCode']?.toString().trim();
    final orderLabel = orderCode?.isNotEmpty == true
        ? '#$orderCode'
        : '#${orderId.substring(0, orderId.length.clamp(0, 8))}';
    final body =
        'ออเดอร์ $orderLabel ${amount.toStringAsFixed(2)} บาท • จ่ายแล้ว';
    final notifications =
        FirebaseFirestore.instance.collection('app_notifications');
    final now = FieldValue.serverTimestamp();

    if (payoutType == 'shop') {
      final shopOwnerId = _readRecipientUid(
        orderData['shopOwnerId'] ?? orderData['merchantId'] ?? orderData['shopId'],
      );
      if (shopOwnerId == null) {
        return;
      }
      await notifications.add(<String, dynamic>{
        'targetApp': 'van1',
        'recipientUid': shopOwnerId,
        'orderId': orderId,
        'title': 'โอนเงินสำเร็จ',
        'body': body,
        'action': 'payout_paid',
        'read': false,
        'isRead': false,
        'createdAt': now,
      });
      return;
    }

    final riderId = _readRecipientUid(
      orderData['driverId'] ?? orderData['riderId'],
    );
    if (riderId == null) {
      return;
    }
    await notifications.add(<String, dynamic>{
      'targetApp': 'van3',
      'recipientUid': riderId,
      'orderId': orderId,
      'title': 'โอนเงินสำเร็จ',
      'body': body,
      'action': 'payout_paid',
      'read': false,
      'isRead': false,
      'createdAt': now,
    });
  }

  static String? _readRecipientUid(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static Map<String, dynamic>? _readSettlementMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
    }
    return null;
  }

  static double? _readAmount(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static List<String> _splitOrderCodes(String raw) {
    return raw
        .split(RegExp(r'[,;]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
  }

  static String _cellAt(List<String> cells, int index) {
    if (index < 0 || index >= cells.length) {
      return '';
    }
    return cells[index].trim();
  }

  static List<String> _parseCsvLine(String line) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }
      if (char == ',' && !inQuotes) {
        cells.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    cells.add(buffer.toString());
    return cells;
  }

  static String _csvCell(String value) {
    final sanitized = value.replaceAll('"', '""');
    return '"$sanitized"';
  }

  static String _money(double value) => value.toStringAsFixed(2);

  static String _formatReportDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
