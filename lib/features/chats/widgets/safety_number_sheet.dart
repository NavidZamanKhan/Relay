import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/crypto/crypto_service.dart';
import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_button.dart';
import '../../../core/widgets/relay_toast.dart';

/// Modal bottom sheet allowing users to verify end-to-end encryption integrity
/// by comparing cryptographic safety numbers with a peer contact.
class SafetyNumberSheet extends StatefulWidget {
  const SafetyNumberSheet({
    super.key,
    required this.peerName,
    required this.myPublicKey,
    required this.peerPublicKey,
  });

  final String peerName;
  final String myPublicKey;
  final String peerPublicKey;

  static Future<void> show(
    BuildContext context, {
    required String peerName,
    required String myPublicKey,
    required String peerPublicKey,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SafetyNumberSheet(
        peerName: peerName,
        myPublicKey: myPublicKey,
        peerPublicKey: peerPublicKey,
      ),
    );
  }

  @override
  State<SafetyNumberSheet> createState() => _SafetyNumberSheetState();
}

class _SafetyNumberSheetState extends State<SafetyNumberSheet> {
  String? _safetyNumber;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _computeSafetyNumber();
  }

  Future<void> _computeSafetyNumber() async {
    final code = await CryptoService.computeSafetyNumber(
      widget.myPublicKey,
      widget.peerPublicKey,
    );
    if (mounted) {
      setState(() {
        _safetyNumber = code;
        _loading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_safetyNumber == null) return;
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: _safetyNumber!));
    RelayToast.show(
      context,
      message: 'Safety code copied to clipboard',
      icon: CupertinoIcons.doc_on_clipboard,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Security shield icon
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: RelayColors.coral.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                CupertinoIcons.shield_lefthalf_fill,
                color: RelayColors.coral,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 14),

          Text(
            'Verify Security Code',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
          ),
          const SizedBox(height: 8),

          Text(
            'Compare this 30-digit security code with ${widget.peerName}\'s device to verify that your conversation is end-to-end encrypted with X25519 and AES-GCM.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          // Safety number blocks container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
            ),
            child: _loading
                ? const Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: RelayColors.coral,
                      ),
                    ),
                  )
                : Text(
                    _safetyNumber ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      height: 1.7,
                    ),
                  ),
          ),
          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading ? null : _copyToClipboard,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Copy Code',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RelayButton(
                  label: 'Done',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
