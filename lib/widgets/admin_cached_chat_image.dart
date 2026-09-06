import 'dart:io';

import 'package:flutter/material.dart';

import '../services/admin_chat_cache_service.dart';

/// Chat image that reads from local disk cache first, then downloads in background.
class AdminCachedChatImage extends StatefulWidget {
  const AdminCachedChatImage({
    super.key,
    required this.url,
    this.width = 120,
    this.height = 120,
    this.fit = BoxFit.cover,
    this.borderRadius = 8,
  });

  final String url;
  final double width;
  final double height;
  final BoxFit fit;
  final double borderRadius;

  @override
  State<AdminCachedChatImage> createState() => _AdminCachedChatImageState();
}

class _AdminCachedChatImageState extends State<AdminCachedChatImage> {
  File? _localFile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AdminCachedChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url.trim() != widget.url.trim()) {
      _localFile = null;
      _loading = true;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final trimmed = widget.url.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }

    final cache = AdminChatCacheService.instance;
    var file = await cache.cachedImageFile(trimmed);
    file ??= await cache.fetchAndCacheImage(trimmed);

    if (!mounted) {
      return;
    }
    setState(() {
      _localFile = file;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    if (_localFile != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.file(
          _localFile!,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholder(showProgress: false),
        ),
      );
    }

    if (!_loading) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          widget.url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          gaplessPlayback: true,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              return child;
            }
            return _placeholder(showProgress: true);
          },
          errorBuilder: (_, __, ___) => _placeholder(showProgress: false),
        ),
      );
    }

    return _placeholder(showProgress: true);
  }

  Widget _placeholder({required bool showProgress}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Container(
        width: widget.width,
        height: widget.height,
        color: const Color(0xFFF3F4F6),
        alignment: Alignment.center,
        child: showProgress
            ? SizedBox(
                width: widget.width * 0.28,
                height: widget.height * 0.28,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.broken_image_outlined, color: Color(0xFF9CA3AF)),
      ),
    );
  }
}
