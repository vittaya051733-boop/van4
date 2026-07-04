import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'admin_repository.dart';
import 'admin_settlement_support.dart';

enum AdminOrderCategory {
  success,
  unsuccessful,
  cancelled,
  refund,
}

/// อัตราหักสำหรับสรุป CSV ฝั่งแอดมิน (กำหนดได้ใน platform_config/settlement)
class AdminSettlementFeeRates {
  const AdminSettlementFeeRates({
    this.gpRate = 0.18,
    this.riderPlatformRate = 0.15,
    this.leaderRate = 0.15,
  });

  static const AdminSettlementFeeRates defaults = AdminSettlementFeeRates();

  final double gpRate;
  final double riderPlatformRate;
  final double leaderRate;

  double get gpRatePercent => gpRate * 100;
  double get riderPlatformRatePercent => riderPlatformRate * 100;
  double get leaderRatePercent => leaderRate * 100;

  double afterGp(double productSubtotal) =>
      productSubtotal * (1 - gpRate);

  double shopNet(double productSubtotal) =>
      afterGp(productSubtotal) * (1 - leaderRate);

  double shippingPlatformFee(double grossShipping) =>
      grossShipping * riderPlatformRate;

  double riderNetShipping(double grossShipping) =>
      grossShipping * (1 - riderPlatformRate);

  static AdminSettlementFeeRates fromFirestore(Map<String, dynamic>? data) {
    if (data == null) {
      return defaults;
    }
    return AdminSettlementFeeRates(
      gpRate: _readRatePercent(data, 'gpRatePercent', 18) / 100,
      riderPlatformRate:
          _readRatePercent(data, 'riderPlatformRatePercent', 15) / 100,
      leaderRate: _readRatePercent(data, 'leaderRatePercent', 15) / 100,
    );
  }

  static double _readRatePercent(
    Map<String, dynamic> data,
    String key,
    double fallback,
  ) {
    final value = data[key];
    if (value is num && value >= 0 && value <= 100) {
      return value.toDouble();
    }
    return fallback;
  }
}

extension AdminOrderCategoryX on AdminOrderCategory {
  String get label {
    switch (this) {
      case AdminOrderCategory.success:
        return 'สำเร็จ';
      case AdminOrderCategory.unsuccessful:
        return 'ไม่สำเร็จ';
      case AdminOrderCategory.cancelled:
        return 'ยกเลิก';
      case AdminOrderCategory.refund:
        return 'ขอคืนเงิน';
    }
  }
}

extension AdminOrderSettlementX on AdminOrderRecord {
  double get resolvedProductSubtotal {
    if (subtotal != null && subtotal! > 0) {
      return subtotal!;
    }

    final itemsTotal = items.fold<double>(
      0,
      (sum, item) => sum + (item.lineTotal ?? 0),
    );
    if (itemsTotal > 0) {
      return itemsTotal;
    }

    final shipping = resolvedShippingFee;
    if (grandTotal != null && grandTotal! > 0) {
      if (shipping > 0 && grandTotal! > shipping) {
        return grandTotal! - shipping;
      }
      return grandTotal!;
    }
    return 0;
  }

  double get resolvedShippingFee {
    if (shippingFee != null && shippingFee! > 0) {
      return shippingFee!;
    }

    final fromDelivery = _readDouble(rawData['deliveryGrossShippingFee']);
    if (fromDelivery != null && fromDelivery > 0) {
      return fromDelivery;
    }

    final financials = rawData['deliveryFinancials'];
    if (financials is Map) {
      final gross = _readDouble(financials['grossShippingFee']);
      if (gross != null && gross > 0) {
        return gross;
      }
    }
    return 0;
  }

  double gpDeduction(AdminSettlementFeeRates rates) =>
      resolvedProductSubtotal * rates.gpRate;

  double afterGpDeduction(AdminSettlementFeeRates rates) =>
      rates.afterGp(resolvedProductSubtotal);

  double leaderDeduction(AdminSettlementFeeRates rates) =>
      afterGpDeduction(rates) * rates.leaderRate;

  double shopNetPayout(AdminSettlementFeeRates rates) =>
      rates.shopNet(resolvedProductSubtotal);

