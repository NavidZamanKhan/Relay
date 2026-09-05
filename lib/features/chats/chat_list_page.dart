import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/motion/relay_motion.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_avatar.dart';
import '../../core/widgets/relay_mark.dart';
import '../auth/auth_bloc.dart';
import '../settings/settings_page.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';
import 'conversation_page.dart';
import 'new_relay_sheet.dart';
import 'relay_receipt.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});
  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _warmed = false;
  final _search = TextEditingController();
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_warmed) return;
    _warmed = true;
    // Warm the SAME resized provider the bubbles use; a full-size AssetImage
    // and a ResizeImage have different cache keys and cannot warm one another.
    precacheImage(
      const ResizeImage(
        AssetImage('assets/images/sylhet_evening.png'),
        width: 1100,
      ),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 5, 16, 12),
              child: SizedBox(
                height: 54,
                child: Row(
                  children: [
                    const RelayMark(size: 35),
                    const SizedBox(width: 11),
                    Text(
                      'Relay',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontSize: 27, letterSpacing: -.9),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Open profile and settings',
                      onPressed: () => Navigator.of(
                        context,
                      ).push(RelayMotion.route(const SettingsPage())),
                      icon: BlocSelector<AuthBloc, AuthState, String>(
                        selector: (s) => s.displayName,
                        builder: (_, name) => RelayAvatar(name: name, size: 36),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SizedBox(
                height: 46,
                child: TextField(
                  controller: _search,
                  onChanged: (v) =>
                      context.read<ChatBloc>().add(ChatSearchChanged(v)),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search messages or people',
                    fillColor: dark
                        ? RelayColors.nightSoft
                        : const Color(0xFFEEEFEA),
                    prefixIcon: const Icon(CupertinoIcons.search, size: 19),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    suffixIcon: BlocSelector<ChatBloc, ChatState, bool>(
                      selector: (s) => s.searchQuery.isNotEmpty,
                      builder: (_, hasQuery) => hasQuery
                          ? IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                                size: 17,
                              ),
                              onPressed: () {
                                _search.clear();
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
            const SizedBox(height: 15),
            BlocBuilder<ChatBloc, ChatState>(
              buildWhen: (a, b) =>
                  a.filter != b.filter || a.conversations != b.conversations,
              builder: (context, state) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  children: [
                    _Filter(
                      label: 'All',
                      count: state.conversations.length,
                      value: InboxFilter.all,
                      selected: state.filter,
                    ),
                    const SizedBox(width: 8),
                    _Filter(
                      label: 'Unread',
                      count: state.conversations
                          .where((c) => c.unread > 0)
                          .length,
                      value: InboxFilter.unread,
                      selected: state.filter,
                    ),
                    const SizedBox(width: 8),
                    _Filter(
                      label: 'Groups',
                      value: InboxFilter.groups,
                      selected: state.filter,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 9),
            Expanded(
              child: BlocBuilder<ChatBloc, ChatState>(
                buildWhen: (a, b) =>
                    a.conversations != b.conversations ||
                    a.searchQuery != b.searchQuery ||
                    a.filter != b.filter,
                builder: (context, state) {
                  final chats = state.filteredConversations;
                  if (chats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              state.filter == InboxFilter.unread
                                  ? CupertinoIcons.checkmark_circle
                                  : CupertinoIcons.search,
                              size: 34,
                              color: RelayColors.inkSoft,
                            ),
                            const SizedBox(height: 14),
                            Text(
                              state.filter == InboxFilter.unread &&
                                      state.searchQuery.isEmpty
                                  ? 'You’re all caught up'
                                  : 'No conversations found',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Your people are just a message away.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 112),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    itemCount: chats.length,
                    itemBuilder: (_, i) => _ConversationTile(chat: chats[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          showDragHandle: true,
          builder: (_) => const NewRelaySheet(),
        ),
        tooltip: 'New relay',
        heroTag: 'new-relay',
        elevation: 0,
        backgroundColor: RelayColors.coral,
        foregroundColor: RelayColors.ink,
        icon: const Icon(CupertinoIcons.square_pencil, size: 21),
        label: const Text(
          'New relay',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({
    required this.label,
    required this.value,
    required this.selected,
    this.count,
  });
  final String label;
  final InboxFilter value, selected;
  final int? count;
  @override
  Widget build(BuildContext context) {
    final active = value == selected;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      selected: active,
      button: true,
      child: Material(
        color: active
            ? (dark ? RelayColors.moon : RelayColors.ink)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.read<ChatBloc>().add(ChatFilterChanged(value)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? (dark ? RelayColors.ink : RelayColors.paper)
                        : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 7),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: active
                          ? (dark ? RelayColors.inkSoft : RelayColors.moonMuted)
                          : RelayColors.inkFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.chat});
  final Conversation chat;
  @override
  Widget build(BuildContext context) {
    final unread = chat.unread > 0;
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ConversationPage.open(context, chat),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 0),
          child: Row(
            children: [
              if (chat.isGroup)
                GroupAvatar(name: chat.name)
              else
                RelayAvatar(
                  name: chat.name,
                  asset: chat.avatarAsset,
                  size: 54,
                  online: chat.online,
                  heroTag: 'avatar-${chat.id}',
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 83),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(
                          context,
                        ).dividerColor.withValues(alpha: .75),
                        width: .65,
                      ),
                    ),
                  ),
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
                                fontSize: 15.5,
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                letterSpacing: -.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            chat.timeLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: unread
                                  ? (Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? RelayColors.coral
                                        : RelayColors.coralDeep)
                                  : muted,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          if (chat.delivery != null) ...[
                            RelayReceipt(stage: chat.delivery!, size: 14),
                            const SizedBox(width: 4),
                          ],
                          if (chat.previewKind != MessageKind.text) ...[
                            Icon(
                              switch (chat.previewKind) {
                                MessageKind.voice => CupertinoIcons.mic,
                                MessageKind.image => CupertinoIcons.photo,
                                _ => CupertinoIcons.doc,
                              },
                              size: 14,
                              color: muted,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Expanded(
                            child: Text(
                              chat.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: muted,
                                fontWeight: unread
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (chat.muted) ...[
                            const SizedBox(width: 6),
                            Icon(
                              CupertinoIcons.bell_slash,
                              size: 12,
                              color: muted,
                            ),
                          ],
                          if (unread) ...[
                            const SizedBox(width: 9),
                            Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              height: 20,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: RelayColors.coralWash,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                '${chat.unread}',
                                style: const TextStyle(
                                  color: RelayColors.coralDeep,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ] else if (chat.pinned) ...[
                            const SizedBox(width: 9),
                            Icon(
                              CupertinoIcons.pin_fill,
                              size: 12,
                              color: muted,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GroupAvatar extends StatelessWidget {
  const GroupAvatar({super.key, required this.name, this.size = 54});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: name == 'The home team'
          ? const Color(0xFFDEE9E4)
          : const Color(0xFFE3E5EF),
      shape: BoxShape.circle,
    ),
    child: Icon(
      name == 'The home team' ? CupertinoIcons.house : CupertinoIcons.person_2,
      size: size * .42,
      color: name == 'The home team'
          ? const Color(0xFF4B7064)
          : const Color(0xFF68738D),
    ),
  );
}
