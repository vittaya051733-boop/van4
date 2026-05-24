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
        color: const Color(0xFFFFEDD5),
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
        color: const Color(0xFFFFEDD5),
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
