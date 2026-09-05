import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/motion/relay_motion.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_avatar.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';
import 'contact_profile_page.dart';
import 'relay_message_list.dart';
import 'message_composer.dart';
import 'signal_background.dart';

class ConversationPage extends StatelessWidget {
  const ConversationPage({
    super.key,
    this.contactId = 'aisha',
    this.contactName = 'Aisha',
    this.avatarAsset = 'assets/images/aisha.png',
    this.online = true,
  });

  static void open(BuildContext context, Conversation chat) =>
      openWith(Navigator.of(context), context.read<ChatBloc>(), chat);

  static void openWith(
    NavigatorState navigator,
    ChatBloc bloc,
    Conversation chat,
  ) {
    bloc.add(ChatOpened(chat.id));
    navigator.push<void>(
      RelayMotion.route(
        ConversationPage(
          contactId: chat.id,
          contactName: chat.name,
          avatarAsset: chat.avatarAsset,
          online: chat.online,
        ),
      ),
    );
  }

  final String contactId;
  final String contactName;
  final String? avatarAsset;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SignalBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _ConversationHeader(
                contactId: contactId,
                contactName: contactName,
                avatarAsset: avatarAsset,
                online: online,
              ),
              const Expanded(
                child: RelayMessageList(
                  dateHeader: _DatePill(),
                  typingIndicator: _TypingBubble(),
                ),
              ),
              MessageComposer(contactName: contactName),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({
    required this.contactId,
    required this.contactName,
    required this.avatarAsset,
    required this.online,
  });

  final String contactId;
  final String contactName;
  final String? avatarAsset;
  final bool online;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.fromLTRB(3, 4, 5, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: .96),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: .58),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(CupertinoIcons.chevron_left, size: 23),
            tooltip: 'Back',
          ),
          Hero(
            tag: 'avatar-$contactId',
            child: RelayAvatar(
              name: contactName,
              asset: avatarAsset,
              online: online,
              size: 40,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contactName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 1),
                BlocSelector<ChatBloc, ChatState, bool>(
                  selector: (state) => state.typing,
                  builder: (context, typing) => AnimatedSwitcher(
                    duration: RelayMotion.quick,
                    child: Text(
                      typing
                          ? 'typing…'
                          : (online ? 'Online' : 'Last seen recently'),
                      key: ValueKey(typing),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: typing || online
                            ? RelayColors.mint
                            : Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _menu(context),
            icon: const Icon(CupertinoIcons.ellipsis, size: 22),
            tooltip: 'Conversation options',
          ),
        ],
      ),
    );
  }

  void _menu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuTile(
              icon: CupertinoIcons.person,
              label: 'View profile',
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(context).push(
                  RelayMotion.route(
                    ContactProfilePage(
                      name: contactName,
                      avatarAsset: avatarAsset,
                      online: online,
                    ),
                  ),
                );
              },
            ),
            _MenuTile(
              icon: CupertinoIcons.bell_slash,
              label:
                  context
                      .read<ChatBloc>()
                      .state
                      .conversations
                      .firstWhere((c) => c.id == contactId)
                      .muted
                  ? 'Unmute notifications'
                  : 'Mute notifications',
              onTap: () {
                Navigator.pop(sheetContext);
                context.read<ChatBloc>().add(const ChatMuteToggled());
              },
            ),
            _MenuTile(
              icon: CupertinoIcons.search,
              label: 'Search conversation',
              onTap: () {
                Navigator.pop(sheetContext);
                showSearch<String?>(
                  context: context,
                  delegate: _ConversationSearchDelegate(),
                );
              },
            ),
            _MenuTile(
              icon: CupertinoIcons.delete,
              label: 'Clear chat',
              destructive: true,
              onTap: () {
                Navigator.pop(sheetContext);
                showDialog<void>(
                  context: context,
                  builder: (dialog) => AlertDialog(
                    title: const Text('Clear this conversation?'),
                    content: const Text(
                      'Messages will be removed from this device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          context.read<ChatBloc>().add(
                            const ChatHistoryCleared(),
                          );
                          Navigator.pop(dialog);
                        },
                        child: const Text('Clear chat'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationSearchDelegate extends SearchDelegate<String?> {
  @override
  String get searchFieldLabel => 'Search this conversation';

  @override
  List<Widget>? buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        onPressed: () => query = '',
        icon: const Icon(CupertinoIcons.clear, size: 20),
      ),
  ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(
    onPressed: () => close(context, null),
    icon: const Icon(CupertinoIcons.chevron_left, size: 22),
  );

  @override
  Widget buildResults(BuildContext context) => _results(context);

  @override
  Widget buildSuggestions(BuildContext context) => _results(context);

  Widget _results(BuildContext context) {
    final matches = context
        .read<ChatBloc>()
        .state
        .messages
        .where(
          (message) =>
              (message.text ?? '').toLowerCase().contains(query.toLowerCase()),
        )
        .toList(growable: false);
    if (query.isEmpty) {
      return const Center(child: Text('Search words, links, and captions'));
    }
    if (matches.isEmpty) {
      return const Center(child: Text('No matching messages'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(18),
      itemCount: matches.length,
      separatorBuilder: (_, _) => const Divider(),
      itemBuilder: (_, index) => ListTile(
        leading: const Icon(CupertinoIcons.chat_bubble, size: 20),
        title: Text(matches[index].text ?? ''),
        subtitle: const Text('Today'),
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: .88),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: .65),
          ),
        ),
        child: Text('Today', style: Theme.of(context).textTheme.labelSmall),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 18, top: 1, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: .65),
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(5),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [_Dot(delay: 0), _Dot(delay: 110), _Dot(delay: 220)],
        ),
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.delay});
  final int delay;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _opacity = Tween<double>(
      begin: .24,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    Future<void>.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          color: RelayColors.coral,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 54,
      onTap: onTap,
      leading: Icon(
        icon,
        size: 20,
        color: destructive ? RelayColors.mint : null,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: destructive ? RelayColors.mint : null,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
