import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_add_product_screen.dart';
import 'admin_image_widgets.dart';
import 'admin_repository.dart';
import 'services/admin_merchant_contract_service.dart';

Future<void> openAdminHelpUploadProduct(
  BuildContext context,
  AdminShopRecord shop,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => AdminAddProductScreen(
        uploadContext: AdminProductUploadContext(
          ownerUid: shop.ownerId,
          shopName: shop.displayName,
          serviceType: shop.serviceType,
        ),
      ),
    ),
  );
}

Future<bool?> openAdminEditPendingReview(
  BuildContext context,
  AdminProductRecord product,
) async {
  try {
    final draft =
        await AdminRepository.fetchPendingProductReviewDraft(product.id);
    if (!context.mounted) {
      return null;
    }
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AdminAddProductScreen(
          uploadContext: AdminProductUploadContext(
            ownerUid: draft.ownerUid,
            shopName: draft.shopName,
            serviceType: draft.serviceType,
          ),
          editReviewId: product.id,
        ),
      ),
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปิดแก้ไขไม่สำเร็จ: $error')),
      );
    }
    return null;
  }
}

class ShopManagementScreen extends StatefulWidget {
  const ShopManagementScreen({super.key});

  @override
  State<ShopManagementScreen> createState() => _ShopManagementScreenState();
}

