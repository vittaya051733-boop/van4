import 'dart:async';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'admin_repository.dart';
import 'admin_image_widgets.dart';
import 'services/admin_product_ai_service.dart';
import 'utils/app_colors.dart';

part 'admin_product_form_ui.dart';

/// Admin (van4) uploads a product on behalf of a shop.
class AdminProductUploadContext {
  const AdminProductUploadContext({
    required this.ownerUid,
    required this.shopName,
    required this.serviceType,
  });

  final String ownerUid;
  final String shopName;
  final String serviceType;

  AdminShopRecord toShopRecord() {
    return AdminShopRecord(
      id: ownerUid,
      collection: 'public_shops',
      displayName: shopName,
      serviceType: serviceType,
      status: 'approved',
      ownerId: ownerUid,
      phone: null,
      email: null,
      imageUrl: null,
      createdAt: null,
      address: null,
      isProfileCompleted: true,
    );
  }
}

class AdminAddProductScreen extends StatefulWidget {
  const AdminAddProductScreen({
    super.key,
    required this.uploadContext,
    this.editReviewId,
  });

  final AdminProductUploadContext uploadContext;
  final String? editReviewId;

  bool get isEditingPendingReview => editReviewId != null;

  @override
  State<AdminAddProductScreen> createState() => _AdminAddProductScreenState();
}

class _AdminAddProductScreenState extends State<AdminAddProductScreen> {
  static const double _gpRate = 0.18;
  static const List<String> _units = <String>[
    'ชิ้น',
    'ถุง',
    'แพ็ค',
    'มัด',
    'ลูก',
    'กล่อง',
    'อื่นๆ',
  ];
  static const List<String> _productCategories = <String>[
    'ของสด',
    'อาหารแปรรูป',
    'สินค้าทั่วไป',
    'ร้านขายยาและเวชภัณฑ์',
    'สินค้าเกษตร',
  ];

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _toppingsController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController(text: '1');
  final _preparationTimeController = TextEditingController(text: '10');
  final _weightController = TextEditingController();
  final _parcelLengthController = TextEditingController();
  final _parcelWidthController = TextEditingController();
  final _parcelHeightController = TextEditingController();
  final _otherUnitController = TextEditingController();
  final _colorsController = TextEditingController();
  final _sizesController = TextEditingController();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _toppingsFocusNode = FocusNode();
  final ImagePicker _picker = ImagePicker();
  final AdminProductAiState _ai = AdminProductAiState();

  final List<XFile> _imageFiles = <XFile>[];
  final List<String> _existingImageUrls = <String>[];
  int _maxImageCount = 1;
  bool _canUploadVideo = false;
  bool _loadingSettings = true;
  bool _loadingReview = false;
  bool _saving = false;
  String? _uploadStatusText;
  bool _aiReanalyzedInEdit = false;
  bool _showPriceGuidance = false;
  bool _showPreparationTimeGuidance = false;
  bool _showToppingsGuidance = false;
  bool _priceGuidanceDismissedWhileFocused = false;
  bool _manualCanShipNationwide = false;

  bool get _isEditingPendingReview => widget.editReviewId != null;
  int get _currentImageCount => _totalImageCount;
  int get _totalImageCount => _existingImageUrls.length + _imageFiles.length;
  bool get _canAddVideo => _canUploadVideo;
  bool get _isResolvingServiceType => _loadingSettings || _loadingReview;
  bool get _canPickMoreImages =>
      _currentImageCount < _maxImageCount && !_ai.isAnalyzing;

  bool get _canRunProductAnalysis =>
      !_ai.isAnalyzing &&
      !_saving &&
      (!_ai.hasUsedProductAnalysis ||
          (_isEditingPendingReview && _aiReanalyzedInEdit == false));

  String? _mediaLimitHintText() {
    if (_isResolvingServiceType) {
      return 'กำลังตรวจสอบสิทธิ์การอัปโหลดรูปและวิดีโอ';
    }
    if (_maxImageCount == 1 && !_canAddVideo) {
      return 'อัปโหลดรูปได้ 1 รูป — วิดีโอและรูปเพิ่มต้องให้แอดมินอนุญาตก่อน';
    }
    return 'อัปโหลดรูปได้สูงสุด $_maxImageCount รูป${_canAddVideo ? ' และวิดีโอ' : ''}';
  }

