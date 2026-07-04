import 'package:flutter_test/flutter_test.dart';

import 'package:van4/admin_order_support.dart';
import 'package:van4/admin_settlement_support.dart';
import 'package:van4/admin_repository.dart';

void main() {
  test('parse payout result csv reads transfer_status', () {
    const raw = '''
payout_type,order_number,order_code,order_id,transfer_status,transfer_reference,paid_at
shop,ORD1,ORD1,order123,paid,KBANK-001,2026-06-01 18:00
''';

    final rows = AdminSettlementSupport.parsePayoutResultCsv(raw);
    expect(rows, hasLength(1));
    expect(rows.first.payoutType, 'shop');
    expect(rows.first.orderCode, 'ORD1');
    expect(rows.first.orderId, 'order123');
    expect(rows.first.transferStatus, 'paid');
  });

  test('parse accepts order_number only column name', () {
    const raw = '''
payout_type,order_number,transfer_status
rider,ORD9,paid
''';

    final rows = AdminSettlementSupport.parsePayoutResultCsv(raw);
    expect(rows.single.orderCode, 'ORD9');
  });

  test('shipping csv groups rider with bank transfer fields', () {
    const banks = AdminSettlementBankDirectory(
      shopsByOwnerId: <String, AdminBankProfile>{},
      ridersById: <String, AdminBankProfile>{
        'rider1': AdminBankProfile(
          bankName: 'ธนาคารกสิกรไทย (KBank)',
          accountNumber: '1234567890',
          accountName: 'นายไรเดอร์',
        ),
      },
      leader: AdminLeaderProfile.empty,
    );
    final orders = <AdminOrderRecord>[
      _testOrder(
        id: 'order1',
        orderCode: 'ORD-100',
        driverId: 'rider1',
        shippingFee: 100,
      ),
      _testOrder(
        id: 'order2',
        orderCode: 'ORD-101',
        driverId: 'rider1',
        shippingFee: 50,
      ),
    ];

    final csv = buildShippingSettlementCsv(
      reportDate: DateTime(2026, 6, 13),
      orders: orders,
      banks: banks,
    );

    expect(
      csv.split('\n').first,
      'วันที่รายงาน,หมายเลขออเดอร์,ชื่อผู้รับ,ชื่อธนาคาร,เลขที่บัญชี,ชื่อบัญชี,ยอดค่าส่งแต่ละออเดอร์,ยอดโอนรวม',
    );
    expect(csv, contains('ORD-100, ORD-101'));
    expect(csv, contains('ธนาคารกสิกรไทย (KBank)'));
    expect(csv, contains('127.50'));
  });

  test('shop csv groups same shop into one transfer row', () {
    const banks = AdminSettlementBankDirectory(
      shopsByOwnerId: <String, AdminBankProfile>{
        'shop1': AdminBankProfile(
          bankName: 'ธนาคารกรุงเทพ (BBL)',
          accountNumber: '9999999999',
          accountName: 'ร้านทดสอบ',
        ),
      },
      ridersById: <String, AdminBankProfile>{},
      leader: AdminLeaderProfile.empty,
    );
    final orders = <AdminOrderRecord>[
      _testOrder(
        id: 'order1',
        orderCode: 'ORD-A',
        shopOwnerId: 'shop1',
        shopName: 'ร้าน A',
        subtotal: 1000,
      ),
      _testOrder(
        id: 'order2',
        orderCode: 'ORD-B',
        shopOwnerId: 'shop1',
        shopName: 'ร้าน A',
        subtotal: 500,
      ),
    ];

    final csv = buildShopSettlementCsv(
      reportDate: DateTime(2026, 6, 13),
      orders: orders,
      banks: banks,
    );

    final dataLines = csv
        .split('\n')
        .where((line) => line.startsWith('"2026'))
        .toList();
    expect(dataLines, hasLength(1));
    expect(csv, contains('ORD-A, ORD-B'));
    expect(csv, contains('ORD-A:1000.00; ORD-B:500.00'));
    expect(csv, contains('ธนาคารกรุงเทพ (BBL)'));
    expect(csv, contains('1045.50'));
  });

  test('fee rates affect shop net payout', () {
    const lowGp = AdminSettlementFeeRates(gpRate: 0.10);
    const highGp = AdminSettlementFeeRates(gpRate: 0.20);
    final order = _testOrder(subtotal: 1000);

    expect(order.shopNetPayout(lowGp), greaterThan(order.shopNetPayout(highGp)));
  });
}

AdminOrderRecord _testOrder({
  String id = 'order1',
  String? orderCode,
  String? driverId,
  String? shopOwnerId,
  String? shopName,
  double? subtotal,
  double? shippingFee,
}) {
  return AdminOrderRecord(
    id: id,
    orderCode: orderCode,
    status: 'delivered',
    statusLabel: 'delivered',
    customerId: null,
    shopOwnerId: shopOwnerId,
    driverId: driverId,
    grandTotal: subtotal,
    subtotal: subtotal,
    shippingFee: shippingFee,
    sourceApp: null,
    paymentStatus: null,
    paymentMethod: null,
    createdAt: null,
    deliveredAt: null,
    cancelledAt: null,
    shopName: shopName,
    customerName: null,
    driverName: 'ไรเดอร์ทดสอบ',
    cancelReason: null,
    refundRequested: false,
    refundStatus: null,
    refundBankName: null,
    refundAccountName: null,
    refundBankAccountNumber: null,
    deliveryProofImageUrl: null,
    shopImageUrl: null,
    items: const <AdminOrderLineItem>[],
    rawData: const <String, dynamic>{},
  );
}