class _ShopManagementScreenState extends State<ShopManagementScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: const Text('จัดการร้านค้า'),
      ),
      body: StreamBuilder<Map<String, AdminShopMediaSettings>>(
        stream: AdminRepository.streamShopMediaSettingsMap(),
        builder: (context, mediaSnapshot) {
          final mediaMap = mediaSnapshot.data ?? const <String, AdminShopMediaSettings>{};

          return StreamBuilder<List<AdminShopRecord>>(
            stream: AdminRepository.streamShops(),
            builder: (context, shopsSnapshot) {
              if (shopsSnapshot.connectionState == ConnectionState.waiting &&
                  !shopsSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (shopsSnapshot.hasError) {
                return Center(child: Text('โหลดข้อมูลไม่สำเร็จ: ${shopsSnapshot.error}'));
              }

              final shops = shopsSnapshot.data ?? <AdminShopRecord>[];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const _IllegalAiProductsPanel(),
                  _ShopAdminToolbar(shops: shops),
                  Expanded(
                    child: shops.isEmpty
                        ? const Center(child: Text('ยังไม่พบข้อมูลร้านค้า'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: shops.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final shop = shops[index];
                              final media = mediaMap[shop.ownerId] ??
                                  AdminShopMediaSettings.fromMap(<String, dynamic>{
                                    'serviceType': shop.serviceType,
                                  });
                              return _ShopCard(
                                shop: shop,
                                mediaSettings: media,
                                displayImageUrl: resolveShopDisplayImageUrl(
                                  registrationImageUrl: shop.imageUrl,
                                  publicShopImageUrl: media.shopImageUrl,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _IllegalAiProductsPanel extends StatefulWidget {
  const _IllegalAiProductsPanel();

  @override
  State<_IllegalAiProductsPanel> createState() => _IllegalAiProductsPanelState();
}

class _IllegalAiProductsPanelState extends State<_IllegalAiProductsPanel> {
  final Set<String> _processingReviewIds = <String>{};

  Future<void> _approve(AdminProductRecord product) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }

    setState(() => _processingReviewIds.add(product.id));
    try {
      await AdminRepository.approveProductReview(
        reviewId: product.id,
        adminUid: adminUid,
      );
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อนุมัติ "${product.name}" — ขึ้นขายแล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อนุมัติไม่สำเร็จ: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingReviewIds.remove(product.id));
      }
    }
  }

  Future<void> _reject(AdminProductRecord product) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }

    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ปฏิเสธ "${product.name}"'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'เหตุผล (ไม่บังคับ)',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ปฏิเสธ')),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      reasonController.dispose();
      return;
    }

    setState(() => _processingReviewIds.add(product.id));
    try {
      await AdminRepository.rejectProductReview(
        reviewId: product.id,
        adminUid: adminUid,
        reason: reasonController.text,
      );
      if (mounted) {
        Navigator.of(context).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธ "${product.name}" แล้ว')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธไม่สำเร็จ: $error')),
        );
      }
    } finally {
      reasonController.dispose();
      if (mounted) {
        setState(() => _processingReviewIds.remove(product.id));
      }
    }
  }

  void _openProductDetail(AdminProductRecord product) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminPendingProductReviewScreen(
          product: product,
          processing: _processingReviewIds.contains(product.id),
          onApprove: () => _approve(product),
          onReject: () => _reject(product),
          onEdit: product.needsLowConfidenceReview
              ? () => _editPendingReview(product)
              : null,
        ),
      ),
    );
  }

  Future<void> _editPendingReview(AdminProductRecord product) async {
    final edited = await openAdminEditPendingReview(context, product);
    if (edited == true && mounted) {
      Navigator.of(context).maybePop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('แก้ไข "${product.name}" แล้ว — ยังอยู่ในคิวรอตรวจสอบ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AdminProductRecord>>(
      stream: AdminRepository.streamPendingAiProductReviews(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'โหลดรายการสินค้ารอตรวจสอบไม่สำเร็จ: ${snapshot.error}',
              style: const TextStyle(color: Color(0xFFB45309)),
            ),
          );
        }

        final products = snapshot.data ?? <AdminProductRecord>[];
        if (products.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.fact_check_outlined, color: Color(0xFFB45309)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'รอแอดมินอนุมัติ — AI ต้องตรวจสอบก่อนขึ้นขาย (${products.length})',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFFB45309),
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final processing = _processingReviewIds.contains(product.id);
                    return Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: processing ? null : () => _openProductDetail(product),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: product.imageUrls.isNotEmpty
                                        ? AdminSafeNetworkImage(
                                            url: product.imageUrls.first,
                                            width: 52,
                                            height: 52,
                                          )
                                        : const SizedBox(
                                            width: 52,
                                            height: 52,
                                            child: Icon(Icons.warning_amber_outlined),
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Text(
                                          product.name,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        Text(
                                          product.shopName ?? product.ownerUid ?? 'ไม่ระบุร้าน',
                                          style: const TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          product.aiReviewSummary,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: product.isAiIllegalInThailand
                                                ? const Color(0xFFB91C1C)
                                                : const Color(0xFFB45309),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: processing ? null : () => _reject(product),
                                      icon: const Icon(Icons.block_outlined, size: 16),
                                      label: const Text('ปฏิเสธ'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: processing ? null : () => _approve(product),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF16A34A),
                                      ),
                                      icon: processing
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.check_circle_outline, size: 16),
                                      label: Text(
                                        processing ? 'กำลังดำเนินการ...' : 'อนุมัติขึ้นขาย',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ShopAdminToolbar extends StatelessWidget {
  const _ShopAdminToolbar({
    required this.shops,
  });

  final List<AdminShopRecord> shops;

  Future<void> _openMediaSettingsPicker(BuildContext context) async {
    if (shops.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<AdminShopRecord>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: shops
                .map(
                  (shop) => ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(shop.displayName),
                    subtitle: Text(shop.serviceType),
                    onTap: () => Navigator.pop(sheetContext, shop),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
    if (selected == null || !context.mounted) {
      return;
    }
    await showShopMediaSettingsDialog(context, shop: selected);
  }

  Future<void> _openShopPickerForProducts(
    BuildContext context, {
    required bool uploadMode,
  }) async {
    if (shops.isEmpty) {
      return;
    }
    final selected = await showModalBottomSheet<AdminShopRecord>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: shops
                .map(
                  (shop) => ListTile(
                    leading: Icon(uploadMode ? Icons.upload_outlined : Icons.inventory_2_outlined),
                    title: Text(shop.displayName),
                    subtitle: Text(uploadMode ? 'ช่วยอัปโหลดสินค้า' : 'ดูสินค้าที่อัปโหลด'),
                    onTap: () => Navigator.pop(sheetContext, shop),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
    if (selected == null || !context.mounted) {
      return;
    }
    if (uploadMode) {
      await openAdminHelpUploadProduct(context, selected);
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ShopUploadedProductsScreen(shop: selected),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFE0B2)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          OutlinedButton.icon(
            onPressed: () => _openShopPickerForProducts(context, uploadMode: true),
            icon: const Icon(Icons.upload_outlined, size: 18),
            label: const Text('ช่วยอัปโหลดสินค้า'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openShopPickerForProducts(context, uploadMode: false),
            icon: const Icon(Icons.inventory_2_outlined, size: 18),
            label: const Text('ดูสินค้าร้าน'),
          ),
          OutlinedButton.icon(
            onPressed: () => _openMediaSettingsPicker(context),
            icon: const Icon(Icons.tune_outlined, size: 18),
            label: const Text('ตั้งค่ารูป/วิดีโอ'),
          ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({
    required this.shop,
    required this.mediaSettings,
    required this.displayImageUrl,
  });

  final AdminShopRecord shop;
  final AdminShopMediaSettings mediaSettings;
  final String? displayImageUrl;

  Future<void> _cancelContract(BuildContext context) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ยกเลิกสัญญา — ${shop.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'หลังยกเลิกสัญญา ร้านค้าจะถอนเครดิตในกระเป๋าเงินได้ '
              '(ตามยอดที่ Cloud Function คำนวณ)',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'เหตุผล (ไม่บังคับ)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ปิด'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB45309)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ยกเลิกสัญญา'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      reasonController.dispose();
      return;
    }

    try {
      await AdminMerchantContractService.instance.cancelMerchantContract(
        merchantUid: shop.ownerId,
        reason: reasonController.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ยกเลิกสัญญา ${shop.displayName} แล้ว — ปลดล็อกถอนเครดิต'),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ยกเลิกสัญญาไม่สำเร็จ: ${AdminMerchantContractService.errorMessage(error)}',
            ),
          ),
        );
      }
    } finally {
      reasonController.dispose();
    }
  }

  Future<void> _approve(BuildContext context) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      return;
    }

    try {
      await AdminRepository.approveShop(shop: shop, adminUid: adminUid);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อนุมัติ ${shop.displayName} แล้ว — แจ้ง van1 + เปิด public_shops')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อนุมัติไม่สำเร็จ: $error')));
      }
    }
  }

  Future<void> _reject(BuildContext context) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('ปฏิเสธ ${shop.displayName}'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'เหตุผล',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ปิด')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('ปฏิเสธ')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      reasonController.dispose();
      return;
    }

    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) {
      reasonController.dispose();
      return;
    }

    try {
      await AdminRepository.rejectShop(
        shop: shop,
        adminUid: adminUid,
        reason: reasonController.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธ ${shop.displayName} และแจ้ง van1 แล้ว')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ปฏิเสธไม่สำเร็จ: $error')));
      }
    } finally {
      reasonController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminMerchantWalletSnapshot?>(
      stream: AdminMerchantContractService.instance.watchMerchantWallet(shop.ownerId),
      builder: (context, walletSnapshot) {
        final wallet = walletSnapshot.data;
        final contractCancelled = wallet?.isContractCancelled ?? false;
        final walletLines = <String>[
          if (wallet != null)
            'เครดิตร้าน: ${wallet.totalCredit.toStringAsFixed(2)} บาท '
            '(ถอนได้ ${wallet.withdrawableCredit.toStringAsFixed(2)} / '
            'ล็อก ${wallet.lockedCredit.toStringAsFixed(2)})',
          if (wallet != null)
            'สัญญา: ${contractCancelled ? 'ยกเลิกแล้ว' : 'ยังมีผล'}',
        ];

        return _AdminInfoCard(
          title: shop.displayName,
          subtitle: '${shop.serviceType} • ${shop.status}',
          imageUrl: displayImageUrl,
          statusChip: _StatusChip(
            label: contractCancelled
                ? 'contract cancelled'
                : shop.isApproved
                    ? 'approved'
                    : shop.isRejected
                        ? 'rejected'
                        : shop.isPendingReview
                            ? 'pending'
                            : shop.status,
          ),
          detailLines: <String>[
            'เจ้าของ (van1): ${shop.ownerId}',
            if (shop.phone != null) 'โทร: ${shop.phone}',
            if (shop.email != null) 'อีเมล: ${shop.email}',
            if (shop.address != null) 'ที่อยู่: ${shop.address}',
            ...walletLines,
            'จำกัดรูป: ${mediaSettings.maxImageCount} รูป',
            'อัปโหลดวิดีโอ: ${mediaSettings.canUploadVideo ? 'อนุญาต' : 'ไม่อนุญาต'}',
            'แหล่งข้อมูล: ${shop.collection}',
            'โปรไฟล์ครบ: ${shop.isProfileCompleted ? 'ใช่' : 'ยังไม่ครบ'}',
            if (shop.createdAt != null) 'อัปเดต: ${_formatDateTime(shop.createdAt!)}',
          ],
          actions: <Widget>[
            if (!shop.isApproved && !shop.isRejected)
              FilledButton.icon(
                onPressed: () => _approve(context),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('อนุมัติ'),
              ),
            if (!shop.isApproved && !shop.isRejected) const SizedBox(width: 8),
            IconButton(
              tooltip: 'ตั้งค่ารูป/วิดีโอ',
              onPressed: () => showShopMediaSettingsDialog(context, shop: shop),
              icon: const Icon(Icons.tune_outlined),
            ),
            IconButton(
              tooltip: 'ดูสินค้า',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ShopUploadedProductsScreen(shop: shop),
                ),
              ),
              icon: const Icon(Icons.inventory_2_outlined),
            ),
            IconButton(
              tooltip: 'ช่วยอัปโหลด',
              onPressed: () => openAdminHelpUploadProduct(context, shop),
              icon: const Icon(Icons.upload_outlined),
            ),
            if (shop.isApproved && !contractCancelled)
              OutlinedButton.icon(
                onPressed: () => _cancelContract(context),
                icon: const Icon(Icons.gavel_outlined, size: 18),
                label: const Text('ยกเลิกสัญญา'),
              ),
            if (!shop.isRejected)
              OutlinedButton.icon(
                onPressed: shop.isApproved ? null : () => _reject(context),
                icon: const Icon(Icons.block_outlined, size: 18),
                label: const Text('ปฏิเสธ'),
              ),
          ],
        );
      },
    );
  }
}

