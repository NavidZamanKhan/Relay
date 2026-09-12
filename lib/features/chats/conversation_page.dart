import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_bloc.dart';
import '../../core/motion/relay_motion.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_avatar.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';
import 'contact_profile_page.dart';
import 'views/group_details_page.dart';
import 'relay_message_list.dart';
import 'message_composer.dart';
import 'signal_background.dart';
import 'widgets/connectivity_status_pill.dart';

import '../auth/models/user_profile.dart';
import '../auth/repositories/i_user_repository.dart';

class ConversationPage extends StatelessWidget {
  const ConversationPage({
    super.key,
    required this.contactId,
    required this.contactName,
    this.avatarAsset,
    this.online = true,
    this.recipientId,
    this.showBackButton = true,
  });

  static void open(BuildContext context, Conversation chat) {
    final readReceipts =
        context.read<AppBloc>().state.preferences['Read receipts'] as bool? ??
            true;
    openWith(
      Navigator.of(context),
      context.read<ChatBloc>(),
      chat,
      markAsRead: readReceipts,
    );
  }


  static void openWith(
    NavigatorState navigator,
    ChatBloc bloc,
    Conversation chat, {
    bool markAsRead = true,
  }) {
    bloc.add(ChatOpened(chat.id, markAsRead: markAsRead));

    navigator.push<void>(
      RelayMotion.route(
        ConversationPage(
          contactId: chat.id,
          contactName: chat.name,
          avatarAsset: chat.avatarAsset,
          online: chat.online,
          recipientId: chat.recipientId,
        ),
      ),
    ).then((_) {
      bloc.add(ChatClosed(chat.id));
    });
  }

