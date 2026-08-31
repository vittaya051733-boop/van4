class AdminClaimRequestItem {
  const AdminClaimRequestItem({
    required this.productId,
    required this.name,
    required this.quantity,
    this.unitPrice,
    this.imageUrl,
  });

  final String productId;
  final String name;
  final int quantity;
  final double? unitPrice;
  final String? imageUrl;

  factory AdminClaimRequestItem.fromMap(Map<dynamic, dynamic> raw) {
    return AdminClaimRequestItem(
      productId: _readString(raw['productId']) ?? '',
      name: _readString(raw['name']) ?? 'สินค้า',
      quantity: _readInt(raw['quantity']) ?? 1,
      unitPrice: _readDouble(raw['unitPrice']),
      imageUrl: _readString(raw['imageUrl']),
    );
  }
}

class AdminClaimRequest {
  const AdminClaimRequest({
    required this.items,
    required this.reason,
    required this.status,
    this.claimId,
  });

  static const String topicKey = 'product_claim';

  final List<AdminClaimRequestItem> items;
  final String reason;
  final String status;
  final String? claimId;

  bool get isPending => status == 'pending';

  Map<String, int> get selectedQuantities {
    final map = <String, int>{};
    for (final item in items) {
      final id = item.productId.trim();
      if (id.isEmpty || item.quantity <= 0) {
        continue;
      }
      map[id] = item.quantity;
    }
    return map;
  }

  static AdminClaimRequest? fromMap(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final data = Map<dynamic, dynamic>.from(raw);
    final rawItems = data['items'];
    final items = <AdminClaimRequestItem>[];
    if (rawItems is List) {
      for (final entry in rawItems) {
        if (entry is Map) {
          items.add(AdminClaimRequestItem.fromMap(entry));
        }
      }
    }
    if (items.isEmpty && _readString(data['reason']) == null) {
      return null;
    }
    return AdminClaimRequest(
      items: items,
      reason: _readString(data['reason']) ?? 'other',
      status: _readString(data['status']) ?? 'pending',
      claimId: _readString(data['claimId']),
    );
  }

  static String reasonLabel(String reason) {
    switch (reason) {
      case 'mismatch':
        return 'ไม่ตรงปก';
      case 'damaged':
        return 'เสียหาย';
      case 'wrong_item':
        return 'ส่งผิดชิ้น';
      case 'other':
        return 'อื่น ๆ';
      default:
        return reason;
    }
  }

  String get reasonLabelText => reasonLabel(reason);
}

String? _readString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
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
