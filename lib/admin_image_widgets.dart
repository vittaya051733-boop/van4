import 'package:flutter/material.dart';

/// โหลดรูปจาก URL โดยไม่โยน exception ถ้าไฟล์หาย (404) หรือ token หมดอายุ
class AdminSafeAvatar extends StatelessWidget {
  const AdminSafeAvatar({
    super.key,
    this.imageUrl,
    this.size = 56,
    this.borderRadius = 16,
  });

  final String? imageUrl;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final trimmed = imageUrl?.trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Container(
        width: size,
        height: size,
        color: Colors.white,
        child: trimmed != null && trimmed.isNotEmpty
            ? Image.network(
                trimmed,
                width: size,
                height: size,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _placeholder(size * 0.45),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return Center(
                    child: SizedBox(
                      width: size * 0.35,
                      height: size * 0.35,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              )
            : _placeholder(size * 0.45),
      ),
    );
  }

  Widget _placeholder(double iconSize) {
    return Center(
      child: Icon(Icons.storefront_outlined, color: const Color(0xFFE65100), size: iconSize),
    );
  }
}

class AdminSafeNetworkImage extends StatelessWidget {
  const AdminSafeNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: Colors.white,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: const Color(0xFFE65100),
          size: (width != null && height != null) ? (width! < height! ? width! : height!) * 0.4 : 24,
        ),
      ),
    );

    if (borderRadius == null) {
      return image;
    }
    return ClipRRect(borderRadius: borderRadius!, child: image);
  }
}

/// Thumbnail สำหรับรายการใน inbox งานแอดมิน (แสดงรูปแรก + badge ถ้ามีหลายรูป)
class AdminWorkInboxThumbnail extends StatelessWidget {
  const AdminWorkInboxThumbnail({
    super.key,
    required this.imageUrls,
    this.size = 72,
  });

  final List<String> imageUrls;
  final double size;

  @override
  Widget build(BuildContext context) {
    final urls = imageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }

    if (urls.length == 1) {
      return AdminSafeNetworkImage(
        url: urls.first,
        width: size,
        height: size,
        borderRadius: BorderRadius.circular(12),
      );
    }

    final visible = urls.take(3).toList(growable: false);
    final extraCount = urls.length - visible.length;
    final thumbSize = size * 0.72;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          for (var index = 0; index < visible.length; index++)
            Positioned(
              left: index * (thumbSize * 0.28),
              top: index * (thumbSize * 0.12),
              child: AdminSafeNetworkImage(
                url: visible[index],
                width: thumbSize,
                height: thumbSize,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          if (extraCount > 0)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827).withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+$extraCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String? resolveShopDisplayImageUrl({
  String? registrationImageUrl,
  String? publicShopImageUrl,
}) {
  final candidates = <String>[
    if (registrationImageUrl != null) registrationImageUrl.trim(),
    if (publicShopImageUrl != null) publicShopImageUrl.trim(),
  ].where((url) => url.isNotEmpty).toList(growable: false);

  if (candidates.isEmpty) {
    return null;
  }
  return candidates.first;
}
