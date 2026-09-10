import 'dart:convert';
import 'dart:io';

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
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, _, _) => _buildFallback(context),
      );
    }
    if (src.startsWith('data:image') ||
        (!src.startsWith('/') && !src.startsWith('assets/') && src.length > 200)) {
      final rawBase64 = src.contains(',') ? src.split(',').last : src;
      try {
        final bytes = base64Decode(rawBase64);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          cacheWidth: (size * 3).round(),
          errorBuilder: (_, _, _) => _buildFallback(context),
        );
      } catch (_) {}
    }
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
        errorBuilder: (_, _, _) => _buildFallback(context),
      );
    }
    final file = File(src);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: (size * 3).round(),
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
