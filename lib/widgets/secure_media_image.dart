import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

/// Renders a stored media reference that may be:
///   - a storage path (`avatars/…`, `messages/…`, `memories/…`) resolved to a
///     short-lived signed URL (buckets are private — SEC-14),
///   - a legacy public storage URL (pre-SEC-14 data) also re-signed,
///   - an external URL (used as-is),
///   - a local file path (pending uploads, shown via [Image.file]).
class SecureMediaImage extends StatefulWidget {
  const SecureMediaImage({
    super.key,
    required this.value,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  final String value;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  @override
  State<SecureMediaImage> createState() => _SecureMediaImageState();
}

class _SecureMediaImageState extends State<SecureMediaImage> {
  late Future<String> _urlFuture;
  bool _isLocalFile = false;

  @override
  void initState() {
    super.initState();
    _urlFuture = _resolve();
  }

  @override
  void didUpdateWidget(covariant SecureMediaImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _isLocalFile = false;
      _urlFuture = _resolve();
    }
  }

  Future<String> _resolve() async {
    final value = widget.value;
    if (value.isEmpty) return value;
    if (!value.startsWith('http')) {
      try {
        final exists = await File(value).exists();
        if (exists && mounted) {
          _isLocalFile = true;
          return value;
        }
      } catch (_) {}
    }
    return SupabaseService().secureMediaUrl(value);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final fallback =
        widget.errorWidget ?? widget.placeholder ?? const SizedBox.shrink();

    if (value.isEmpty) return fallback;

    // Local file (pending upload) — render straight from disk.
    if (_isLocalFile) {
      return Image.file(
        File(value),
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return FutureBuilder<String>(
      future: _urlFuture,
      builder: (context, snapshot) {
        final url = snapshot.data;
        if (url == null || url.isEmpty) {
          return widget.placeholder ?? const SizedBox.shrink();
        }
        // If resolved to a local file path, render from disk.
        if (_isLocalFile) {
          return Image.file(
            File(url),
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (_, _, _) => fallback,
          );
        }
        return CachedNetworkImage(
          imageUrl: url,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          placeholder: (_, _) => widget.placeholder ?? const SizedBox.shrink(),
          errorWidget: (_, _, _) => fallback,
        );
      },
    );
  }
}
