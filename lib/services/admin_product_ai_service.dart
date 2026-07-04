import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// AI analysis result from [analyzeProductWithAi] Cloud Function.
class AdminAiProductAnalysisResult {
  const AdminAiProductAnalysisResult({
    this.productName,
    this.description,
    this.taxStatus,
    this.taxReason,
    this.productCategory,
    this.productType,
    this.isLegalInThailand,
    this.legalReason,
    this.isFreshProduct,
    this.isProcessed,
    this.canShipNationwide,
    this.nationwideShippingReason,
    this.productNameConfidence,
    this.taxConfidence,
    this.productTypeConfidence,
    this.nationwideShippingConfidence,
    this.legalConfidence,
    this.parcelLengthCm,
    this.parcelWidthCm,
    this.parcelHeightCm,
    this.parcelDimensionReason,
    this.parcelDimensionConfidence,
    this.saleUnit,
    this.requiresAdminReview,
    this.reviewReasonLabels,
  });

  final String? productName;
  final String? description;
  final String? taxStatus;
  final String? taxReason;
  final String? productCategory;
  final String? productType;
  final bool? isLegalInThailand;
  final String? legalReason;
  final bool? isFreshProduct;
  final bool? isProcessed;
  final bool? canShipNationwide;
  final String? nationwideShippingReason;
  final int? productNameConfidence;
  final int? taxConfidence;
  final int? productTypeConfidence;
  final int? nationwideShippingConfidence;
  final int? legalConfidence;
  final double? parcelLengthCm;
  final double? parcelWidthCm;
  final double? parcelHeightCm;
  final String? parcelDimensionReason;
  final int? parcelDimensionConfidence;
  final String? saleUnit;
  final bool? requiresAdminReview;
  final List<String>? reviewReasonLabels;
}

/// Mutable AI state accumulated on the upload form.
class AdminProductAiState {
  AdminProductAiState();

  bool hasUsedProductAnalysis = false;
  bool hasUsedDescription = false;
  bool isAnalyzing = false;
  bool isGeneratingDescription = false;
  String? queueStatusText;

  String? taxAnalysisReason;
  bool hasTaxAnalysis = false;
  bool? isLegalInThailand;
  String? legalAnalysisReason;
  String? productType;
  bool? canShipNationwide;
  String? nationwideShippingReason;
  String? parcelDimensionReason;
  int? productNameConfidence;
  int? taxConfidence;
  int? productTypeConfidence;
  int? nationwideShippingConfidence;
  int? legalConfidence;
  bool? requiresAdminReview;
  List<String> reviewReasonLabels = <String>[];

  static const int confidenceThreshold = 80;

  bool requiresAdminReviewCheck() {
    if (requiresAdminReview == true) {
      return true;
    }
    if (isLegalInThailand == false) {
      return true;
    }
    if (!hasUsedProductAnalysis) {
      return false;
    }
    final confidences = <int?>[
      productNameConfidence,
      taxConfidence,
      productTypeConfidence,
      nationwideShippingConfidence,
      legalConfidence,
    ];
    return confidences.any(
      (score) => score == null || score < confidenceThreshold,
    );
  }

  Map<String, dynamic> confidenceFields() {
    return <String, dynamic>{
      if (productNameConfidence != null)
        'aiProductNameConfidence': productNameConfidence,
      if (taxConfidence != null) 'aiTaxConfidence': taxConfidence,
      if (productTypeConfidence != null)
        'aiProductTypeConfidence': productTypeConfidence,
      if (nationwideShippingConfidence != null)
        'aiNationwideShippingConfidence': nationwideShippingConfidence,
      if (legalConfidence != null) 'aiLegalConfidence': legalConfidence,
      'aiRequiresAdminReview': requiresAdminReviewCheck(),
      if (reviewReasonLabels.isNotEmpty)
        'aiReviewReasonLabels': reviewReasonLabels,
    };
  }

