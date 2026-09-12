import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/relay_colors.dart';
import '../../../../core/widgets/relay_avatar.dart';
import '../../chat_bloc.dart';
import '../../chat_models.dart';
import '../../new_relay_sheet.dart';
import '../../relay_receipt.dart';

class RelayDesktopChatListPane extends StatefulWidget {
  const RelayDesktopChatListPane({
    super.key,
    required this.onSelectChat,
    this.selectedChatId,
  });

  final ValueChanged<Conversation> onSelectChat;
  final String? selectedChatId;

  @override
  State<RelayDesktopChatListPane> createState() =>
      _RelayDesktopChatListPaneState();
}

class _RelayDesktopChatListPaneState extends State<RelayDesktopChatListPane> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openNewChat(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 480),
      backgroundColor: Colors.transparent,
      builder: (_) => const NewRelaySheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.65),
          ),
        ),
      ),
      child: SafeArea(
        right: false,
        bottom: false,
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 8),
              child: Row(
                children: [
                  Text(
                    'Chats',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'New conversation',
                    icon: const Icon(CupertinoIcons.square_pencil, size: 20),
                    onPressed: () => _openNewChat(context),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More options',
                    icon: const Icon(CupertinoIcons.ellipsis, size: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (value) {
                      if (value == 'new_group') {
                        _openNewChat(context);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'new_group',
                        child: Text('New group', style: TextStyle(fontSize: 13.5)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      context.read<ChatBloc>().add(ChatSearchChanged(v)),
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    fillColor: dark
                        ? RelayColors.nightSoft
                        : RelayColors.paperRaised,
                    prefixIcon: const Icon(CupertinoIcons.search, size: 17),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.zero,
                    suffixIcon: BlocSelector<ChatBloc, ChatState, bool>(
                      selector: (s) => s.searchQuery.isNotEmpty,
                      builder: (_, hasQuery) => hasQuery
                          ? IconButton(
                              icon: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 15,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                context.read<ChatBloc>().add(
                                      const ChatSearchChanged(''),
                                    );
                              },
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),

            // Filter Pills (All, Unread, Favorites, Groups)
            BlocBuilder<ChatBloc, ChatState>(
              buildWhen: (a, b) =>
                  a.filter != b.filter || a.conversations != b.conversations,
              builder: (context, state) {
                final unreadCount = state.conversations
                    .where((c) => c.unread > 0)
                    .length;
                final favoritesCount =
                    state.conversations.where((c) => c.pinned).length;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _FilterPill(
                        label: 'All',
                        value: InboxFilter.all,
                        selected: state.filter,
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Unread',
                        count: unreadCount,
                        value: InboxFilter.unread,
                        selected: state.filter,
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Favorites',
                        count: favoritesCount > 0 ? favoritesCount : null,
                        value: InboxFilter.favorites,
                        selected: state.filter,
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Groups',
                        value: InboxFilter.groups,
                        selected: state.filter,
                      ),
                    ],
                  ),
                );
              },
            ),

            const Divider(height: 1),

            // Conversation List
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                buildWhen: (a, b) =>
                    a.conversations != b.conversations ||
                    a.searchQuery != b.searchQuery ||
                    a.filter != b.filter ||
                    a.activeId != b.activeId,
                builder: (context, state) {
                  final chats = state.filteredConversations;

                  if (chats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              state.filter == InboxFilter.unread
                                  ? CupertinoIcons.checkmark_circle
                                  : CupertinoIcons.search,
                              size: 32,
                              color: RelayColors.inkSoft,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              state.filter == InboxFilter.unread &&
                                      state.searchQuery.isEmpty
                                  ? 'All caught up'
                                  : 'No conversations found',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    itemCount: chats.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 2),
                    itemBuilder: (context, i) {
                      final chat = chats[i];
                      final isSelected =
                          chat.id == (widget.selectedChatId ?? state.activeId);

                      return _DesktopChatTile(
                        chat: chat,
                        isSelected: isSelected,
                        onTap: () => widget.onSelectChat(chat),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.value,
    required this.selected,
    this.count,
  });

  final String label;
  final InboxFilter value;
  final InboxFilter selected;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final isSelected = value == selected;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = isSelected
        ? RelayColors.coralDeep.withValues(alpha: 0.16)
        : (isDark ? RelayColors.nightSoft : RelayColors.paperRaised);

    final foregroundColor = isSelected
        ? RelayColors.coralDeep
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.read<ChatBloc>().add(ChatFilterChanged(value)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: foregroundColor,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? RelayColors.coralDeep
                        : Theme.of(context).dividerColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : foregroundColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopChatTile extends StatelessWidget {
  const _DesktopChatTile({
    required this.chat,
    required this.isSelected,
    required this.onTap,
  });

  final Conversation chat;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final tileBackground = isSelected
        ? (isDark
            ? RelayColors.coralDeep.withValues(alpha: 0.22)
            : RelayColors.coral.withValues(alpha: 0.16))
        : Colors.transparent;

    return Material(
      color: tileBackground,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              RelayAvatar(
                name: chat.name,
                asset: chat.avatarAsset,
                size: 44,
                online: chat.online,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            chat.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected || chat.unread > 0
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          chat.timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: chat.unread > 0
                                ? RelayColors.coralDeep
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.75),
                            fontWeight: chat.unread > 0
                                ? FontWeight.w700
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (chat.delivery != null) ...[
                          RelayReceipt(stage: chat.delivery!),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            chat.isPeerTyping ? 'typing…' : chat.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: chat.isPeerTyping
                                  ? RelayColors.mint
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              fontStyle: chat.isPeerTyping
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ),
                        if (chat.pinned) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            CupertinoIcons.pin_fill,
                            size: 13,
                            color: RelayColors.inkSoft,
                          ),
                        ],
                        if (chat.unread > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: RelayColors.coralDeep,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${chat.unread}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