  double shippingPlatformFee(AdminSettlementFeeRates rates) =>
      rates.shippingPlatformFee(resolvedShippingFee);

  double riderNetShippingIncome(AdminSettlementFeeRates rates) =>
      rates.riderNetShipping(resolvedShippingFee);

  double get refundAmount {
    if (grandTotal != null && grandTotal! > 0) {
      return grandTotal!;
    }
    return resolvedProductSubtotal + resolvedShippingFee;
  }

  bool get isDeliveredSuccess => status.toLowerCase() == 'delivered';
}

double? _readDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim());
  }
  return null;
}

AdminOrderCategory resolveAdminOrderCategory(AdminOrderRecord order) {
  if (order.isRefundCase) {
    return AdminOrderCategory.refund;
  }
  final status = order.status.toLowerCase();
  if (status == 'cancelled') {
    return AdminOrderCategory.cancelled;
  }
  if (status == 'delivered') {
    return AdminOrderCategory.success;
  }
  return AdminOrderCategory.unsuccessful;
}

List<AdminOrderRecord> filterOrdersByCategory(
  List<AdminOrderRecord> orders,
  AdminOrderCategory category,
) {
  return orders
      .where((order) => resolveAdminOrderCategory(order) == category)
      .toList(growable: false);
}

List<AdminOrderRecord> filterDeliveredOrders(List<AdminOrderRecord> orders) {
  return orders.where((order) => order.isDeliveredSuccess).toList(growable: false);
}

List<AdminOrderRecord> filterRefundOrders(List<AdminOrderRecord> orders) {
  return orders.where((order) => order.isRefundCase).toList(growable: false);
}

class AdminCsvExportFile {
  const AdminCsvExportFile({
    required this.name,
    required this.content,
  });

  final String name;
  final String content;
}

class AdminDailyCsvBundle {
  const AdminDailyCsvBundle({
    required this.reportDate,
    required this.files,
  });

  final DateTime reportDate;
  final List<AdminCsvExportFile> files;
}

AdminDailyCsvBundle buildAllDailySettlementCsvBundle({
  required DateTime reportDate,
  required List<AdminOrderRecord> orders,
  AdminSettlementBankDirectory? banks,
  AdminSettlementFeeRates rates = AdminSettlementFeeRates.defaults,
}) {
  final dateKey =
      '${reportDate.year}${reportDate.month.toString().padLeft(2, '0')}${reportDate.day.toString().padLeft(2, '0')}';

  AdminCsvExportFile named(String suffix, String content) {
    return AdminCsvExportFile(
      name: 'van_admin_${suffix}_$dateKey.csv',
      content: content,
    );
  }

  final files = <AdminCsvExportFile>[
    named(
      'shipping',
      buildShippingSettlementCsv(
        reportDate: reportDate,
        orders: orders,
        banks: banks,
        rates: rates,
      ),
    ),
    named(
      'products',
      buildProductsSettlementCsv(
        reportDate: reportDate,
        orders: orders,
      ),
    ),
    named(
      'refunds',
      buildRefundsSettlementCsv(reportDate: reportDate, orders: orders),
    ),
    named(
      'shop',
      buildShopSettlementCsv(
        reportDate: reportDate,
        orders: orders,
        banks: banks,
        rates: rates,
      ),
    ),
  ];

  if (banks != null) {
    files.add(
      named(
        'bulk_transfer',
        AdminSettlementSupport.buildBulkTransferCsv(
          reportDate: reportDate,
          orders: orders,
          banks: banks,
          rates: rates,
        ),
      ),
    );
  }

  return AdminDailyCsvBundle(
    reportDate: reportDate,
    files: files,
  );
}

Future<AdminDailyCsvBundle> buildAllDailySettlementCsvBundleAsync({
  required DateTime reportDate,
  required List<AdminOrderRecord> orders,
}) async {
  final banks = await AdminSettlementSupport.loadBankDirectory(orders: orders);
  final rates = await AdminSettlementSupport.fetchSettlementFeeRates();
  return buildAllDailySettlementCsvBundle(
    reportDate: reportDate,
    orders: orders,
    banks: banks,
    rates: rates,
  );
}

