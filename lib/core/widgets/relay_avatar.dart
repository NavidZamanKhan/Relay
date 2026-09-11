import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/relay_colors.dart';

class RelayAvatar extends StatelessWidget {
  const RelayAvatar({
    super.key,
    required this.name,
    this.asset,
    this.size = 52,
    this.online = false,
    this.heroTag,
  });

  final String name;
  final String? asset;
  final double size;
  final bool online;
  final Object? heroTag;

  /// Standardized cache width for all avatar instances to ensure a single shared
  /// entry in Flutter's ImageCache across all list tiles, headers, and profile icons.
  static const int avatarCacheWidth = 256;

  /// In-memory cache for base64 decoded bytes so that MemoryImage uses the exact
  /// same Uint8List reference across builds and route transitions.
  static final Map<String, Uint8List> _base64Cache = <String, Uint8List>{};

  static Uint8List _getOrCreateBase64Bytes(String rawBase64) {
    final cached = _base64Cache[rawBase64];
    if (cached != null) return cached;
    final bytes = base64Decode(rawBase64);
    if (_base64Cache.length > 100) {
      _base64Cache.remove(_base64Cache.keys.first);
    }
    _base64Cache[rawBase64] = bytes;
    return bytes;
  }

  Widget _buildFallback(BuildContext context) {
    return ColoredBox(
      color: RelayColors.coralWash,
      child: Center(
        child: Text(
          name.isEmpty ? 'R' : name.characters.first.toUpperCase(),
          style: TextStyle(
            color: RelayColors.coralDeep,
            fontSize: size * .36,
            fontWeight: FontWeight.w800,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String src, BuildContext context) {
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return Image.network(
        src,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: avatarCacheWidth,
        errorBuilder: (_, _, _) => _buildFallback(context),
      );
    }
    if (src.startsWith('data:image') ||
        (!src.startsWith('/') && !src.startsWith('assets/') && src.length > 200)) {
      final rawBase64 = src.contains(',') ? src.split(',').last : src;
      try {
        final bytes = _getOrCreateBase64Bytes(rawBase64);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: avatarCacheWidth,
          errorBuilder: (_, _, _) => _buildFallback(context),
        );
      } catch (_) {}
    }
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: avatarCacheWidth,
        errorBuilder: (_, _, _) => _buildFallback(context),
      );
    }
    final file = File(src);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        cacheWidth: avatarCacheWidth,
        errorBuilder: (_, _, _) => _buildFallback(context),
      );
    }
    return _buildFallback(context);
  }

  @override
  Widget build(BuildContext context) {
    final avatar = Material(
      type: MaterialType.transparency,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.surface,
            ),
            child: ClipOval(
              child: asset == null || asset!.isEmpty
                  ? _buildFallback(context)
                  : _buildAvatarImage(asset!, context),
            ),
          ),
          if (online)
            Positioned(
              right: 0,
              bottom: size * .04,
              child: Container(
                width: size * .25,
                height: size * .25,
                decoration: BoxDecoration(
                  color: RelayColors.mint,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (heroTag == null) return avatar;
    return Hero(tag: heroTag!, child: avatar);
  }
}
