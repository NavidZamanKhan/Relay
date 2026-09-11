import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_mark.dart';

/// Full-screen branded loading gate displayed while verifying authentication
/// and restoring session credentials on cold start or hot restart.
class RelaySplashScreen extends StatelessWidget {
  const RelaySplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final fg = isDark ? Colors.white : RelayColors.ink;
    final muted = isDark ? Colors.white54 : RelayColors.inkSoft;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),
            // Centered Brand Icon and Wordmark
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2124) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/brand/relay_app_icon.png',
                        width: 88,
                        height: 88,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Center(
                          child: RelayMark(size: 56, onDark: isDark),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Relay',
                    style: TextStyle(
                      color: fg,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            // Bottom Loading Indicator and Status Caption
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CupertinoActivityIndicator(
                    radius: 11,
                    color: isDark ? Colors.white70 : RelayColors.inkSoft,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Securing connection...',
                    style: TextStyle(
                      color: muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
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