Future<void> exportAndShareDailySettlementCsvFiles({
  required DateTime reportDate,
  required List<AdminOrderRecord> orders,
  bool markExported = true,
}) async {
  final bundle = await buildAllDailySettlementCsvBundleAsync(
    reportDate: reportDate,
    orders: orders,
  );
  if (markExported && orders.isNotEmpty) {
    final batchId =
        'export_${reportDate.year}${reportDate.month.toString().padLeft(2, '0')}${reportDate.day.toString().padLeft(2, '0')}_${DateTime.now().millisecondsSinceEpoch}';
    await AdminSettlementSupport.markSettlementExported(
      orders: orders,
      batchId: batchId,
    );
  }
  await Share.shareXFiles(
    bundle.files
        .map(
          (file) => XFile.fromData(
            utf8.encode(file.content),
            mimeType: 'text/csv',
            name: file.name,
          ),
        )
        .toList(growable: false),
    subject: 'สรุป CSV 4 ฝ่าย Van Market ${_formatReportDate(reportDate)}',
    text:
        'สรุป CSV แยกฝ่าย: ขาดส่ง / ค่าสินค้า / ขอคืนเงิน / ร้านค้า (${_formatReportDate(reportDate)})',
  );
}

String buildShippingSettlementCsv({
  required DateTime reportDate,
  required List<AdminOrderRecord> orders,
  AdminSettlementBankDirectory? banks,
  AdminSettlementFeeRates rates = AdminSettlementFeeRates.defaults,
}) {
  final delivered = filterDeliveredOrders(orders);
  final grouped = _groupOrdersByRider(delivered);
  final buffer = StringBuffer()
    ..writeln(
      'วันที่รายงาน,หมายเลขออเดอร์,ชื่อผู้รับ,ชื่อธนาคาร,เลขที่บัญชี,ชื่อบัญชี,ยอดค่าส่งแต่ละออเดอร์,ยอดโอนรวม',
    );

  var totalTransfer = 0.0;
  var orderCount = 0;

  for (final entry in grouped.entries) {
    final riderOrders = entry.value;
    if (riderOrders.isEmpty) {
      continue;
    }
    orderCount += riderOrders.length;

    final riderId = entry.key;
    final riderBank = banks?.ridersById[riderId];
    final riderName = riderOrders.first.driverName?.trim().isNotEmpty == true
        ? riderOrders.first.driverName!.trim()
        : riderId;
    var transferTotal = 0.0;
    final breakdown = <String>[];
    final orderNumbers = <String>[];

    for (final order in riderOrders) {
      final net = order.riderNetShippingIncome(rates);
      transferTotal += net;
      orderNumbers.add(order.displayOrderNumber);
      breakdown.add('${order.displayOrderNumber}:${_money(net)}');
    }
    totalTransfer += transferTotal;

    buffer.writeln(
      [
        _csvCell(_formatReportDate(reportDate)),
        _csvCell(orderNumbers.join(', ')),
        _csvCell(riderName),
        _csvCell(riderBank?.bankName ?? ''),
        _csvCell(riderBank?.accountNumber ?? ''),
        _csvCell(riderBank?.accountName ?? ''),
        _csvCell(breakdown.join('; ')),
        _csvCell(_money(transferTotal)),
      ].join(','),
    );
  }

  buffer
    ..writeln()
    ..writeln('summary_field,value')
    ..writeln('rider_count,${grouped.length}')
    ..writeln('order_count,$orderCount')
    ..writeln('total_transfer_amount,${_money(totalTransfer)}')
    ..writeln('report_date,${_csvCell(_formatReportDate(reportDate))}');

  return buffer.toString();
}

