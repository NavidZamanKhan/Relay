import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/services/connectivity_service.dart';
import '../chat_bloc.dart';

/// Unobtrusive animated connectivity banner indicating network status
/// (offline, connecting, or syncing pending outbox messages).
class ConnectivityStatusPill extends StatelessWidget {
  const ConnectivityStatusPill({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatBloc, ChatState, (NetworkStatus, int)>(
      selector: (s) => (s.networkStatus, s.outboxQueue.length),
      builder: (context, data) {
        final status = data.$1;
        final outboxCount = data.$2;
        final isOnline = status == NetworkStatus.online;

        final isVisible = !isOnline || outboxCount > 0;

        return AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOutCubic,
          child: !isVisible
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        context
                            .read<ChatBloc>()
                            .add(const ChatOutboxFlushRequested());
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: status == NetworkStatus.offline
                              ? Colors.red.withValues(alpha: 0.12)
                              : Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: status == NetworkStatus.offline
                                ? Colors.redAccent.withValues(alpha: 0.3)
                                : Colors.amber.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (status == NetworkStatus.offline)
                              const Icon(
                                CupertinoIcons.wifi_slash,
                                size: 13,
                                color: Colors.redAccent,
                              )
                            else
                              const SizedBox.square(
                                dimension: 11,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: Colors.amber,
                                ),
                              ),
                            const SizedBox(width: 7),
                            Text(
                              status == NetworkStatus.offline
                                  ? (outboxCount > 0
                                      ? 'Offline ($outboxCount queued: tap to retry)'
                                      : 'Waiting for network...')
                                  : (outboxCount > 0
                                      ? 'Syncing $outboxCount message(s)...'
                                      : 'Connecting...'),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: status == NetworkStatus.offline
                                    ? Colors.redAccent
                                    : Colors.amber.shade800,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}
