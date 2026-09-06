class AdminTaxConfig {
  const AdminTaxConfig({
    this.legalName = '',
    this.taxId = '',
    this.branchCode = '00000',
    this.vatRegistered = false,
    this.defaultVatRate = 0.07,
    this.pricesIncludeVat = true,
    this.fiscalYearStartMonth = 1,
  });

  final String legalName;
  final String taxId;
  final String branchCode;
  final bool vatRegistered;
  final double defaultVatRate;
  final bool pricesIncludeVat;
  final int fiscalYearStartMonth;

  factory AdminTaxConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const AdminTaxConfig();
    }
    final month = _readInt(data['fiscalYearStartMonth'], fallback: 1);
    return AdminTaxConfig(
      legalName: (data['legalName'] ?? '').toString(),
      taxId: (data['taxId'] ?? '').toString(),
      branchCode: (data['branchCode'] ?? '00000').toString(),
      vatRegistered: data['vatRegistered'] == true,
      defaultVatRate: _readRate(data['defaultVatRate'], fallback: 0.07),
      pricesIncludeVat: data['pricesIncludeVat'] != false,
      fiscalYearStartMonth: month.clamp(1, 12),
    );
  }

  Map<String, dynamic> toMap({
    required String adminUid,
    String? adminEmail,
  }) {
    return <String, dynamic>{
      'legalName': legalName.trim(),
      'taxId': taxId.trim(),
      'branchCode': branchCode.trim().isEmpty ? '00000' : branchCode.trim(),
      'vatRegistered': vatRegistered,
      'defaultVatRate': defaultVatRate,
      'pricesIncludeVat': pricesIncludeVat,
      'fiscalYearStartMonth': fiscalYearStartMonth,
      'updatedByUid': adminUid,
      if (adminEmail != null && adminEmail.trim().isNotEmpty)
        'updatedByEmail': adminEmail.trim(),
    };
  }
}

class TaxAmountSplit {
  const TaxAmountSplit({
    required this.amountGross,
    required this.amountExVat,
    required this.vatAmount,
    required this.vatRate,
  });

  final double amountGross;
  final double amountExVat;
  final double vatAmount;
  final double vatRate;

  static TaxAmountSplit compute({
    required double grossOrNet,
    required AdminTaxConfig config,
    bool inputIsGross = true,
  }) {
    final base = _roundMoney(grossOrNet);
    if (!config.vatRegistered || base <= 0) {
      return TaxAmountSplit(
        amountGross: base,
        amountExVat: base,
        vatAmount: 0,
        vatRate: 0,
      );
    }
    final rate = config.defaultVatRate > 0 ? config.defaultVatRate : 0.07;
    if (config.pricesIncludeVat || inputIsGross) {
      final exVat = _roundMoney(base / (1 + rate));
      final vat = _roundMoney(base - exVat);
      return TaxAmountSplit(
        amountGross: base,
        amountExVat: exVat,
        vatAmount: vat,
        vatRate: rate,
      );
    }
    final exVat = base;
    final vat = _roundMoney(exVat * rate);
    return TaxAmountSplit(
      amountGross: _roundMoney(exVat + vat),
      amountExVat: exVat,
      vatAmount: vat,
      vatRate: rate,
    );
  }
}

double _readRate(Object? value, {required double fallback}) {
  if (value is num && value >= 0 && value <= 1) {
    return value.toDouble();
  }
  if (value is num && value > 1 && value <= 100) {
    return value.toDouble() / 100;
  }
  return fallback;
}

int _readInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return fallback;
}

double _roundMoney(double value) {
  return (value * 100).roundToDouble() / 100;
}