String buildProductsSettlementCsv({
  required DateTime reportDate,
  required List<AdminOrderRecord> orders,
}) {
  final delivered = filterDeliveredOrders(orders);
  final grouped = _groupOrdersByShop(delivered);
  final buffer = StringBuffer()
    ..writeln(
      'วันที่รายงาน,ชื่อร้าน,หมายเลขออเดอร์,ยอดสินค้าแต่ละออเดอร์,รวมยอดสินค้า',
    );

  var totalProducts = 0.0;
  var orderCount = 0;

  for (final entry in grouped.entries) {
    final shopOrders = entry.value;
    if (shopOrders.isEmpty) {
      continue;
    }
    orderCount += shopOrders.length;

    var shopSubtotal = 0.0;
    final orderNumbers = <String>[];
    final breakdown = <String>[];

    for (final order in shopOrders) {
      final productTotal = order.resolvedProductSubtotal;
      shopSubtotal += productTotal;
      orderNumbers.add(order.displayOrderNumber);
      breakdown.add('${order.displayOrderNumber}:${_money(productTotal)}');
    }
    totalProducts += shopSubtotal;

    final shopName = shopOrders.first.shopName?.trim().isNotEmpty == true
        ? shopOrders.first.shopName!.trim()
        : entry.key;

    buffer.writeln(
      [
        _csvCell(_formatReportDate(reportDate)),
        _csvCell(shopName),
        _csvCell(orderNumbers.join(', ')),
        _csvCell(breakdown.join('; ')),
        _csvCell(_money(shopSubtotal)),
      ].join(','),
    );
  }

  buffer
    ..writeln()
    ..writeln('summary_field,amount')
    ..writeln('shop_count,${grouped.length}')
    ..writeln('order_count,$orderCount')
    ..writeln('total_product_subtotal,${_money(totalProducts)}');

  return buffer.toString();
}

String buildRefundsSettlementCsv({
  required DateTime reportDate,
  required List<AdminOrderRecord> orders,
}) {
  final refunds = filterRefundOrders(orders);
  final buffer = StringBuffer()
    ..writeln(
      'วันที่รายงาน,หมายเลขออเดอร์,ชื่อผู้รับ,ชื่อธนาคาร,เลขที่บัญชี,ชื่อบัญชี,ยอดโอน,สถานะ,เหตุผล',
    );

  var totalRefund = 0.0;

  for (final order in refunds) {
    final amount = order.refundAmount;
    totalRefund += amount;

    buffer.writeln(
      [
        _csvCell(_formatReportDate(reportDate)),
        _csvCell(order.displayOrderNumber),
        _csvCell(order.customerName ?? order.refundAccountName ?? ''),
        _csvCell(order.refundBankName ?? ''),
        _csvCell(order.refundBankAccountNumber ?? ''),
        _csvCell(order.refundAccountName ?? ''),
        _csvCell(_money(amount)),
        _csvCell(order.refundStatus ?? order.status),
        _csvCell(order.cancelReason ?? ''),
      ].join(','),
    );
  }

  buffer
    ..writeln()
    ..writeln('summary_field,amount')
    ..writeln('order_count,${refunds.length}')
    ..writeln('total_refund_amount,${_money(totalRefund)}');

  return buffer.toString();
}