  String _formatPriceDisplay(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _hideFieldGuidance() {
    if (!_showPriceGuidance &&
        !_showPreparationTimeGuidance &&
        !_showToppingsGuidance) {
      return;
    }
    setState(() {
      _showPriceGuidance = false;
      _showPreparationTimeGuidance = false;
      _showToppingsGuidance = false;
    });
  }

  Future<void> _captureImage() =>
      _pickImages(source: ImageSource.camera);

  Future<void> _pickImagesFromGallery() =>
      _pickImages(source: ImageSource.gallery);

  void _pickVideoPlaceholder() {
    _showSnack('ยังไม่รองรับการอัปโหลดวิดีโอในแอปแอดมิน');
  }

  String? _selectedUnit = 'ชิ้น';
  String? _selectedProductCategory;
  bool _isFreshProduct = false;
  bool _isProcessed = false;
  bool _pharmacyIsTaxable = true;
  String _weightUnit = 'g';

  @override
  void initState() {
    super.initState();
    _priceFocusNode.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        if (_priceFocusNode.hasFocus) {
          _showPriceGuidance = !_priceGuidanceDismissedWhileFocused;
          _showToppingsGuidance = false;
        } else {
          _priceGuidanceDismissedWhileFocused = false;
          _showPriceGuidance = false;
        }
      });
    });
    _toppingsFocusNode.addListener(() {
      if (!mounted) {
        return;
      }
      setState(() {
        _showToppingsGuidance = _toppingsFocusNode.hasFocus;
        if (_toppingsFocusNode.hasFocus) {
          _showPriceGuidance = false;
          _showPreparationTimeGuidance = false;
        }
      });
    });
    if (_isEditingPendingReview) {
      _loadReviewForEdit();
    } else {
      _loadMediaSettings();
    }
  }

  Future<void> _loadReviewForEdit() async {
    setState(() => _loadingReview = true);
    try {
      final draft = await AdminRepository.fetchPendingProductReviewDraft(
        widget.editReviewId!,
      );
      if (!mounted) {
        return;
      }
      _applyReviewDraft(draft);
      await _loadMediaSettings();
    } catch (error) {
      if (mounted) {
        _showSnack('โหลดข้อมูลแก้ไขไม่สำเร็จ: $error');
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _loadingReview = false);
      }
    }
  }

  void _applyReviewDraft(AdminPendingReviewDraft draft) {
    _nameController.text = draft.name;
    _descriptionController.text = draft.description;
    _toppingsController.text = draft.toppings;
    _priceController.text = draft.price % 1 == 0
        ? draft.price.toStringAsFixed(0)
        : draft.price.toString();
    _stockController.text = draft.stock.toString();
    _preparationTimeController.text = draft.preparationTimeMinutes.toString();
    if (draft.weightAmount != null && draft.weightAmount!.isNotEmpty) {
      _weightController.text = draft.weightAmount!;
    }
    if (draft.weightUnit == 'g' || draft.weightUnit == 'kg') {
      _weightUnit = draft.weightUnit!;
    }
    if (draft.parcelLengthCm != null) {
      _parcelLengthController.text = draft.parcelLengthCm!.toString();
    }
    if (draft.parcelWidthCm != null) {
      _parcelWidthController.text = draft.parcelWidthCm!.toString();
    }
    if (draft.parcelHeightCm != null) {
      _parcelHeightController.text = draft.parcelHeightCm!.toString();
    }
    _selectedProductCategory = draft.productCategory;
    _isFreshProduct = draft.isFreshProduct;
    _isProcessed = draft.isProcessed;
    _pharmacyIsTaxable = draft.pharmacyIsTaxable;
    final unit = draft.unit?.trim();
    if (unit != null && unit.isNotEmpty) {
      if (_units.contains(unit)) {
        _selectedUnit = unit;
      } else {
        _selectedUnit = 'อื่นๆ';
        _otherUnitController.text = unit;
      }
    }
    _existingImageUrls
      ..clear()
      ..addAll(draft.imageUrls);
    _ai.applyStoredReview(draft.aiSourceData);
    final colors = draft.aiSourceData['colors'];
    if (colors is List) {
      _colorsController.text = colors.map((e) => e.toString()).join(', ');
    }
    final sizes = draft.aiSourceData['sizes'];
    if (sizes is List) {
      _sizesController.text = sizes.map((e) => e.toString()).join(', ');
    }
    if (draft.aiSourceData['canShipNationwide'] is bool) {
      _manualCanShipNationwide = draft.aiSourceData['canShipNationwide'] as bool;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _toppingsController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _preparationTimeController.dispose();
    _weightController.dispose();
    _parcelLengthController.dispose();
    _parcelWidthController.dispose();
    _parcelHeightController.dispose();
    _otherUnitController.dispose();
    _colorsController.dispose();
    _sizesController.dispose();
    _priceFocusNode.dispose();
    _toppingsFocusNode.dispose();
    super.dispose();
  }

  bool get _isPharmacyCategory =>
      _selectedProductCategory == 'ร้านขายยาและเวชภัณฑ์';

  String get _computedTaxStatus {
    if (_isPharmacyCategory) {
      return _pharmacyIsTaxable ? 'taxable' : 'exempt';
    }
    return (_isFreshProduct && !_isProcessed) ? 'exempt' : 'taxable';
  }

  String get _taxStatusLabel => _computedTaxStatus == 'exempt'
      ? 'สินค้านี้ยกเว้นภาษี'
      : 'สินค้านี้เสียภาษี';

  Color get _taxStatusColor => _computedTaxStatus == 'exempt'
      ? const Color(0xFF2E7D32)
      : const Color(0xFFC62828);

  String get _taxReason {
    final aiReason = _ai.taxAnalysisReason?.trim();
    if (aiReason != null && aiReason.isNotEmpty) {
      return aiReason;
    }
    if (_isPharmacyCategory) {
      return _pharmacyIsTaxable
          ? 'ร้านค้าระบุว่ายาหรือเวชภัณฑ์รายการนี้อยู่ในกลุ่มที่เสียภาษี'
          : 'ร้านค้าระบุว่ายาหรือเวชภัณฑ์รายการนี้อยู่ในกลุ่มที่ยกเว้นภาษี';
    }
    if (_isFreshProduct && !_isProcessed) {
      return 'ของสดที่ยังไม่ผ่านการแปรรูป';
    }
    if (_isFreshProduct && _isProcessed) {
      return 'ของสดที่ผ่านการแปรรูปแล้ว';
    }
    return 'สินค้าไม่ได้เข้ากลุ่มของสดไม่แปรรูป';
  }

  bool get _resolvedCanShipNationwide =>
      _ai.canShipNationwide ?? _manualCanShipNationwide;

  String get _resolvedNationwideShippingReason {
    final aiReason = _ai.nationwideShippingReason?.trim();
    if (_ai.canShipNationwide != null &&
        aiReason != null &&
        aiReason.isNotEmpty) {
      return aiReason;
    }
    return _resolvedCanShipNationwide
        ? 'สินค้านี้เหมาะกับการส่งทั่วประเทศ'
        : 'สินค้านี้ไม่เหมาะกับการส่งทั่วประเทศ';
  }

  double? get _netPriceAfterGp {
    final raw = _priceController.text.trim().replaceAll(',', '');
    final price = double.tryParse(raw);
    if (price == null) {
      return null;
    }
    return price * (1 - _gpRate);
  }

  Future<void> _loadMediaSettings() async {
    try {
      final settings =
          await AdminRepository.fetchShopMediaSettings(widget.uploadContext.ownerUid);
      if (!mounted) {
        return;
      }
      setState(() {
        _maxImageCount = settings.maxImageCount.clamp(1, 30);
        _canUploadVideo = settings.canUploadVideo;
        _loadingSettings = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingSettings = false);
      }
    }
  }

  Future<void> _pickImages({required ImageSource source}) async {
    if (_totalImageCount >= _maxImageCount) {
      _showSnack('อัปโหลดได้สูงสุด $_maxImageCount รูป');
      return;
    }

    final remaining = _maxImageCount - _totalImageCount;
    final List<XFile> picked;
    if (source == ImageSource.camera || remaining == 1) {
      final single = await _picker.pickImage(
        source: source,
        imageQuality: 78,
      );
      picked = single == null ? <XFile>[] : <XFile>[single];
    } else {
      picked = await _picker.pickMultiImage(
        imageQuality: 78,
        limit: remaining,
      );
    }

    if (picked.isEmpty || !mounted) {
      return;
    }

    final wasEmpty = _totalImageCount == 0;
    setState(() {
      _imageFiles.addAll(picked.take(remaining));
    });

    if (wasEmpty) {
      unawaited(_analyzeProductWithAi(automatic: true));
    }
  }

  void _removeImage(int index) {
    setState(() => _imageFiles.removeAt(index));
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  Future<void> _analyzeProductWithAi({bool automatic = false}) async {
    final canReanalyzeInEdit =
        _isEditingPendingReview && !_aiReanalyzedInEdit && _imageFiles.isNotEmpty;
    if (_ai.hasUsedProductAnalysis && !canReanalyzeInEdit) {
      if (!automatic) {
        _showSnack(_isEditingPendingReview
            ? 'ใช้ AI วิเคราะห์แล้ว — เพิ่มรูปใหม่แล้วกดวิเคราะห์ใหม่ได้ 1 ครั้ง'
            : 'สินค้านี้ใช้ AI วิเคราะห์ไปแล้ว ใช้ได้ 1 ครั้งต่อสินค้า');
      }
      return;
    }

    if (!automatic && _nameController.text.trim().isEmpty) {
      _showSnack('กรุณากรอกชื่อสินค้าก่อนให้ AI วิเคราะห์');
      return;
    }

    if (_imageFiles.isEmpty) {
      _showSnack('กรุณาเพิ่มรูปสินค้าก่อนให้ AI วิเคราะห์');
      return;
    }

    setState(() {
      _ai.isAnalyzing = true;
      _ai.queueStatusText = 'กำลังส่งคำขอ AI...';
    });

    try {
      final file = _imageFiles.first;
      final bytes = await File(file.path).readAsBytes();
      final result = await AdminProductAiService.analyzeProduct(
        imageBytes: bytes,
        mimeType: AdminProductAiService.mimeTypeFromPath(file.path),
        productName: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        category: (_selectedProductCategory ?? '').trim(),
        price: _priceController.text.trim(),
        unit: _resolvedUnit,
        weight: _weightController.text.trim(),
        weightUnit: _weightUnit,
        onQueueStatus: (text) {
          if (!mounted) {
            return;
          }
          setState(() => _ai.queueStatusText = text);
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _applyAiAnalysis(result);
        _ai.hasUsedProductAnalysis = true;
        _ai.isAnalyzing = false;
        _ai.queueStatusText = null;
        if (_isEditingPendingReview && canReanalyzeInEdit) {
          _aiReanalyzedInEdit = true;
        }
      });

      if (!automatic) {
        _showSnack('AI วิเคราะห์สินค้าเรียบร้อยแล้ว');
      }
    } on FirebaseFunctionsException catch (error) {
      if (mounted) {
        setState(() {
          _ai.isAnalyzing = false;
          _ai.queueStatusText = null;
        });
      }
      _showSnack(
        automatic
            ? 'AI วิเคราะห์อัตโนมัติไม่สำเร็จ — กดปุ่ม "วิเคราะห์สินค้า" เพื่อลองอีกครั้ง'
            : AdminProductAiService.functionErrorMessage(error),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _ai.isAnalyzing = false;
          _ai.queueStatusText = null;
        });
      }
      _showSnack(
        automatic
            ? 'AI วิเคราะห์อัตโนมัติไม่สำเร็จ — กดปุ่ม "วิเคราะห์สินค้า" เพื่อลองอีกครั้ง'
            : 'AI วิเคราะห์สินค้าไม่สำเร็จ: $error',
      );
    }
  }

  void _applyAiAnalysis(AdminAiProductAnalysisResult result) {
    final productName = result.productName?.trim();
    final description = result.description?.trim();
    final category = result.productCategory?.trim();
    final taxStatus = result.taxStatus?.trim().toLowerCase();

    if (productName != null &&
        productName.isNotEmpty &&
        _nameController.text.trim().isEmpty) {
      _nameController.text = productName;
    }

    if (description != null && description.isNotEmpty) {
      _descriptionController.text = description;
      _ai.hasUsedDescription = true;
    }

    if (category != null &&
        category.isNotEmpty &&
        _productCategories.contains(category)) {
      _selectedProductCategory = category;
    } else if ((_selectedProductCategory ?? '').isEmpty) {
      _selectedProductCategory =
          taxStatus == 'exempt' ? 'ของสด' : 'สินค้าทั่วไป';
    }

    if (_isPharmacyCategory) {
      _isFreshProduct = false;
      _isProcessed = false;
      if (taxStatus == 'taxable' || taxStatus == 'exempt') {
        _pharmacyIsTaxable = taxStatus == 'taxable';
      }
    } else if (result.isFreshProduct != null || result.isProcessed != null) {
      _isFreshProduct = result.isFreshProduct ?? _isFreshProduct;
      _isProcessed = result.isProcessed ?? _isProcessed;
    } else if (taxStatus == 'exempt') {
      _isFreshProduct = true;
      _isProcessed = false;
    } else if (taxStatus == 'taxable') {
      _isFreshProduct = false;
      _isProcessed = true;
    }

    _applyParcelField(_parcelLengthController, result.parcelLengthCm);
    _applyParcelField(_parcelWidthController, result.parcelWidthCm);
    _applyParcelField(_parcelHeightController, result.parcelHeightCm);

    final saleUnit = result.saleUnit?.trim();
    if (saleUnit != null &&
        saleUnit.isNotEmpty &&
        _selectedUnit == 'ชิ้น' &&
        _otherUnitController.text.trim().isEmpty) {
      if (_units.contains(saleUnit)) {
        _selectedUnit = saleUnit;
      } else {
        _selectedUnit = 'อื่นๆ';
        _otherUnitController.text = saleUnit;
      }
    }

    _ai.applyAnalysis(result);
  }

  void _applyParcelField(TextEditingController controller, double? value) {
    if (value == null || controller.text.trim().isNotEmpty) {
      return;
    }
    final rounded = (value * 10).round() / 10;
    controller.text = rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(1);
  }

  Future<void> _generateAiDescription() async {
    if (_ai.hasUsedDescription) {
      _showSnack('สินค้านี้ใช้ AI เขียนคำอธิบายไปแล้ว ใช้ได้ 1 ครั้งต่อสินค้า');
      return;
    }

    final productName = _nameController.text.trim();
    if (productName.isEmpty) {
      _showSnack('กรุณากรอกชื่อสินค้าก่อนให้ AI ช่วยเขียนคำอธิบาย');
      return;
    }

    setState(() {
      _ai.isGeneratingDescription = true;
      _ai.hasUsedDescription = true;
      _ai.queueStatusText = 'กำลังส่งคำขอ AI...';
    });

    try {
      final text = await AdminProductAiService.generateDescription(
        productName: productName,
        category: (_selectedProductCategory ?? '').trim(),
        price: _priceController.text.trim(),
        unit: _resolvedUnit,
        stock: _stockController.text.trim(),
        onQueueStatus: (text) {
          if (!mounted) {
            return;
          }
          setState(() => _ai.queueStatusText = text);
        },
      );
      if (!mounted) {
        return;
      }
      _descriptionController.text = text;
      _showSnack('เติมคำอธิบายสินค้าจาก AI แล้ว');
    } on FirebaseFunctionsException catch (error) {
      setState(() => _ai.hasUsedDescription = false);
      _showSnack(AdminProductAiService.functionErrorMessage(error));
    } catch (error) {
      setState(() => _ai.hasUsedDescription = false);
      _showSnack('เรียก AI ไม่สำเร็จ: $error');
    } finally {
      if (mounted) {
        setState(() {
          _ai.isGeneratingDescription = false;
          _ai.queueStatusText = null;
        });
      }
    }
  }

  String get _resolvedUnit =>
      _selectedUnit == 'อื่นๆ'
          ? _otherUnitController.text.trim()
          : (_selectedUnit ?? '');

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnack('กรุณากรอกชื่อสินค้า');
      return;
    }

    if (_weightController.text.trim().isEmpty) {
      _showSnack('กรุณากรอกน้ำหนักสินค้า');
      return;
    }

    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      _showSnack('กรุณากรอกราคาที่ถูกต้อง');
      return;
    }

    if ((_selectedProductCategory ?? '').trim().isEmpty) {
      _showSnack('กรุณาเลือกประเภทสินค้า');
      return;
    }

    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    if (stock < 0) {
      _showSnack('สต็อกต้องไม่ติดลบ');
      return;
    }

    final preparationMinutes =
        int.tryParse(_preparationTimeController.text.trim());
    if (preparationMinutes == null ||
        preparationMinutes <= 0 ||
        preparationMinutes > 240) {
      _showSnack('กรุณากรอกเวลาเตรียมสินค้า 1-240 นาที');
      return;
    }

    if (_totalImageCount == 0) {
      _showSnack('กรุณาเลือกรูปสินค้าอย่างน้อย 1 รูป');
      return;
    }

    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      _showSnack('กรุณาเข้าสู่ระบบก่อนบันทึก');
      return;
    }

    if (_ai.requiresAdminReviewCheck()) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('AI แจ้งเตือน'),
          content: Text(
            _ai.isLegalInThailand == false
                ? 'AI ประเมินว่าสินค้านี้อาจผิดกฎหมาย — ต้องการบันทึกต่อหรือไม่?'
                : 'AI ประเมินความมั่นใจต่ำกว่า 80% — ต้องการบันทึกต่อหรือไม่?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('บันทึกต่อ'),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
    }

    setState(() => _saving = true);
    try {
      if (_imageFiles.isNotEmpty) {
        setState(() => _uploadStatusText = 'กำลังอัปโหลดรูป...');
      }
      final uploadedUrls = _imageFiles.isEmpty
          ? <String>[]
          : await AdminRepository.uploadProductImages(
              ownerUid: widget.uploadContext.ownerUid,
              localPaths:
                  _imageFiles.map((file) => file.path).toList(growable: false),
            );
      final imageUrls = <String>[
        ..._existingImageUrls,
        ...uploadedUrls,
      ];
      if (imageUrls.isEmpty) {
        throw Exception('อัปโหลดรูปไม่สำเร็จ');
      }

      final weightAmount = double.tryParse(_weightController.text.trim()) ?? 0;
      final parcelWeightGrams = _weightUnit == 'kg'
          ? (weightAmount * 1000).round()
          : weightAmount.round();
      final weightValue = '${_weightController.text.trim()} $_weightUnit';
      final parcelLength = double.tryParse(_parcelLengthController.text.trim());
      final parcelWidth = double.tryParse(_parcelWidthController.text.trim());
      final parcelHeight = double.tryParse(_parcelHeightController.text.trim());
      final toppings = _toppingsController.text.trim();
      final colors = _colorsController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
      final sizes = _sizesController.text
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);

      final specificationsPayload = <String, dynamic>{
        'description': _descriptionController.text.trim(),
        if (toppings.isNotEmpty) 'toppings': toppings,
        if (colors.isNotEmpty) 'colors': colors,
        if (sizes.isNotEmpty) 'sizes': sizes,
        'productCategory': _selectedProductCategory,
        'isFreshProduct': _isFreshProduct,
        'isProcessed': _isProcessed,
        'taxStatus': _computedTaxStatus,
        'taxStatusLabel': _taxStatusLabel,
        'taxReason': _taxReason,
        'aiIsLegalInThailand': _ai.isLegalInThailand,
        if ((_ai.legalAnalysisReason ?? '').trim().isNotEmpty)
          'aiLegalAnalysisReason': _ai.legalAnalysisReason!.trim(),
        if ((_ai.productType ?? '').trim().isNotEmpty)
          'aiProductType': _ai.productType!.trim(),
        'preparationTimeMinutes': preparationMinutes,
        'preparingDuration': preparationMinutes * 60 * 1000,
        'canShipNationwide': _resolvedCanShipNationwide,
        'nationwideShippingReason': _resolvedNationwideShippingReason,
        'unit': _resolvedUnit,
        'weight': weightValue,
        if (parcelWeightGrams > 0) 'parcelWeightGrams': parcelWeightGrams,
        if (parcelLength != null) 'parcelLengthCm': parcelLength,
        if (parcelWidth != null) 'parcelWidthCm': parcelWidth,
        if (parcelHeight != null) 'parcelHeightCm': parcelHeight,
      };

      final details = AdminProductCreateInput(
        thumbnailUrls: imageUrls,
        preparationTimeMinutes: preparationMinutes,
        productCategory: _selectedProductCategory,
        isFreshProduct: _isFreshProduct,
        isProcessed: _isProcessed,
        taxStatus: _computedTaxStatus,
        taxStatusLabel: _taxStatusLabel,
        taxReason: _taxReason,
        unit: _resolvedUnit,
        weight: weightValue,
        parcelWeightGrams: parcelWeightGrams,
        parcelLengthCm: parcelLength,
        parcelWidthCm: parcelWidth,
        parcelHeightCm: parcelHeight,
        canShipNationwide: _resolvedCanShipNationwide,
        nationwideShippingReason: _resolvedNationwideShippingReason,
        toppings: toppings.isEmpty ? null : toppings,
        colors: colors.isEmpty ? null : colors,
        sizes: sizes.isEmpty ? null : sizes,
        aiDescriptionRequested: _ai.hasUsedDescription,
        aiProductAnalysisRequested: _ai.hasUsedProductAnalysis,
        aiIsLegalInThailand: _ai.isLegalInThailand,
        aiLegalAnalysisReason: _ai.legalAnalysisReason,
        aiProductType: _ai.productType,
        taxAiReason: _ai.taxAnalysisReason,
        aiConfidenceFields: _ai.confidenceFields(),
        specificationsPayload: specificationsPayload,
      );

      if (_isEditingPendingReview) {
        await AdminRepository.updatePendingProductReview(
          reviewId: widget.editReviewId!,
          adminUid: adminUid,
          name: name,
          description: _descriptionController.text.trim(),
          price: price,
          stock: stock,
          imageUrls: imageUrls,
          details: details,
        );
      } else {
        final needsReview = _ai.requiresAdminReviewCheck();
        await AdminRepository.adminCreateProduct(
          shop: widget.uploadContext.toShopRecord(),
          name: name,
          description: _descriptionController.text.trim(),
          price: price,
          stock: stock,
          imageUrls: imageUrls,
          adminUid: adminUid,
          details: details,
        );

        if (!mounted) {
          return;
        }
        final snackMessage = needsReview
            ? (_ai.isLegalInThailand == false
                ? 'AI ประเมินว่าสินค้านี้อาจผิดกฎหมาย — ส่งเข้าคิวตรวจสอบแล้ว'
                : 'AI ประเมินความมั่นใจต่ำ — ส่งเข้าคิวตรวจสอบแล้ว')
            : 'เพิ่ม "$name" ให้ร้าน ${widget.uploadContext.shopName} แล้ว';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snackMessage)),
        );
        Navigator.pop(context, true);
        return;
      }

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกการแก้ไข "$name" แล้ว — ยังอยู่ในคิวรอตรวจสอบ')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _showSnack('บันทึกไม่สำเร็จ: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadStatusText = null;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _formTitle =>
      _isEditingPendingReview ? 'แก้ไขสินค้า' : 'เพิ่มสินค้าใหม่';

  String get _saveButtonLabel =>
      _isEditingPendingReview ? 'บันทึกการแก้ไข' : 'บันทึกสินค้า';

  @override
  Widget build(BuildContext context) => buildMerchantProductForm(context);
}
