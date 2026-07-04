part of 'admin_add_product_screen.dart';

extension _AdminMerchantProductFormUi on _AdminAddProductScreenState {
  Widget buildMerchantProductForm(BuildContext context) {
    if (_loadingSettings || _loadingReview) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_formTitle),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 1,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final shopName = widget.uploadContext.shopName;

    return Scaffold(
      appBar: AppBar(
        title: Text(_formTitle),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildAdminContextBanner(shopName),
            const SizedBox(height: 16),
            const Text(
              'รูปภาพและวิดีโอ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildMediaSection(),
            if (_uploadStatusText != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_uploadStatusText!),
              ),
            const SizedBox(height: 32),
            const Text(
              'รายละเอียดสินค้า',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _buildTextField(
                    label: 'ชื่อสินค้า',
                    controller: _nameController,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildWeightField()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _buildGuidedFieldOverlay(
                        showGuidance: _showPriceGuidance,
                        guidanceMessage:
                            'ระบบจะหักค่า GP 18% จากราคาที่ระบุ แนะนำให้บวกราคาเพิ่มจากราคาขายหน้าร้านปกติ ตามราคาที่เหมาะสม',
                        footer: Text(
                          _netPriceAfterGp == null
                              ? 'ราคาที่จะได้รับ: ระบุราคาก่อน'
                              : 'ราคาที่จะได้รับ: ${_formatPriceDisplay(_netPriceAfterGp!)} บาท',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentDark,
                          ),
                        ),
                        field: _buildTextField(
                          label: 'ราคา',
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          focusNode: _priceFocusNode,
                          onTap: () {
                            setState(() {
                              _showPreparationTimeGuidance = false;
                              _priceGuidanceDismissedWhileFocused = false;
                              _showPriceGuidance = true;
                            });
                          },
                          onChanged: (_) {
                            if (_showPriceGuidance && mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGuidedFieldOverlay(
                        showGuidance: _showPreparationTimeGuidance,
                        guidanceMessage:
                            'เวลาที่ระบุจะแสดงต่อลูกค้า และมีผลต่อการสั่งสินค้า รวมถึงค่าปรับหากเตรียมออเดอร์ช้าเกินเวลาที่ตั้งไว้ โดยคิดช้านาทีละ 1 บาทและหักจากยอดเครดิต กรุณาระบุเวลาเตรียมที่เหมาะสม',
                        field: _buildTextField(
                          label: 'เวลาเตรียมสินค้า/ออเดอร์ (นาที)',
                          controller: _preparationTimeController,
                          keyboardType: TextInputType.number,
                          hint: 'เช่น 10',
                          onTap: () => setState(() {
                            _showPriceGuidance = false;
                            _priceGuidanceDismissedWhileFocused = false;
                            _showPreparationTimeGuidance = true;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'สต็อกทั้งหมด',
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProductAnalysisSection(),
            const SizedBox(height: 24),
            _buildNationwideShippingSection(),
            if (_resolvedCanShipNationwide) ...<Widget>[
              const SizedBox(height: 12),
              _buildParcelDimensionFields(),
            ],
            const SizedBox(height: 24),
            _buildTaxSection(),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) => _buildSpecificationSheet(),
                );
              },
              icon: const Icon(Icons.tune),
              label: const Text(
                'ข้อมูลจำเพาะสินค้า (ท็อปปิ้ง, สี, ขนาด, หน่วย)',
                style: TextStyle(fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: AppColors.accent, width: 1.5),
                foregroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: (_saving || _ai.isGeneratingDescription) ? null : _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _saveButtonLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminContextBanner(String shopName) {
    if (_isEditingPendingReview) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Text(
          'แก้ไขสินค้ารอตรวจสอบ — ร้าน: $shopName\n'
          'AI ประเมินความมั่นใจต่ำกว่า 80% · หลังบันทึกยังอยู่ในคิวรอตรวจสอบ',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFFE65100),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        'อัปโหลดให้ร้าน: $shopName',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFFE65100),
        ),
      ),
    );
  }

  Widget _buildDismissibleGuidance({
    required String message,
    Widget? footer,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            message,
            softWrap: true,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF7C2D12),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (footer != null) ...<Widget>[
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: footer),
          ],
        ],
      ),
    );
  }

  Widget _buildGuidedFieldOverlay({
    required Widget field,
    required bool showGuidance,
    required String guidanceMessage,
    Widget? footer,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        field,
        if (showGuidance)
          Positioned(
            left: 2,
            right: 2,
            bottom: 58,
            child: _buildDismissibleGuidance(
              message: guidanceMessage,
              footer: footer,
            ),
          ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    TextEditingController? controller,
    FocusNode? focusNode,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onTap: () {
            _hideFieldGuidance();
            onTap?.call();
          },
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: const BorderSide(
                color: AppColors.accentDark,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'น้ำหนัก',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.grey.shade400),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'ใส่น้ำหนัก',
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: Colors.grey.shade300),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _weightUnit,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.black54,
                  ),
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() => _weightUnit = value);
                        },
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(value: 'g', child: Text('g')),
                    DropdownMenuItem<String>(value: 'kg', child: Text('kg')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMediaSection() {
    final bool hasImages = _currentImageCount > 0;
    final bool showVideoControls = _canAddVideo;

    final Widget imageContent = hasImages
        ? _buildImagePreviewContent()
        : _buildPlaceholderSquare(
            icon: Icons.photo_library_outlined,
            label: 'ยังไม่มีรูปภาพ',
          );

    final Widget videoContent = _buildPlaceholderSquare(
      icon: Icons.videocam_outlined,
      label: 'ยังไม่มีวิดีโอ',
    );

    final bool showCombinedRow = !hasImages && showVideoControls;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              ElevatedButton.icon(
                onPressed: _isResolvingServiceType || !_canPickMoreImages
                    ? null
                    : _captureImage,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('ถ่ายรูป'),
              ),
              ElevatedButton.icon(
                onPressed: _isResolvingServiceType || !_canPickMoreImages
                    ? null
                    : _pickImagesFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text('เลือกรูป ($_currentImageCount/$_maxImageCount)'),
              ),
              if (_canAddVideo)
                ElevatedButton.icon(
                  onPressed: _pickVideoPlaceholder,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('เพิ่มวิดีโอ'),
                ),
            ],
          ),
          if (_mediaLimitHintText() != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _mediaLimitHintText()!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 16),
          if (showCombinedRow)
            Row(
              children: <Widget>[
                Expanded(child: imageContent),
                const SizedBox(width: 12),
                Expanded(child: videoContent),
              ],
            )
          else ...<Widget>[
            if (hasImages)
              imageContent
            else
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 120, child: imageContent),
              ),
            if (showVideoControls) ...<Widget>[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 120, child: videoContent),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreviewContent() {
    final List<Widget> tiles = <Widget>[];

    for (int i = 0; i < _existingImageUrls.length; i++) {
      tiles.add(
        _buildImageTile(
          image: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AdminSafeNetworkImage(
              url: _existingImageUrls[i],
              width: 110,
              height: 110,
            ),
          ),
          onRemove: () => _removeExistingImage(i),
        ),
      );
    }

    for (int i = 0; i < _imageFiles.length; i++) {
      final file = _imageFiles[i];
      tiles.add(
        _buildImageTile(
          image: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(file.path),
              width: 110,
              height: 110,
              fit: BoxFit.cover,
            ),
          ),
          onRemove: () => _removeImage(i),
        ),
      );
    }

    return Wrap(spacing: 12, runSpacing: 12, children: tiles);
  }

  Widget _buildPlaceholderSquare({
    required IconData icon,
    required String label,
  }) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(icon, color: Colors.grey[500], size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageTile({
    required Widget image,
    required VoidCallback onRemove,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        SizedBox(width: 110, height: 110, child: image),
        Positioned(
          top: -8,
          right: -8,
          child: InkWell(
            onTap: _saving ? null : onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductAnalysisSection() {
    final legalKnown = _ai.isLegalInThailand != null;
    final legalColor = _ai.isLegalInThailand == false
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);
    final legalReason = (_ai.legalAnalysisReason ?? '').trim();
    final productType = (_ai.productType ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'วิเคราะห์สินค้า',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _canRunProductAnalysis ? () => _analyzeProductWithAi() : null,
              icon: _ai.isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _ai.isAnalyzing
                    ? 'AI กำลังวิเคราะห์สินค้า...'
                    : (_ai.hasUsedProductAnalysis
                        ? (_isEditingPendingReview && !_aiReanalyzedInEdit
                            ? 'วิเคราะห์ใหม่ (เพิ่มรูปก่อน)'
                            : 'ใช้ AI วิเคราะห์สินค้าแล้ว')
                        : 'วิเคราะห์สินค้า'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
              ),
            ),
          ),
          if (_ai.isAnalyzing && (_ai.queueStatusText ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _ai.queueStatusText!,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
          if (legalKnown || productType.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            if (legalKnown)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: legalColor.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _ai.isLegalInThailand == true
                          ? 'AI ประเมินว่าเป็นสินค้าที่ขายได้ตามกฎหมายไทย'
                          : 'AI ประเมินว่าอาจเป็นสินค้าที่ห้ามหรือจำกัดการขายในไทย',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: legalColor,
                      ),
                    ),
                    if (legalReason.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        legalReason,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (productType.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  'ประเภทสินค้า: $productType',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
            if (_ai.requiresAdminReviewCheck() &&
                _ai.isLegalInThailand != false) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'AI ประเมินความมั่นใจต่ำกว่า 80% — จะส่งให้แอดมินตรวจสอบก่อนขึ้นขาย',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFB45309),
                      ),
                    ),
                    if (_ai.reviewReasonLabels.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        'จุดที่ต้องตรวจ: ${_ai.reviewReasonLabels.join(', ')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildManualNationwideShippingCheckbox() {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('เหมาะกับการส่งทั่วประเทศ'),
      subtitle: const Text('ติ๊กถูกถ้าสินค้านี้แพ็กและจัดส่งไปต่างจังหวัดได้'),
      value: _manualCanShipNationwide,
      onChanged: _saving
          ? null
          : (value) {
              setState(() => _manualCanShipNationwide = value ?? false);
            },
      activeColor: AppColors.accent,
    );
  }

  Widget _buildNationwideShippingSection() {
    if (_ai.canShipNationwide != null) {
      return _buildNationwideShippingSummaryCard();
    }
    return _buildManualNationwideShippingCheckbox();
  }

  Widget _buildNationwideShippingSummaryCard() {
    final canShip = _ai.canShipNationwide == true;
    final color = canShip ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final reason = (_ai.nationwideShippingReason ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            canShip
                ? 'สินค้านี้ส่งได้ทั่วไทย'
                : 'สินค้านี้ไม่เหมาะกับการส่งทั่วไทย',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (reason.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              reason,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParcelDimensionFields() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'ข้อมูลพัสดุสำหรับส่งทั่วประเทศ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'เตรียมไว้สำหรับเชื่อมต่อ ShipPop ภายหลัง ระบุขนาดโดยประมาณของพัสดุหลังแพ็ก',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          if ((_ai.parcelDimensionReason ?? '').isNotEmpty) ...<Widget>[
            Text(
              'AI ประเมิน: ${_ai.parcelDimensionReason!}',
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: <Widget>[
              Expanded(
                child: _buildTextField(
                  label: 'ยาว (ซม.)',
                  controller: _parcelLengthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  label: 'กว้าง (ซม.)',
                  controller: _parcelWidthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  label: 'สูง (ซม.)',
                  controller: _parcelHeightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _taxStatusColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _taxStatusLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _taxStatusColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _taxReason,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'ภาษีสินค้า',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_ai.hasTaxAnalysis) ...<Widget>[
            _buildTaxSummaryCard(),
          ] else ...<Widget>[
            const Text(
              'ประเภทสินค้า',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedProductCategory,
              items: _AdminAddProductScreenState._productCategories
                  .map(
                    (category) => DropdownMenuItem<String>(
                      value: category,
                      child: Text(category),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() {
                        _selectedProductCategory = value;
                        if (_isPharmacyCategory) {
                          _isFreshProduct = false;
                          _isProcessed = false;
                        }
                      });
                    },
              decoration: InputDecoration(
                hintText: 'เลือกประเภทสินค้า',
                helperText: 'จำเป็นต้องเลือกก่อนบันทึกสินค้า',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.accentDark,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            if (_isPharmacyCategory) ...<Widget>[
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('เสียภาษี'),
                subtitle: const Text(
                  'ปิดสวิตช์หากยาหรือเวชภัณฑ์รายการนี้เป็นสินค้ายกเว้นภาษี',
                ),
                value: _pharmacyIsTaxable,
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _pharmacyIsTaxable = value;
                          _isFreshProduct = false;
                          _isProcessed = false;
                        });
                      },
                activeColor: AppColors.accent,
              ),
            ] else ...<Widget>[
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('เป็นของสด'),
                subtitle: const Text('เช่น ผัก ผลไม้ เนื้อสด อาหารทะเลสด'),
                value: _isFreshProduct,
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _isFreshProduct = value);
                      },
                activeColor: AppColors.accent,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('ผ่านการแปรรูปแล้ว'),
                subtitle: const Text(
                  'เช่น หั่น หมัก ปรุง บรรจุพร้อมขาย หรือแปรรูปจากสภาพสด',
                ),
                value: _isProcessed,
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() => _isProcessed = value);
                      },
                activeColor: AppColors.accent,
              ),
            ],
            const SizedBox(height: 12),
            _buildTaxSummaryCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecificationSheet() {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const Text(
                  'ข้อมูลจำเพาะสินค้า',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'คำอธิบายสินค้า',
              controller: _descriptionController,
              hint: 'อธิบายรายละเอียดสินค้า',
              maxLines: 3,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (_ai.isGeneratingDescription ||
                        _ai.hasUsedDescription ||
                        _saving)
                    ? null
                    : _generateAiDescription,
                icon: _ai.isGeneratingDescription
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _ai.isGeneratingDescription
                      ? 'AI กำลังเขียนคำอธิบาย...'
                      : (_ai.hasUsedDescription
                            ? 'ใช้ AI เขียนคำอธิบายแล้ว'
                            : 'ให้ AI ช่วยเขียนคำอธิบายสินค้า'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(
                    color: AppColors.accent.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            if (_ai.isGeneratingDescription &&
                (_ai.queueStatusText ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                _ai.queueStatusText!,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              label: 'ท็อปปิ้ง',
              controller: _toppingsController,
              focusNode: _toppingsFocusNode,
              hint: 'เช่น (ระดับความเผ็ด) +เผ็ดน้อย+ เผ็ด+ กลาง+เผ็ดมาก',
              onTap: () => setState(() {
                _showPriceGuidance = false;
                _showPreparationTimeGuidance = false;
                _showToppingsGuidance = true;
              }),
            ),
            if (_showToppingsGuidance) ...<Widget>[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'วิธีกรอกท็อปปิ้ง',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '1. ถ้าใส่วงเล็บ () จะใช้เป็นหัวข้อ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7C2D12)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '2. ถ้าใส่เครื่องหมาย + นำหน้า และลงท้ายด้วย + จะใช้เป็นตัวเลือก',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7C2D12)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '3. ตัวอย่าง: (ระดับความเผ็ด) +เผ็ดน้อย+ เผ็ด+ กลาง+เผ็ดมาก',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7C2D12)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              label: 'สี (คั่นด้วยจุลภาค)',
              controller: _colorsController,
              hint: 'เช่น แดง, ขาว, ดำ',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'ขนาด (คั่นด้วยจุลภาค)',
              controller: _sizesController,
              hint: 'เช่น S, M, L, XL',
            ),
            const SizedBox(height: 16),
            const Text(
              'หน่วย',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedUnit,
              items: _AdminAddProductScreenState._units
                  .map(
                    (unit) => DropdownMenuItem<String>(
                      value: unit,
                      child: Text(unit),
                    ),
                  )
                  .toList(growable: false),
              onChanged: _saving
                  ? null
                  : (value) {
                      setState(() => _selectedUnit = value);
                    },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: const BorderSide(
                    color: AppColors.accentDark,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
            ),
            if (_selectedUnit == 'อื่นๆ') ...<Widget>[
              const SizedBox(height: 16),
              _buildTextField(
                label: 'ระบุหน่วย (อื่นๆ)',
                controller: _otherUnitController,
                hint: 'เช่น หลอด, ขวด, ซอง',
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('เสร็จสิ้น'),
            ),
          ],
        ),
      ),
    );
  }
}
