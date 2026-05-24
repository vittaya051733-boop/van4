import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import 'admin_repository.dart';

enum AdminOrderCategory {
  success,
  unsuccessful,
  cancelled,
  refund,
}

/// อัตราหักสำหรับสรุป CSV ฝั่งแอดมิน
class AdminSettlementRates {
  AdminSettlementRates._();

  static const double gpRate = 0.18;
  static const double leaderRate = 0.15;
  static const double shippingPlatformRate = 0.15;

  static double afterGp(double productSubtotal) => productSubtotal * (1 - gpRate);

  static double shopNet(double productSubtotal) =>
      afterGp(productSubtotal) * (1 - leaderRate);

  static double shippingPlatformFee(double grossShipping) =>
      grossShipping * shippingPlatformRate;

  static double riderNetShipping(double grossShipping) =>
      grossShipping * (1 - shippingPlatformRate);
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

  double get gpDeduction =>
      resolvedProductSubtotal * AdminSettlementRates.gpRate;

  double get afterGpDeduction =>
      AdminSettlementRates.afterGp(resolvedProductSubtotal);

  double get leaderDeduction =>
      afterGpDeduction * AdminSettlementRates.leaderRate;

  double get shopNetPayout => AdminSettlementRates.shopNet(resolvedProductSubtotal);

  double get shippingPlatformFee =>
      AdminSettlementRates.shippingPlatformFee(resolvedShippingFee);

  double get riderNetShippingIncome =>
      AdminSettlementRates.riderNetShipping(resolvedShippingFee);

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
}) {
  final dateKey =
      '${reportDate.year}${reportDate.month.toString().padLeft(2, '0')}${reportDate.day.toString().padLeft(2, '0')}';

  AdminCsvExportFile named(String suffix, String content) {
    return AdminCsvExportFile(
      name: 'van_admin_${suffix}_$dateKey.csv',
      content: content,
    );
  }

  return AdminDailyCsvBundle(
    reportDate: reportDate,
    files: <AdminCsvExportFile>[
      named(
        'shipping',
        buildShippingSettlementCsv(reportDate: reportDate, orders: orders),
      ),
      named(
        'products',
        buildProductsSettlementCsv(reportDate: reportDate, orders: orders),
      ),
      named(
        'refunds',
        buildRefundsSettlementCsv(reportDate: reportDate, orders: orders),
      ),
      named(
        'shop',
        buildShopSettlementCsv(reportDate: reportDate, orders: orders),
      ),
    ],
  );
}

Future<void> exportAndShareDailySettlementCsvFiles({
  required DateTime reportDate,
  required List<AdminOrderRecord> orders,
}) async {
  final bundle = buildAllDailySettlementCsvBundle(
    reportDate: reportDate,
    orders: orders,
  );
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
}) {
  final delivered = filterDeliveredOrders(orders);
  final buffer = StringBuffer()
    ..writeln(
      'report_date,order_code,order_id,shop,rider,gross_shipping,platform_fee_15pct,rider_net_85pct,delivered_at',
    );

  var totalGross = 0.0;
  var totalPlatform = 0.0;
  var totalRiderNet = 0.0;

  for (final order in delivered) {
    final gross = order.resolvedShippingFee;
    final platform = order.shippingPlatformFee;
    final riderNet = order.riderNetShippingIncome;
    totalGross += gross;
    totalPlatform += platform;
    totalRiderNet += riderNet;

    buffer.writeln(
      [
        _csvCell(_formatReportDate(reportDate)),
        _csvCell(order.displayOrderNumber),
        _csvCell(order.id),
        _csvCell(order.shopName ?? order.shopOwnerId ?? ''),
        _csvCell(order.driverName ?? order.driverId ?? ''),
        _csvCell(_money(gross)),
        _csvCell(_money(platform)),
        _csvCell(_money(riderNet)),
        _csvCell(order.deliveredAt != null ? _formatDateTime(order.deliveredAt!) : ''),
      ].join(','),
    );
  }

  buffer
    ..writeln()
    ..writeln('summary_field,amount')
    ..writeln('order_count,${delivered.length}')
    ..writeln('total_gross_shipping,${_money(totalGross)}')
    ..writeln('total_platform_fee_15pct,${_money(totalPlatform)}')
    ..writeln('total_rider_net_85pct,${_money(totalRiderNet)}');

  return buffer.toString();
}