  void applyStoredReview(Map<String, dynamic> data) {
    hasUsedProductAnalysis = data['aiProductAnalysisRequested'] == true;
    hasUsedDescription = data['aiDescriptionRequested'] == true;
    final taxReason = data['taxAiReason']?.toString().trim();
    if (taxReason != null && taxReason.isNotEmpty) {
      taxAnalysisReason = taxReason;
      hasTaxAnalysis = true;
    }
    if (data['aiIsLegalInThailand'] is bool) {
      isLegalInThailand = data['aiIsLegalInThailand'] as bool;
    }
    final legalReason = data['aiLegalAnalysisReason']?.toString().trim();
    if (legalReason != null && legalReason.isNotEmpty) {
      legalAnalysisReason = legalReason;
    }
    final type = data['aiProductType']?.toString().trim();
    if (type != null && type.isNotEmpty) {
      productType = type;
    }
    if (data['canShipNationwide'] is bool) {
      canShipNationwide = data['canShipNationwide'] as bool;
    }
    final shipReason = data['nationwideShippingReason']?.toString().trim();
    if (shipReason != null && shipReason.isNotEmpty) {
      nationwideShippingReason = shipReason;
    }
    productNameConfidence = _readInt(data['aiProductNameConfidence']);
    taxConfidence = _readInt(data['aiTaxConfidence']);
    productTypeConfidence = _readInt(data['aiProductTypeConfidence']);
    nationwideShippingConfidence = _readInt(data['aiNationwideShippingConfidence']);
    legalConfidence = _readInt(data['aiLegalConfidence']);
    if (data['aiRequiresAdminReview'] is bool) {
      requiresAdminReview = data['aiRequiresAdminReview'] as bool;
    }
    final labels = data['aiReviewReasonLabels'];
    if (labels is List) {
      reviewReasonLabels = labels
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }
  }

  static int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  void applyAnalysis(AdminAiProductAnalysisResult result) {
    if ((result.taxReason ?? '').trim().isNotEmpty) {
      taxAnalysisReason = result.taxReason!.trim();
      hasTaxAnalysis = true;
    }
    if (result.isLegalInThailand != null) {
      isLegalInThailand = result.isLegalInThailand;
    }
    if ((result.legalReason ?? '').trim().isNotEmpty) {
      legalAnalysisReason = result.legalReason!.trim();
    }
    if ((result.productType ?? '').trim().isNotEmpty) {
      productType = result.productType!.trim();
    }
    if (result.canShipNationwide != null) {
      canShipNationwide = result.canShipNationwide;
    }
    if ((result.nationwideShippingReason ?? '').trim().isNotEmpty) {
      nationwideShippingReason = result.nationwideShippingReason!.trim();
    }
    if ((result.parcelDimensionReason ?? '').trim().isNotEmpty) {
      parcelDimensionReason = result.parcelDimensionReason!.trim();
    }
    productNameConfidence = result.productNameConfidence;
    taxConfidence = result.taxConfidence;
    productTypeConfidence = result.productTypeConfidence;
    nationwideShippingConfidence = result.nationwideShippingConfidence;
    legalConfidence = result.legalConfidence;
    requiresAdminReview = result.requiresAdminReview;
    reviewReasonLabels = List<String>.from(
      result.reviewReasonLabels ?? const <String>[],
    );
    if (result.taxStatus?.trim().toLowerCase() == 'taxable' ||
        result.taxStatus?.trim().toLowerCase() == 'exempt' ||
        (result.taxReason ?? '').trim().isNotEmpty) {
      hasTaxAnalysis = true;
    }
  }
}

class AdminProductAiService {
  AdminProductAiService._();

  static const Duration _callableTimeout = Duration(seconds: 120);

  static HttpsCallable _callable(String name) {
    return FirebaseFunctions.instanceFor(region: 'asia-southeast1').httpsCallable(
      name,
      options: HttpsCallableOptions(timeout: _callableTimeout),
    );
  }

