import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/relay_colors.dart';
import '../../../../core/widgets/relay_mark.dart';
import '../../../settings/settings_page.dart';
import '../../chat_models.dart';
import '../../conversation_page.dart';
import 'relay_desktop_nav_rail.dart';

class RelayDesktopDetailPane extends StatelessWidget {
  const RelayDesktopDetailPane({
    super.key,
    required this.selectedTab,
    this.activeConversation,
  });

  final DesktopNavTab selectedTab;
  final Conversation? activeConversation;

  @override
  Widget build(BuildContext context) {
    if (selectedTab == DesktopNavTab.settings) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: const Scaffold(
            body: SafeArea(
              child: SettingsPage(showBackButton: false),
            ),
          ),
        ),
      );
    }

    if (selectedTab == DesktopNavTab.calls) {
      return const _PlaceholderPane(
        icon: CupertinoIcons.phone,
        title: 'Calls',
        subtitle: 'Recent encrypted voice and video calls will appear here.',
      );
    }

    if (selectedTab == DesktopNavTab.status) {
      return const _PlaceholderPane(
        icon: CupertinoIcons.smallcircle_fill_circle,
        title: 'Status Updates',
        subtitle: 'Share encrypted ephemeral updates with your contacts.',
      );
    }

    if (selectedTab == DesktopNavTab.starred) {
      return const _PlaceholderPane(
        icon: CupertinoIcons.star,
        title: 'Starred Messages',
        subtitle: 'Bookmark important messages to access them quickly across devices.',
      );
    }

    // Chats tab
    if (activeConversation != null) {
      return ConversationPage(
        key: ValueKey(activeConversation!.id),
        contactId: activeConversation!.id,
        contactName: activeConversation!.name,
        avatarAsset: activeConversation!.avatarAsset,
        online: activeConversation!.online,
        recipientId: activeConversation!.recipientId,
        showBackButton: false,
      );
    }

    // Empty state matching WhatsApp macOS layout
    return const _DesktopEmptyState();
  }
}

class _DesktopEmptyState extends StatelessWidget {
  const _DesktopEmptyState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RelayMark(size: 78),
                  const SizedBox(height: 20),
                  Text(
                    'Relay Desktop',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send and receive encrypted messages without keeping your phone online.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.lock_fill,
                    size: 13,
                    color: RelayColors.mint,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Your personal messages are end-to-end encrypted',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.8),
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

class _PlaceholderPane extends StatelessWidget {
  const _PlaceholderPane({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
