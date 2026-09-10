import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';

import '../theme/relay_colors.dart';

/// A production-grade, Cupertino-styled emoji picker widget for Relay.
///
/// Features the complete Unicode emoji library (1,500+ emojis across 8 categories),
/// rendered in Apple's authentic native style on iOS/macOS devices.
class RelayEmojiPicker extends StatelessWidget {
  const RelayEmojiPicker({
    super.key,
    required this.textEditingController,
    this.onEmojiSelected,
    this.onBackspacePressed,
    this.height = 270,
  });

  final TextEditingController textEditingController;
  final void Function(Category? category, Emoji emoji)? onEmojiSelected;
  final VoidCallback? onBackspacePressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? RelayColors.night : RelayColors.porcelain;
    final surfaceColor = isDark ? RelayColors.nightRaised : RelayColors.paper;
    final iconColor = isDark ? RelayColors.moonMuted : RelayColors.inkSoft;
    const activeColor = RelayColors.coral;

    final isIOS = foundation.defaultTargetPlatform == TargetPlatform.iOS ||
        foundation.defaultTargetPlatform == TargetPlatform.macOS;

    return Container(
      height: height,
      color: backgroundColor,
      child: EmojiPicker(
        textEditingController: textEditingController,
        onEmojiSelected: onEmojiSelected,
        onBackspacePressed: onBackspacePressed,
        config: Config(
          height: height,
          checkPlatformCompatibility: true,
          emojiViewConfig: EmojiViewConfig(
            columns: isIOS ? 7 : 8,
            emojiSizeMax: 30 * (isIOS ? 1.15 : 1.0),
            verticalSpacing: 4,
            horizontalSpacing: 4,
            gridPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            recentsLimit: 28,
            backgroundColor: backgroundColor,
            buttonMode: ButtonMode.CUPERTINO,
            loadingIndicator: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: activeColor,
              ),
            ),
            noRecents: Center(
              child: Text(
                'No Recent Emojis',
                style: TextStyle(
                  color: iconColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          categoryViewConfig: CategoryViewConfig(
            tabIndicatorAnimDuration: kTabScrollDuration,
            backgroundColor: surfaceColor,
            indicatorColor: activeColor,
            iconColor: iconColor,
            iconColorSelected: activeColor,
            backspaceColor: activeColor,
            dividerColor: Theme.of(context).dividerColor.withValues(alpha: .5),
          ),
          bottomActionBarConfig: BottomActionBarConfig(
            enabled: true,
            backgroundColor: surfaceColor,
            buttonColor: surfaceColor,
            buttonIconColor: iconColor,
          ),
          searchViewConfig: SearchViewConfig(
            backgroundColor: surfaceColor,
            buttonIconColor: iconColor,
          ),
        ),
      ),
    );
  }
}