String buildShopSettlementCsv({
  required DateTime reportDate,
  required List<AdminOrderRecord> orders,
  AdminSettlementBankDirectory? banks,
  AdminSettlementFeeRates rates = AdminSettlementFeeRates.defaults,
}) {
  final delivered = filterDeliveredOrders(orders);
  final grouped = _groupOrdersByShop(delivered);
  final buffer = StringBuffer()
    ..writeln(
      'วันที่รายงาน,ชื่อร้าน,ชื่อธนาคาร,เลขที่บัญชี,ชื่อบัญชี,หมายเลขออเดอร์,ยอดสินค้าแต่ละออเดอร์,รวมยอดสินค้า,หักGP(${rates.gpRatePercent.toStringAsFixed(0)}%),หักไลด์เดอร์(${rates.leaderRatePercent.toStringAsFixed(0)}%),ยอดโอน',
    );

  var totalSubtotal = 0.0;
  var totalGp = 0.0;
  var totalLeader = 0.0;
  var totalShopNet = 0.0;
  var orderCount = 0;

  for (final entry in grouped.entries) {
    final shopOrders = entry.value;
    if (shopOrders.isEmpty) {
      continue;
    }
    orderCount += shopOrders.length;

    final shopOwnerId = entry.key;
    final shopBank = banks?.shopsByOwnerId[shopOwnerId];
    final shopName = shopOrders.first.shopName?.trim().isNotEmpty == true
        ? shopOrders.first.shopName!.trim()
        : shopOwnerId;

    var shopSubtotal = 0.0;
    var shopGp = 0.0;
    var shopLeader = 0.0;
    var shopNet = 0.0;
    final orderNumbers = <String>[];
    final breakdown = <String>[];

    for (final order in shopOrders) {
      final subtotal = order.resolvedProductSubtotal;
      shopSubtotal += subtotal;
      shopGp += order.gpDeduction(rates);
      shopLeader += order.leaderDeduction(rates);
      shopNet += order.shopNetPayout(rates);
      orderNumbers.add(order.displayOrderNumber);
      breakdown.add('${order.displayOrderNumber}:${_money(subtotal)}');
    }

    totalSubtotal += shopSubtotal;
    totalGp += shopGp;
    totalLeader += shopLeader;
    totalShopNet += shopNet;

    buffer.writeln(
      [
        _csvCell(_formatReportDate(reportDate)),
        _csvCell(shopName),
        _csvCell(shopBank?.bankName ?? ''),
        _csvCell(shopBank?.accountNumber ?? ''),
        _csvCell(shopBank?.accountName ?? ''),
        _csvCell(orderNumbers.join(', ')),
        _csvCell(breakdown.join('; ')),
        _csvCell(_money(shopSubtotal)),
        _csvCell(_money(shopGp)),
        _csvCell(_money(shopLeader)),
        _csvCell(_money(shopNet)),
      ].join(','),
    );
  }

  buffer
    ..writeln()
    ..writeln('summary_field,amount')
    ..writeln('shop_count,${grouped.length}')
    ..writeln('order_count,$orderCount')
    ..writeln('total_product_subtotal,${_money(totalSubtotal)}')
    ..writeln('total_gp_deduct,${_money(totalGp)}')
    ..writeln('total_leader_deduct,${_money(totalLeader)}')
    ..writeln('total_shop_net_payout,${_money(totalShopNet)}');

  return buffer.toString();
}

Map<String, List<AdminOrderRecord>> _groupOrdersByShop(
  List<AdminOrderRecord> orders,
) {
  final grouped = <String, List<AdminOrderRecord>>{};
  for (final order in orders) {
    final ownerId = order.shopOwnerId?.trim();
    final key = (ownerId != null && ownerId.isNotEmpty)
        ? ownerId
        : order.shopName?.trim() ?? order.id;
    grouped.putIfAbsent(key, () => <AdminOrderRecord>[]).add(order);
  }
  return grouped;
}

Map<String, List<AdminOrderRecord>> _groupOrdersByRider(
  List<AdminOrderRecord> orders,
) {
  final grouped = <String, List<AdminOrderRecord>>{};
  for (final order in orders) {
    final riderId = order.driverId?.trim();
    if (riderId == null || riderId.isEmpty) {
      continue;
    }
    grouped.putIfAbsent(riderId, () => <AdminOrderRecord>[]).add(order);
  }
  return grouped;
}

class AdminDailyCsvScheduler {
  AdminDailyCsvScheduler({required this.onExport});

  final Future<void> Function(DateTime reportDate) onExport;

  Timer? _timer;
  String? _lastExportDateKey;

  void start() {
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => _tick());
    unawaited(_tick());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    final now = DateTime.now();
    if (now.hour != 18) {
      return;
    }

    final dateKey = '${now.year}-${now.month}-${now.day}';
    if (_lastExportDateKey == dateKey) {
      return;
    }
    _lastExportDateKey = dateKey;

    try {
      await onExport(DateTime(now.year, now.month, now.day));
    } catch (error, stackTrace) {
      debugPrint('Daily CSV export failed: $error\n$stackTrace');
    }
  }
}

String _csvCell(String value) {
  final sanitized = value.replaceAll('"', '""');
  return '"$sanitized"';
}

String _money(double value) => value.toStringAsFixed(2);

String _formatReportDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$year-$month-$day $hour:$minute';
}