Future<void> showShopMediaSettingsDialog(
  BuildContext context, {
  required AdminShopRecord shop,
}) async {
  final current = await AdminRepository.fetchShopMediaSettings(shop.ownerId);
  if (!context.mounted) {
    return;
  }

  final maxImagesController = TextEditingController(text: '${current.maxImageCount}');
  var canUploadVideo = current.canUploadVideo;

  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          return AlertDialog(
            title: Text('ตั้งค่าสื่อ — ${shop.displayName}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: maxImagesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'จำนวนรูปสูงสุดต่อสินค้า',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('อนุญาตอัปโหลดวิดีโอ'),
                  value: canUploadVideo,
                  onChanged: (value) => setLocalState(() => canUploadVideo = value),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ยกเลิก')),
              FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('บันทึก')),
            ],
          );
        },
      );
    },
  );

  final parsedMaxImages = int.tryParse(maxImagesController.text.trim()) ?? current.maxImageCount;
  maxImagesController.dispose();
  if (saved != true || !context.mounted) {
    return;
  }

  final adminUid = FirebaseAuth.instance.currentUser?.uid;
  if (adminUid == null) {
    return;
  }

  try {
    await AdminRepository.updateShopMediaSettings(
      shop: shop,
      maxImageCount: parsedMaxImages.clamp(1, 30),
      canUploadVideo: canUploadVideo,
      adminUid: adminUid,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกการตั้งค่า ${shop.displayName} แล้ว')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('บันทึกไม่สำเร็จ: $error')),
      );
    }
  }
}

