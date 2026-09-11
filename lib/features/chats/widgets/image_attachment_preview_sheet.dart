import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/relay_colors.dart';

/// Confirmation screen presented after selecting or capturing an image,
/// allowing the user to review the photo and attach an optional caption before sending.
class ImageAttachmentPreviewSheet extends StatefulWidget {
  const ImageAttachmentPreviewSheet({
    super.key,
    required this.imagePath,
    required this.onSend,
  });

  final String imagePath;
  final void Function(String caption) onSend;

  static Future<void> show(
    BuildContext context, {
    required String imagePath,
    required void Function(String caption) onSend,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageAttachmentPreviewSheet(
          imagePath: imagePath,
          onSend: onSend,
        ),
      ),
    );
  }

  @override
  State<ImageAttachmentPreviewSheet> createState() =>
      _ImageAttachmentPreviewSheetState();
}

class _ImageAttachmentPreviewSheetState
    extends State<ImageAttachmentPreviewSheet> {
  final _captionController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _captionController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSend() {
    final caption = _captionController.text.trim();
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
    widget.onSend(caption);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final file = File(widget.imagePath);

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.xmark,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const Text(
                    'Preview',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balancing width
                ],
              ),
            ),

            // Image Preview Container
            Expanded(
              child: Center(
                child: file.existsSync()
                    ? Image.file(
                        file,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                      )
                    : const Center(
                        child: Text(
                          'Image unavailable',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
              ),
            ),

            // Bottom Caption & Send Bar
            AnimatedPadding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomInset + 12),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 1.0,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _captionController,
                        focusNode: _focusNode,
                        maxLines: 4,
                        minLines: 1,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          height: 1.3,
                        ),
                        cursorColor: RelayColors.coral,
                        decoration: InputDecoration(
                          isDense: true,
                          filled: false,
                          fillColor: Colors.transparent,
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 15.5,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _handleSend,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: const BoxDecoration(
                        color: RelayColors.coral,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.arrow_up,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
