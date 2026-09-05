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

  @override
  Widget build(BuildContext context) {
    final avatar = Stack(
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
            child: asset == null
                ? ColoredBox(
                    color: RelayColors.coralWash,
                    child: Center(
                      child: Text(
                        name.isEmpty
                            ? 'R'
                            : name.characters.first.toUpperCase(),
                        style: TextStyle(
                          color: RelayColors.coralDeep,
                          fontSize: size * .36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  )
                : Image.asset(
                    asset!,
                    fit: BoxFit.cover,
                    // Decode close to rendered size. Production network
                    // avatars should follow the same memory discipline.
                    cacheWidth: (size * 3).round(),
                  ),
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
    );
    if (heroTag == null) return avatar;
    return Hero(tag: heroTag!, child: avatar);
  }
}