String buildProductsSettlementCsv({
  required DateTime reportDate,
  required List<AdminOrderRecord> orders,
}) {
  final delivered = filterDeliveredOrders(orders);
  final buffer = StringBuffer()
    ..writeln(
      'report_date,order_code,order_id,shop,product_subtotal,item_count,delivered_at',
    );

  var totalProducts = 0.0;

  for (final order in delivered) {
    final productTotal = order.resolvedProductSubtotal;
    totalProducts += productTotal;

    buffer.writeln(
      [
        _csvCell(_formatReportDate(reportDate)),
        _csvCell(order.displayOrderNumber),
        _csvCell(order.id),
        _csvCell(order.shopName ?? order.shopOwnerId ?? ''),
        _csvCell(_money(productTotal)),
        _csvCell('${order.items.length}'),
        _csvCell(order.deliveredAt != null ? _formatDateTime(order.deliveredAt!) : ''),
      ].join(','),
    );
  }

  buffer
    ..writeln()
    ..writeln('summary_field,amount')
    ..writeln('order_count,${delivered.length}')
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
      'report_date,order_code,order_id,shop,customer,status,refund_status,refund_amount,bank,account_name,account_number,cancel_reason,updated_at',
    );

  var totalRefund = 0.0;

  for (final order in refunds) {
    final amount = order.refundAmount;
    totalRefund += amount;
    final updatedAt = order.cancelledAt ?? order.deliveredAt ?? order.createdAt;

    buffer.writeln(
      [
        _csvCell(_formatReportDate(reportDate)),
        _csvCell(order.displayOrderNumber),
        _csvCell(order.id),
        _csvCell(order.shopName ?? order.shopOwnerId ?? ''),
        _csvCell(order.customerName ?? order.customerId ?? ''),
        _csvCell(order.status),
        _csvCell(order.refundStatus ?? ''),
        _csvCell(_money(amount)),
        _csvCell(order.refundBankName ?? ''),
        _csvCell(order.refundAccountName ?? ''),
        _csvCell(order.refundBankAccountNumber ?? ''),
        _csvCell(order.cancelReason ?? ''),
        _csvCell(updatedAt != null ? _formatDateTime(updatedAt) : ''),
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
}) {
  final delivered = filterDeliveredOrders(orders);
  final buffer = StringBuffer()
    ..writeln(
      'report_date,order_code,order_id,shop,shop_owner_id,product_subtotal,gp_deduct_18pct,after_gp,leader_deduct_15pct,shop_net_payout,delivered_at',
    );

  var totalSubtotal = 0.0;
  var totalGp = 0.0;
  var totalAfterGp = 0.0;
  var totalLeader = 0.0;
  var totalShopNet = 0.0;

  for (final order in delivered) {
    final subtotal = order.resolvedProductSubtotal;
    final gp = order.gpDeduction;
    final afterGp = order.afterGpDeduction;
    final leader = order.leaderDeduction;
    final shopNet = order.shopNetPayout;

    totalSubtotal += subtotal;
    totalGp += gp;
    totalAfterGp += afterGp;
    totalLeader += leader;
    totalShopNet += shopNet;

    buffer.writeln(
      [
        _csvCell(_formatReportDate(reportDate)),
        _csvCell(order.displayOrderNumber),
        _csvCell(order.id),
        _csvCell(order.shopName ?? ''),
        _csvCell(order.shopOwnerId ?? ''),
        _csvCell(_money(subtotal)),
        _csvCell(_money(gp)),
        _csvCell(_money(afterGp)),
        _csvCell(_money(leader)),
        _csvCell(_money(shopNet)),
        _csvCell(order.deliveredAt != null ? _formatDateTime(order.deliveredAt!) : ''),
      ].join(','),
    );
  }

  buffer
    ..writeln()
    ..writeln('summary_field,amount')
    ..writeln('order_count,${delivered.length}')
    ..writeln('total_product_subtotal,${_money(totalSubtotal)}')
    ..writeln('total_gp_deduct_18pct,${_money(totalGp)}')
    ..writeln('total_after_gp,${_money(totalAfterGp)}')
    ..writeln('total_leader_deduct_15pct,${_money(totalLeader)}')
    ..writeln('total_shop_net_payout,${_money(totalShopNet)}');

  return buffer.toString();
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