  static String createRequestId() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
    return '${uid}_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  static StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? listenQueueStatus({
    required String requestId,
    required void Function(String? statusText) onStatus,
  }) {
    return FirebaseFirestore.instance
        .collection('ai_processing_queue')
        .doc(requestId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!snapshot.exists) {
              return;
            }
            onStatus(_buildQueueText(snapshot.data() ?? <String, dynamic>{}));
          },
          onError: (_) => onStatus('กำลังเข้าคิว AI...'),
        );
  }

  static String _buildQueueText(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    final position =
        data['position'] is num ? (data['position'] as num).toInt() : null;
    final estimatedSeconds = data['estimatedWaitSeconds'] is num
        ? (data['estimatedWaitSeconds'] as num).toInt()
        : null;
    final message = (data['message'] ?? '').toString().trim();

    if (status == 'queued') {
      final positionText =
          position != null && position > 0 ? 'คิวที่ $position' : 'กำลังรอคิว';
      final waitText =
          estimatedSeconds != null ? ' ${_formatWait(estimatedSeconds)}' : '';
      return '$positionText$waitText';
    }
    if (status == 'processing') {
      return 'ถึงคิวแล้ว กำลังประมวลผล AI...';
    }
    if (status == 'rejected') {
      return message.isNotEmpty
          ? message
          : 'คิว AI เยอะมาก กรุณาลองวิเคราะห์สินค้าใหม่ภายหลัง';
    }
    if (status == 'failed') {
      return message.isNotEmpty ? message : 'AI ประมวลผลไม่สำเร็จ';
    }
    if (status == 'completed') {
      return 'ประมวลผล AI สำเร็จ';
    }
    return 'กำลังส่งคำขอ AI...';
  }

  static String _formatWait(int seconds) {
    if (seconds <= 0) {
      return 'อีกสักครู่';
    }
    if (seconds < 60) {
      return 'ประมาณ $seconds วินาที';
    }
    return 'ประมาณ ${(seconds / 60).ceil()} นาที';
  }

  static String functionErrorMessage(FirebaseFunctionsException error) {
    final details = error.details;
    if (details is Map && details['externalAiRecommended'] == true) {
      final position = details['queuePosition'] is num
          ? (details['queuePosition'] as num).toInt()
          : null;
      final estimatedSeconds = details['estimatedWaitSeconds'] is num
          ? (details['estimatedWaitSeconds'] as num).toInt()
          : null;
      final queueText = position != null ? 'คิวที่ $position' : 'คิว AI เยอะมาก';
      final waitText =
          estimatedSeconds != null ? ' ${_formatWait(estimatedSeconds)}' : '';
      return '$queueText$waitText ระบบ AI ยังไม่พร้อม กรุณาลองใหม่ภายหลัง';
    }
    if (error.code == 'deadline-exceeded') {
      return 'AI ใช้เวลานานเกินไป (คิวเต็มหรือเครือข่ายช้า) กรุณารอสักครู่แล้วลองใหม่';
    }
    return error.message ?? 'AI วิเคราะห์สินค้าไม่สำเร็จ (${error.code})';
  }

  static Future<AdminAiProductAnalysisResult> analyzeProduct({
    required Uint8List imageBytes,
    required String mimeType,
    required String productName,
    required String description,
    required String category,
    required String price,
    required String unit,
    required String weight,
    required String weightUnit,
    void Function(String? queueText)? onQueueStatus,
  }) async {
    final requestId = createRequestId();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    subscription = listenQueueStatus(
      requestId: requestId,
      onStatus: onQueueStatus ?? (_) {},
    );
    onQueueStatus?.call('กำลังส่งคำขอ AI...');

    try {
      final response = await _callable('analyzeProductWithAi').call(
        <String, dynamic>{
          'requestId': requestId,
          'imageBase64': base64Encode(imageBytes),
          'mimeType': mimeType,
          'productName': productName,
          'description': description,
          'category': category,
          'price': price,
          'unit': unit,
          'weight': weight,
          'weightUnit': weightUnit,
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw Exception('รูปแบบข้อมูลจาก AI ไม่ถูกต้อง');
      }
      return _parseAnalysisResult(data);
    } finally {
      await subscription?.cancel();
    }
  }

  static Future<String> generateDescription({
    required String productName,
    required String category,
    required String price,
    required String unit,
    required String stock,
    void Function(String? queueText)? onQueueStatus,
  }) async {
    final requestId = createRequestId();
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subscription;
    subscription = listenQueueStatus(
      requestId: requestId,
      onStatus: onQueueStatus ?? (_) {},
    );
    onQueueStatus?.call('กำลังส่งคำขอ AI...');

    try {
      final response = await _callable('askGeminiFlash').call(
        <String, dynamic>{
          'requestId': requestId,
          'prompt':
              'ช่วยเขียนคำอธิบายสินค้าเป็นภาษาไทยประมาณ 2 บรรทัด อ่านเป็นธรรมชาติ น่าเชื่อถือ และเน้นการขายสำหรับร้านค้าออนไลน์',
          'productName': productName,
          'category': category,
          'price': price,
          'unit': unit,
          'stock': stock,
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        final text = data['text']?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          return text;
        }
      }
      throw Exception('AI ไม่ได้ส่งข้อความกลับมา');
    } finally {
      await subscription?.cancel();
    }
  }

  static AdminAiProductAnalysisResult _parseAnalysisResult(Map<dynamic, dynamic> data) {
    return AdminAiProductAnalysisResult(
      productName: (data['productName'] ?? '').toString().trim(),
      description: (data['description'] ?? '').toString().trim(),
      taxStatus: (data['taxStatus'] ?? '').toString().trim(),
      taxReason: (data['taxReason'] ?? '').toString().trim(),
      productCategory: (data['productCategory'] ?? '').toString().trim(),
      productType: (data['productType'] ?? '').toString().trim(),
      isLegalInThailand: data['isLegalInThailand'] is bool
          ? data['isLegalInThailand'] as bool
          : null,
      legalReason: (data['legalReason'] ?? '').toString().trim(),
      isFreshProduct:
          data['isFreshProduct'] is bool ? data['isFreshProduct'] as bool : null,
      isProcessed:
          data['isProcessed'] is bool ? data['isProcessed'] as bool : null,
      canShipNationwide: data['canShipNationwide'] is bool
          ? data['canShipNationwide'] as bool
          : null,
      nationwideShippingReason:
          (data['nationwideShippingReason'] ?? '').toString().trim(),
      productNameConfidence: _parseConfidence(data['productNameConfidence']),
      taxConfidence: _parseConfidence(data['taxConfidence']),
      productTypeConfidence: _parseConfidence(data['productTypeConfidence']),
      nationwideShippingConfidence:
          _parseConfidence(data['nationwideShippingConfidence']),
      legalConfidence: _parseConfidence(data['legalConfidence']),
      parcelLengthCm: _parseParcelCm(data['parcelLengthCm']),
      parcelWidthCm: _parseParcelCm(data['parcelWidthCm']),
      parcelHeightCm: _parseParcelCm(data['parcelHeightCm']),
      parcelDimensionReason:
          (data['parcelDimensionReason'] ?? '').toString().trim(),
      parcelDimensionConfidence:
          _parseConfidence(data['parcelDimensionConfidence']),
      saleUnit: (data['saleUnit'] ?? '').toString().trim(),
      requiresAdminReview: data['requiresAdminReview'] is bool
          ? data['requiresAdminReview'] as bool
          : null,
      reviewReasonLabels: _parseStringList(data['reviewReasonLabels']),
    );
  }

  static int? _parseConfidence(Object? value) {
    if (value is int) {
      return value.clamp(0, 100);
    }
    if (value is double) {
      return value.round().clamp(0, 100);
    }
    final parsed = int.tryParse(value?.toString() ?? '');
    return parsed?.clamp(0, 100);
  }

  static double? _parseParcelCm(Object? value) {
    if (value is num) {
      final parsed = value.toDouble();
      if (parsed > 0 && parsed <= 200) {
        return parsed;
      }
      return null;
    }
    final parsed = double.tryParse(value?.toString().trim() ?? '');
    if (parsed == null || parsed <= 0 || parsed > 200) {
      return null;
    }
    return parsed;
  }

  static List<String>? _parseStringList(Object? value) {
    if (value is! List) {
      return null;
    }
    final labels = value
        .map((entry) => entry?.toString().trim() ?? '')
        .where((String entry) => entry.isNotEmpty)
        .toList(growable: false);
    return labels.isEmpty ? null : labels;
  }

  static String mimeTypeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) {
      return 'image/heic';
    }
    return 'image/jpeg';
  }
}
