import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_image_widgets.dart';
import 'admin_repository.dart';
import 'data/catalog_taxonomy.dart';

class AdminCatalogReviewScreen extends StatefulWidget {
  const AdminCatalogReviewScreen({super.key});

  @override
  State<AdminCatalogReviewScreen> createState() => _AdminCatalogReviewScreenState();
}

class _AdminCatalogReviewScreenState extends State<AdminCatalogReviewScreen> {
  final _searchController = TextEditingController();
  var _showAllActive = false;
  final Set<String> _processingIds = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCatalogEditor(AdminCatalogProductRecord product) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }

    final submission = await showModalBottomSheet<_CatalogEditorSubmission>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => _CatalogEditorSheet(product: product),
    );

    if (submission == null || !mounted) {
      return;
    }

    setState(() => _processingIds.add(product.id));
    try {
      await AdminRepository.approveProductCatalog(
        productId: product.id,
        catalogType: submission.catalogType,
        catalogHeading: submission.catalogHeading,
        adminUid: adminUid,
        serviceType: product.serviceType,
        customHeading: submission.customHeading,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกหมวด "${product.name}" แล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds.remove(product.id));
      }
    }
  }

  List<AdminCatalogProductRecord> _filterProducts(
    List<AdminCatalogProductRecord> products,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return products;
    }
    return products
        .where((product) {
          final haystack = [
            product.name,
            product.shopName,
            product.catalogType,
            product.catalogHeading,
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('จัดการหมวดสินค้า'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'ค้นหาชื่อสินค้า / ร้าน / หมวด',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: <Widget>[
                FilterChip(
                  label: const Text('รอตรวจหมวด'),
                  selected: !_showAllActive,
                  onSelected: (_) => setState(() => _showAllActive = false),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('สินค้าทั้งหมด'),
                  selected: _showAllActive,
                  onSelected: (_) => setState(() => _showAllActive = true),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<AdminCatalogProductRecord>>(
              stream: _showAllActive
                  ? AdminRepository.streamActiveProductsForCatalogFix()
                  : AdminRepository.streamPendingCatalogReviews(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final products = _filterProducts(snapshot.data ?? const <AdminCatalogProductRecord>[]);
                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      _showAllActive
                          ? 'ไม่พบสินค้าที่ค้นหา'
                          : 'ไม่มีสินค้ารอตรวจหมวด',
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _CatalogProductTile(
                      product: product,
                      processing: _processingIds.contains(product.id),
                      onTap: () => _openCatalogEditor(product),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogProductTile extends StatelessWidget {
  const _CatalogProductTile({
    required this.product,
    required this.processing,
    required this.onTap,
  });

  final AdminCatalogProductRecord product;
  final bool processing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: processing ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              if (product.imageUrls.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AdminSafeNetworkImage(
                    url: product.imageUrls.first,
                    width: 64,
                    height: 64,
                  ),
                ),
              if (product.imageUrls.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (product.shopName?.trim().isNotEmpty == true)
                      Text(
                        product.shopName!,
                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'ปัจจุบัน: ${product.catalogType ?? '-'} / ${product.catalogHeading ?? '-'}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    if (product.isPendingCatalogReview)
                      Text(
                        product.catalogReviewSummary,
                        style: const TextStyle(color: Color(0xFFB45309), fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (processing)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.edit_outlined, color: Color(0xFFE65100)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogEditorSubmission {
  const _CatalogEditorSubmission({
    required this.catalogType,
    required this.catalogHeading,
    this.customHeading,
  });

  final String catalogType;
  final String catalogHeading;
  final String? customHeading;
}

class _CatalogEditorSheet extends StatefulWidget {
  const _CatalogEditorSheet({required this.product});

  final AdminCatalogProductRecord product;

  @override
  State<_CatalogEditorSheet> createState() => _CatalogEditorSheetState();
}

class _CatalogEditorSheetState extends State<_CatalogEditorSheet> {
  late String? _selectedType;
  late String? _selectedHeading;
  late final TextEditingController _customHeadingController;
  var _useCustomHeading = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.product.catalogType;
    _selectedHeading = widget.product.catalogHeading;
    _customHeadingController = TextEditingController(text: widget.product.catalogHeading ?? '');
  }

  @override
  void dispose() {
    _customHeadingController.dispose();
    super.dispose();
  }

  List<CatalogTaxonomyEntry> get _typeOptions =>
      CatalogTaxonomy.typesForServiceType(widget.product.serviceType);

  List<String> get _headingOptions {
    final type = _selectedType?.trim();
    if (type == null || type.isEmpty) {
      return const <String>[];
    }
    return CatalogTaxonomy.headingsFor(widget.product.serviceType, type);
  }

  void _save() {
    final type = _selectedType?.trim();
    if (type == null || type.isEmpty) {
      return;
    }
    final heading = _useCustomHeading
        ? _customHeadingController.text.trim()
        : (_selectedHeading?.trim() ?? '');
    if (heading.isEmpty) {
      return;
    }
    Navigator.of(context).pop(
      _CatalogEditorSubmission(
        catalogType: type,
        catalogHeading: heading,
        customHeading: _useCustomHeading ? heading : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            widget.product.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(widget.product.catalogReviewSummary),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _typeOptions.any((entry) => entry.label == _selectedType)
                ? _selectedType
                : null,
            decoration: const InputDecoration(
              labelText: 'หมวดใหญ่ (catalogType)',
              border: OutlineInputBorder(),
            ),
            items: _typeOptions
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.label,
                    child: Text(entry.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              setState(() {
                _selectedType = value;
                _selectedHeading = CatalogTaxonomy.headingsFor(
                  widget.product.serviceType,
                  value ?? '',
                ).firstOrNull;
              });
            },
          ),
          const SizedBox(height: 12),
          if (!_useCustomHeading)
            DropdownButtonFormField<String>(
              value: _headingOptions.contains(_selectedHeading) ? _selectedHeading : null,
              decoration: const InputDecoration(
                labelText: 'หัวข้อย่อย (catalogHeading)',
                border: OutlineInputBorder(),
              ),
              items: _headingOptions
                  .map(
                    (heading) => DropdownMenuItem<String>(
                      value: heading,
                      child: Text(heading),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) => setState(() => _selectedHeading = value),
            )
          else
            TextField(
              controller: _customHeadingController,
              decoration: const InputDecoration(
                labelText: 'หัวข้อใหม่',
                border: OutlineInputBorder(),
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('เพิ่มหัวข้อใหม่'),
            value: _useCustomHeading,
            onChanged: (value) => setState(() => _useCustomHeading = value),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('บันทึกและอนุมัติหมวด'),
          ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
