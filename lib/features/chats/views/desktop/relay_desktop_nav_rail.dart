import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app_bloc.dart';
import '../../../../core/theme/relay_colors.dart';
import '../../../../core/widgets/relay_avatar.dart';
import '../../../../core/widgets/relay_mark.dart';
import '../../../auth/auth_bloc.dart';
import '../../../auth/profile_setup_page.dart';
import '../../chat_bloc.dart';

enum DesktopNavTab { chats, calls, status, starred, settings }

class RelayDesktopNavRail extends StatelessWidget {
  const RelayDesktopNavRail({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
  });

  final DesktopNavTab selectedTab;
  final ValueChanged<DesktopNavTab> onTabChanged;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final chatState = context.watch<ChatBloc>().state;

    final unreadCount = chatState.conversations.fold<int>(
      0,
      (sum, c) => sum + c.unread,
    );

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.65),
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 14),
            const RelayMark(size: 32),
            const SizedBox(height: 22),

            // Top Nav Items
            _RailItem(
              icon: CupertinoIcons.chat_bubble_2_fill,
              tooltip: 'Chats',
              selected: selectedTab == DesktopNavTab.chats,
              badgeCount: unreadCount,
              onTap: () => onTabChanged(DesktopNavTab.chats),
            ),
            const SizedBox(height: 6),
            _RailItem(
              icon: CupertinoIcons.phone,
              tooltip: 'Calls',
              selected: selectedTab == DesktopNavTab.calls,
              onTap: () => onTabChanged(DesktopNavTab.calls),
            ),
            const SizedBox(height: 6),
            _RailItem(
              icon: CupertinoIcons.smallcircle_fill_circle,
              tooltip: 'Status',
              selected: selectedTab == DesktopNavTab.status,
              onTap: () => onTabChanged(DesktopNavTab.status),
            ),
            const SizedBox(height: 6),
            _RailItem(
              icon: CupertinoIcons.star,
              tooltip: 'Starred messages',
              selected: selectedTab == DesktopNavTab.starred,
              onTap: () => onTabChanged(DesktopNavTab.starred),
            ),

            const Spacer(),

            // Bottom Nav Items
            IconButton(
              tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
              icon: Icon(
                isDark ? CupertinoIcons.sun_max : CupertinoIcons.moon,
                size: 20,
              ),
              onPressed: () {
                final next =
                    isDark ? ThemeMode.light : ThemeMode.dark;
                context.read<AppBloc>().add(AppThemeChanged(next));
              },
            ),
            const SizedBox(height: 6),
            _RailItem(
              icon: CupertinoIcons.gear_alt,
              tooltip: 'Settings',
              selected: selectedTab == DesktopNavTab.settings,
              onTap: () => onTabChanged(DesktopNavTab.settings),
            ),
            const SizedBox(height: 8),

            // Current User Avatar
            Tooltip(
              message: authState.displayName.isEmpty
                  ? 'My profile'
                  : authState.displayName,
              child: GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const ProfileSetupPage(editing: true),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: RelayAvatar(
                    name: authState.displayName,
                    asset: authState.avatarUrl,
                    size: 34,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    const activeColor = RelayColors.coralDeep;
    final inactiveColor =
        Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85);

    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: selected
                ? activeColor.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 21,
                  color: selected ? activeColor : inactiveColor,
                ),
              ),
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: RelayColors.coralDeep,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  badgeCount > 99 ? '99+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
