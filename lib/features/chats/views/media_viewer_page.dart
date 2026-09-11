import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/relay_toast.dart';
import '../models/relay_message.dart';
import '../widgets/relay_message_image.dart';

/// Full-screen interactive media viewer supporting pinch-to-zoom, double-tap zoom,
/// vertical drag-to-dismiss with dynamic backdrop opacity, share actions, and captions.
class MediaViewerPage extends StatefulWidget {
  const MediaViewerPage({
    super.key,
    required this.message,
    this.heroTag,
  });

  final RelayMessage message;
  final String? heroTag;

  static void open(BuildContext context, RelayMessage message, {String? heroTag}) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, animation, secondaryAnimation) => MediaViewerPage(
          message: message,
          heroTag: heroTag,
        ),
        transitionsBuilder: (_, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  State<MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<MediaViewerPage>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _resetAnimController;
  Animation<Matrix4>? _resetAnimation;

  double _dragOffsetY = 0.0;
  bool _isDragging = false;
  bool _showOverlays = true;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _resetAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(() {
        if (_resetAnimation != null) {
          _transformController.value = _resetAnimation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _resetAnimController.dispose();
    super.dispose();
  }

  void _onDoubleTap(TapDownDetails details) {
    if (_resetAnimController.isAnimating) return;

    final currentScale = _transformController.value.getMaxScaleOnAxis();
    final targetMatrix = Matrix4.identity();

    if (currentScale <= 1.05) {
      // Zoom in to 2.5x centered on tap position
      final position = details.localPosition;
      targetMatrix
        ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0.0, 1.0)
        ..scaleByDouble(2.5, 2.5, 1.0, 1.0);
    }

    _resetAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: targetMatrix,
    ).animate(
      CurvedAnimation(parent: _resetAnimController, curve: Curves.easeOutCubic),
    );

    _resetAnimController.forward(from: 0.0);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    final scale = _transformController.value.getMaxScaleOnAxis();
    if (scale > 1.05) return;

    setState(() {
      _isDragging = true;
      _dragOffsetY += details.delta.dy;
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final velocity = details.primaryVelocity ?? 0.0;
    if (_dragOffsetY > 110.0 || velocity > 650.0) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _isDragging = false;
        _dragOffsetY = 0.0;
      });
    }
  }

  void _shareMedia() {
    final asset = widget.message.asset ?? widget.message.imageUrl ?? '';
    if (asset.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: asset));
      RelayToast.show(
        context,
        message: 'Image link copied to clipboard',
        icon: CupertinoIcons.doc_on_clipboard,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTag = widget.heroTag ?? 'shared-image-${widget.message.id}';
    final hasCaption = widget.message.text != null &&
        widget.message.text!.trim().isNotEmpty;

    final dragRatio = (_dragOffsetY.abs() / 320.0).clamp(0.0, 1.0);
    final bgOpacity = (1.0 - dragRatio * 0.75).clamp(0.0, 1.0);
    final scaleRatio = (1.0 - dragRatio * 0.15).clamp(0.85, 1.0);

    final senderName = widget.message.senderName ??
        (widget.message.isMine ? 'You' : 'Contact');
    final formattedTime =
        DateFormat('d MMM, HH:mm').format(widget.message.sentAt);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity * 0.96),
      body: Stack(
        children: [
          // Main Interactive Image
          GestureDetector(
            onTap: () => setState(() => _showOverlays = !_showOverlays),
            onDoubleTapDown: _onDoubleTap,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: Transform.translate(
                offset: Offset(0, _dragOffsetY),
                child: Transform.scale(
                  scale: scaleRatio,
                  child: Hero(
                    tag: effectiveTag,
                    child: InteractiveViewer(
                      transformationController: _transformController,
                      minScale: 0.8,
                      maxScale: 4.5,
                      child: RelayMessageImage(
                        message: widget.message,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Top App Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _showOverlays && !_isDragging ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  14,
                  MediaQuery.of(context).padding.top + 8,
                  14,
                  12,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.chevron_left,
                        color: Colors.white,
                        size: 26,
                      ),
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            senderName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedTime,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        CupertinoIcons.share,
                        color: Colors.white,
                        size: 22,
                      ),
                      tooltip: 'Share image',
                      onPressed: _shareMedia,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Caption Overlay
          if (hasCaption)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                opacity: _showOverlays && !_isDragging ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.78),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        color: Colors.white.withValues(alpha: 0.12),
                        child: Text(
                          widget.message.text!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
