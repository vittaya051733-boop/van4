import 'package:flutter_test/flutter_test.dart';
import 'package:van4/services/admin_project_finance_service.dart';

void main() {
  group('calculateRoiPercent', () {
    test('returns null when initial investment is zero', () {
      expect(
        AdminProjectFinanceService.calculateRoiPercent(
          initialInvestmentBaht: 0,
          netProfitBaht: 1000,
        ),
        isNull,
      );
    });

    test('calculates ROI from net profit over investment', () {
      expect(
        AdminProjectFinanceService.calculateRoiPercent(
          initialInvestmentBaht: 100000,
          netProfitBaht: 25000,
        ),
        25,
      );
    });
  });
}
