class HomePageLockConfig {
  const HomePageLockConfig({
    required this.enabled,
    required this.message,
  });

  static const String defaultMessage =
      'กำลังปรับปรุงระบบ ขออภัยในความไม่สะดวก\nกรุณากลับมาใหม่ภายหลัง';

  static const HomePageLockConfig defaults = HomePageLockConfig(
    enabled: false,
    message: defaultMessage,
  );

  final bool enabled;
  final String message;

  factory HomePageLockConfig.fromFirestore(Map<String, dynamic>? data) {
    final raw = data?['homeLock'];
    if (raw is! Map) {
      return defaults;
    }

    final message = (raw['message'] ?? '').toString().trim();
    return HomePageLockConfig(
      enabled: raw['enabled'] == true,
      message: message.isEmpty ? defaultMessage : message,
    );
  }

  factory HomePageLockConfig.fromLocal({
    required bool enabled,
    required String message,
  }) {
    final trimmed = message.trim();
    return HomePageLockConfig(
      enabled: enabled,
      message: trimmed.isEmpty ? defaultMessage : trimmed,
    );
  }

  String get signature => '$enabled|$message';
}