class AdminPendingProductReviewScreen extends StatelessWidget {
  const AdminPendingProductReviewScreen({
    super.key,
    required this.product,
    required this.processing,
    required this.onApprove,
    required this.onReject,
    this.onEdit,
  });

  final AdminProductRecord product;
  final bool processing;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final description = product.description?.trim();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (product.imageUrls.isNotEmpty)
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: product.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AdminSafeNetworkImage(
                      url: product.imageUrls[index],
                      width: 220,
                      height: 220,
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          Text(
            product.name,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text('ร้าน: ${product.shopName ?? product.ownerUid ?? '-'}'),
          Text('ราคา: ฿${formatAdminBaht(product.price)}'),
          Text(
            'ประเภท: ${product.reviewType == 'update' ? 'แก้ไขสินค้าเดิม' : 'สินค้าใหม่'}',
          ),
          if (description != null && description.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            const Text('รายละเอียด', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(description),
          ],
          const SizedBox(height: 12),
          const Text('เหตุผลจาก AI', style: TextStyle(fontWeight: FontWeight.w700)),
          Text(product.aiReviewSummary),
          if (onEdit != null) ...<Widget>[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: processing ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('แก้ไขรายละเอียด (ความมั่นใจต่ำกว่า 80%)'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: processing ? null : onReject,
                  icon: const Icon(Icons.block_outlined, size: 16),
                  label: const Text('ปฏิเสธ'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: processing ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                  ),
                  icon: processing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(processing ? 'กำลังดำเนินการ...' : 'อนุมัติขึ้นขาย'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ShopUploadedProductsScreen extends StatelessWidget {
  const ShopUploadedProductsScreen({super.key, required this.shop});

  final AdminShopRecord shop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFE65100),
        foregroundColor: Colors.white,
        title: Text('สินค้า — ${shop.displayName}'),
      ),
      body: StreamBuilder<List<AdminProductRecord>>(
        stream: AdminRepository.streamProductsForShop(shop.ownerId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('โหลดสินค้าไม่สำเร็จ: ${snapshot.error}'));
          }

          final products = snapshot.data ?? <AdminProductRecord>[];
          if (products.isEmpty) {
            return const Center(child: Text('ร้านนี้ยังไม่มีสินค้า'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              return ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFFFFE0B2)),
                ),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product.imageUrls.isNotEmpty
                      ? AdminSafeNetworkImage(
                          url: product.imageUrls.first,
                          width: 48,
                          height: 48,
                        )
                      : const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                ),
                title: Text(product.name),
                subtitle: Text(
                  '฿${formatAdminBaht(product.price)} • สต็อก ${product.stock ?? 0}'
                  '${product.uploadedByAdmin ? ' • แอดมินอัปโหลด' : ''}'
                  '${product.videoUrl != null ? ' • มีวิดีโอ' : ''}',
                ),
                trailing: _StatusChip(label: product.isActive ? 'active' : 'inactive'),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminInfoCard extends StatelessWidget {
  const _AdminInfoCard({
    required this.title,
    required this.subtitle,
    required this.detailLines,
    this.imageUrl,
    this.actions,
    this.statusChip,
  });

  final String title;
  final String subtitle;
  final List<String> detailLines;
  final String? imageUrl;
  final List<Widget>? actions;
  final Widget? statusChip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AdminSafeAvatar(imageUrl: imageUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (statusChip != null) statusChip!,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFFE65100)),
                    ),
                    const SizedBox(height: 8),
                    ...detailLines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF6B7280)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (actions != null && actions!.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(spacing: 4, runSpacing: 4, children: actions!),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    Color bg;
    Color fg;
    if (normalized.contains('approve') || normalized == 'online' || normalized == 'active') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (normalized.contains('reject') || normalized == 'cancelled' || normalized == 'inactive') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    } else if (normalized.contains('pending')) {
      bg = const Color(0xFFFFEDD5);
      fg = const Color(0xFF9A3412);
    } else {
      bg = const Color(0xFFF3F4F6);
      fg = const Color(0xFF374151);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

String _formatDateTime(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}