  final String contactId;
  final String contactName;
  final String? avatarAsset;
  final bool online;
  final String? recipientId;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: showBackButton,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<ChatBloc>().add(ChatClosed(contactId));
        }
      },
      child: Scaffold(
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
                  recipientId: recipientId,
                  showBackButton: showBackButton,
                ),
                const ConnectivityStatusPill(),
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
    this.recipientId,
    this.showBackButton = true,
  });

  final String contactId;
  final String contactName;
  final String? avatarAsset;
  final bool online;
  final String? recipientId;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    IUserRepository? userRepo;
    try {
      userRepo = context.read<IUserRepository>();
    } catch (_) {}

    final currentUserId = context.read<ChatBloc>().currentUserId;
    final effectivePeerUid = recipientId ??
        (contactId.startsWith('chat_')
            ? contactId
                .replaceFirst('chat_', '')
                .split('_')
                .where((id) => id != currentUserId)
                .firstOrNull
            : null);

    if (userRepo != null &&
        effectivePeerUid != null &&
        effectivePeerUid.isNotEmpty) {
      return StreamBuilder<UserProfile?>(
        stream: userRepo.watchUserProfile(effectivePeerUid),
        initialData: UserProfile(
          uid: effectivePeerUid,
          phoneNumber: '',
          displayName: contactName,
          about: '',
          publicKey: '',
          avatarUrl: avatarAsset,
          isOnline: online,
        ),
        builder: (context, snapshot) {
          final liveOnline = snapshot.data?.isOnline ?? online;
          final liveName =
              (snapshot.data?.displayName.trim().isNotEmpty == true)
                  ? snapshot.data!.displayName.trim()
                  : contactName;
          final liveAvatar = snapshot.data?.avatarUrl ?? avatarAsset;
          return _buildBar(
            context,
            displayName: liveName,
            isOnline: liveOnline,
            avatar: liveAvatar,
            peerUid: effectivePeerUid,
            about: snapshot.data?.about,
            phoneNumber: snapshot.data?.phoneNumber,
          );
        },
      );
    }

    return _buildBar(
      context,
      displayName: contactName,
      isOnline: online,
      avatar: avatarAsset,
      peerUid: effectivePeerUid,
    );
  }

  Widget _buildBar(
    BuildContext context, {
    required String displayName,
    required bool isOnline,
    String? avatar,
    String? peerUid,
    String? about,
    String? phoneNumber,
  }) {
    final activeConv = context
        .read<ChatBloc>()
        .state
        .conversations
        .where((c) => c.id == contactId)
        .firstOrNull;
    final isGroup = contactId.startsWith('group_') || (activeConv?.isGroup ?? false);

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
          if (showBackButton)
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(CupertinoIcons.chevron_left, size: 23),
              tooltip: 'Back',
            )
          else
            const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (isGroup) {
                  GroupDetailsPage.open(context, contactId);
                } else {
                  Navigator.of(context).push(
                    RelayMotion.route(
                      ContactProfilePage(
                        name: displayName,
                        avatarAsset: avatar ?? avatarAsset,
                        online: isOnline,
                        peerUid: peerUid,
                        about: about,
                        phoneNumber: phoneNumber,
                      ),
                    ),
                  );
                }
              },
              child: Row(
                children: [
                  RelayAvatar(
                    name: displayName,
                    asset: avatar ?? avatarAsset,
                    online: false,
                    size: 40,
                    heroTag: isGroup ? null : 'avatar-$contactId',
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 1),
                        BlocSelector<ChatBloc, ChatState, (bool, int)>(
                          selector: (state) {
                            final c = state.conversations
                                .where((conv) => conv.id == contactId)
                                .firstOrNull;
                            return (state.typing, c?.memberCount ?? 0);
                          },
                          builder: (context, data) {
                            final typing = data.$1;
                            final count = data.$2;
                            final String subtitleText;
                            if (typing) {
                              subtitleText = 'typing…';
                            } else if (isGroup) {
                              subtitleText =
                                  count > 0 ? '$count members' : 'Group';
                            } else {
                              subtitleText =
                                  isOnline ? 'Online' : 'Last seen recently';
                            }
                            return AnimatedSwitcher(
                              duration: RelayMotion.quick,
                              child: Text(
                                subtitleText,
                                key: ValueKey(subtitleText),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: typing || (isOnline && !isGroup)
                                          ? RelayColors.mint
                                          : Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => _menu(
              context,
              displayName: displayName,
              avatar: avatar ?? avatarAsset,
              isOnline: isOnline,
              peerUid: peerUid,
              about: about,
              phoneNumber: phoneNumber,
              isGroup: isGroup,
            ),
            icon: const Icon(CupertinoIcons.ellipsis, size: 22),
            tooltip: 'Conversation options',
          ),
        ],
      ),
    );
  }

  void _menu(
    BuildContext context, {
    required String displayName,
    required String? avatar,
    required bool isOnline,
    String? peerUid,
    String? about,
    String? phoneNumber,
    required bool isGroup,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MenuTile(
              icon: isGroup ? CupertinoIcons.info : CupertinoIcons.person,
              label: isGroup ? 'Group info' : 'View profile',
              onTap: () {
                Navigator.pop(sheetContext);
                if (isGroup) {
                  GroupDetailsPage.open(context, contactId);
                } else {
                  Navigator.of(context).push(
                    RelayMotion.route(
                      ContactProfilePage(
                        name: displayName,
                        avatarAsset: avatar,
                        online: isOnline,
                        peerUid: peerUid,
                        about: about,
                        phoneNumber: phoneNumber,
                      ),
                    ),
                  );
                }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 18, top: 2, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(minWidth: 64, minHeight: 38),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: .65),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [_Dot(delay: 0), _Dot(delay: 140), _Dot(delay: 280)],
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
  late final Animation<double> _scale;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _opacity = Tween<double>(begin: .32, end: 1.0).animate(curve);
    _scale = Tween<double>(begin: .84, end: 1.16).animate(curve);
    if (widget.delay == 0) {
      _controller.repeat(reverse: true);
    } else {
      _delayTimer = Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) _controller.repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: 7.5,
          height: 7.5,
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          decoration: const BoxDecoration(
            color: RelayColors.coral,
            shape: BoxShape.circle,
          ),
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
