String normalizeNationalId(Object? raw) {
  return (raw?.toString() ?? '').replaceAll(RegExp(r'\D'), '');
}

bool validateThaiNationalIdChecksum(String id) {
  final digits = normalizeNationalId(id);
  if (digits.length != 13) {
    return false;
  }
  var sum = 0;
  for (var i = 0; i < 12; i++) {
    sum += int.parse(digits[i]) * (13 - i);
  }
  final check = (11 - (sum % 11)) % 10;
  return check == int.parse(digits[12]);
}

String maskNationalId(String id) {
  final digits = normalizeNationalId(id);
  if (digits.length != 13) {
    return '';
  }
  return '${digits.substring(0, 1)}*********${digits.substring(10)}';
}

bool isPseudoVanEmail(String email) {
  final normalized = email.trim().toLowerCase();
  return normalized.endsWith('@phone.vanmerchant.app') ||
      normalized.endsWith('@van-customer.local') ||
      normalized.endsWith('@van-merchant.local');
}
