import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/relay_colors.dart';
import '../models/relay_message.dart';

/// Robust multi-source image widget supporting bundled assets, local file paths,
/// offline document directory cache, network URLs, and inline base64 fallback.
class RelayMessageImage extends StatefulWidget {
  const RelayMessageImage({
    super.key,
    required this.message,
    this.fit = BoxFit.cover,
  });

  final RelayMessage message;
  final BoxFit fit;

  @override
  State<RelayMessageImage> createState() => _RelayMessageImageState();
}

class _RelayMessageImageState extends State<RelayMessageImage> {
  String? _resolvedLocalPath;

  @override
  void initState() {
    super.initState();
    _checkPersistentLocalCache();
  }

  @override
  void didUpdateWidget(covariant RelayMessageImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.asset != widget.message.asset ||
        oldWidget.message.imageUrl != widget.message.imageUrl ||
        oldWidget.message.imageData != widget.message.imageData) {
      _checkPersistentLocalCache();
    }
  }

  Future<void> _checkPersistentLocalCache() async {
    final msg = widget.message;
    // 1. Direct asset
    if (msg.asset != null && msg.asset!.isNotEmpty) {
      if (msg.asset!.startsWith('assets/')) {
        if (mounted) setState(() => _resolvedLocalPath = msg.asset);
        return;
      }
      try {
        final f = File(msg.asset!);
        if (f.existsSync()) {
          if (mounted) setState(() => _resolvedLocalPath = msg.asset);
          return;
        }
      } catch (_) {}
    }

    // 2. Persistent document directory cache
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final target = File('${docsDir.path}/relay_images/img_${msg.id}.jpg');
      if (await target.exists() && await target.length() > 0) {
        if (mounted) setState(() => _resolvedLocalPath = target.path);
        return;
      }
    } catch (_) {}

    // Fallback: If imageData is present, eagerly cache it to disk
    if (msg.imageData != null && msg.imageData!.isNotEmpty) {
      try {
        final rawBase64 = msg.imageData!.contains(',')
            ? msg.imageData!.split(',').last
            : msg.imageData!;
        final bytes = base64Decode(rawBase64);
        _cacheBytesToDocsDir(msg.id, bytes);
      } catch (_) {}
    }
  }

  Future<void> _cacheBytesToDocsDir(String messageId, List<int> bytes) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final dir = Directory('${docsDir.path}/relay_images');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final file = File('${dir.path}/img_$messageId.jpg');
      await file.writeAsBytes(bytes);
      if (mounted) setState(() => _resolvedLocalPath = file.path);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.message;

    // 1. If persistent local cache or existing asset path was resolved
    if (_resolvedLocalPath != null) {
      if (_resolvedLocalPath!.startsWith('assets/')) {
        return Image.asset(
          _resolvedLocalPath!,
          fit: widget.fit,
          gaplessPlayback: true,
          cacheWidth: 1440,
          errorBuilder: (_, _, _) => _buildFallback(msg),
        );
      }
      try {
        final file = File(_resolvedLocalPath!);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: widget.fit,
            gaplessPlayback: true,
            cacheWidth: 1440,
            errorBuilder: (_, _, _) => _buildFallback(msg),
          );
        }
      } catch (_) {}
    }

    // 2. Direct synchronous check for message.asset if it exists right now
    if (msg.asset != null && msg.asset!.isNotEmpty) {
      if (msg.asset!.startsWith('assets/')) {
        return Image.asset(
          msg.asset!,
          fit: widget.fit,
          gaplessPlayback: true,
          cacheWidth: 1440,
          errorBuilder: (_, _, _) => _buildFallback(msg),
        );
      }
      try {
        final file = File(msg.asset!);
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: widget.fit,
            gaplessPlayback: true,
            cacheWidth: 1440,
            errorBuilder: (_, _, _) => _buildFallback(msg),
          );
        }
      } catch (_) {}
    }

    // 3. Fallback to Cloud Storage URL or inline base64
    return _buildFallback(msg);
  }

  Widget _buildFallback(RelayMessage msg) {
    // A. Network URL
    if (msg.imageUrl != null &&
        msg.imageUrl!.isNotEmpty &&
        msg.imageUrl!.startsWith('http')) {
      return Image.network(
        msg.imageUrl!,
        fit: widget.fit,
        gaplessPlayback: true,
        cacheWidth: 1440,
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return ColoredBox(
            color: RelayColors.ink.withValues(alpha: .12),
            child: const Center(
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: RelayColors.coral,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => _buildBase64OrPlaceholder(msg),
      );
    }

    // B. Base64
    return _buildBase64OrPlaceholder(msg);
  }

  Widget _buildBase64OrPlaceholder(RelayMessage msg) {
    if (msg.imageData != null && msg.imageData!.isNotEmpty) {
      try {
        final rawBase64 = msg.imageData!.contains(',')
            ? msg.imageData!.split(',').last
            : msg.imageData!;
        final bytes = base64Decode(rawBase64);
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          cacheWidth: 1440,
          errorBuilder: (_, _, _) => _placeholder(),
        );
      } catch (_) {}
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      color: RelayColors.coralWash,
      child: const Center(
        child: Icon(
          CupertinoIcons.photo,
          color: RelayColors.coralDeep,
          size: 32,
        ),
      ),
    );
  }
}
