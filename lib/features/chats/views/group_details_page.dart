import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/motion/relay_motion.dart';
import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_avatar.dart';
import '../../../core/widgets/relay_toast.dart';
import '../chat_bloc.dart';
import '../chat_models.dart';
import '../widgets/add_group_members_sheet.dart';
import '../widgets/group_member_tile.dart';

/// Full screen view for group details, member roster, and admin controls.
class GroupDetailsPage extends StatelessWidget {
  const GroupDetailsPage({
    super.key,
    required this.groupId,
  });

  final String groupId;

  static void open(BuildContext context, String groupId) {
    Navigator.of(context).push(
      RelayMotion.route(GroupDetailsPage(groupId: groupId)),
    );
  }

  void _editName(BuildContext context, Conversation conversation) {
    final controller = TextEditingController(text: conversation.name);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Change group name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter group name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != conversation.name) {
                context.read<ChatBloc>().add(
                  ChatGroupInfoUpdated(
                    groupId: conversation.id,
                    name: newName,
                  ),
                );
                RelayToast.show(context, message: 'Group name updated');
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _editDescription(BuildContext context, Conversation conversation) {
    final controller = TextEditingController(text: conversation.description ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Group description'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter group description',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newDesc = controller.text.trim();
              context.read<ChatBloc>().add(
                ChatGroupInfoUpdated(
                  groupId: conversation.id,
                  description: newDesc,
                ),
              );
              RelayToast.show(context, message: 'Group description updated');
              Navigator.pop(dialogContext);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _editAvatar(BuildContext context, Conversation conversation) {
    final controller = TextEditingController(text: conversation.avatarAsset ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Group avatar URL'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter image URL or asset path',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newUrl = controller.text.trim();
              context.read<ChatBloc>().add(
                ChatGroupInfoUpdated(
                  groupId: conversation.id,
                  avatarUrl: newUrl,
                ),
              );
              RelayToast.show(context, message: 'Group avatar updated');
              Navigator.pop(dialogContext);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, Conversation conversation, String currentUserId) {
    final isSoleAdmin = conversation.isAdmin(currentUserId) &&
        conversation.adminIds.length == 1 &&
        conversation.participantIds.length > 1;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave group'),
        content: Text(
          isSoleAdmin
              ? 'You are the only admin in this group. If you leave, another member will automatically be appointed as admin. Continue?'
              : 'Are you sure you want to leave this group? You will no longer receive messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.read<ChatBloc>().add(
                ChatGroupLeft(
                  groupId: conversation.id,
                  currentUserId: currentUserId,
                ),
              );
              Navigator.of(context).popUntil((route) => route.isFirst);
              RelayToast.show(context, message: 'Left group');
            },
            child: const Text(
              'Leave',
              style: TextStyle(color: RelayColors.coralDeep, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = context.read<ChatBloc>().currentUserId ?? 'current_user';

    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final conversation = state.conversations
            .where((c) => c.id == groupId)
            .firstOrNull;

        if (conversation == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Group Info')),
            body: const Center(child: Text('Group conversation not found')),
          );
        }

        final isAdmin = conversation.isAdmin(currentUserId);
        final members = conversation.participantIds;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Group Info'),
            centerTitle: true,
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // Header Card
              Center(
                child: Stack(
                  children: [
                    RelayAvatar(
                      name: conversation.name,
                      asset: conversation.avatarAsset,
                      size: 92,
                    ),
                    if (isAdmin)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: () => _editAvatar(context, conversation),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: RelayColors.mint,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.scaffoldBackgroundColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              CupertinoIcons.camera_fill,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // Group Title Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        conversation.name,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _editName(context, conversation),
                        child: const Icon(
                          CupertinoIcons.pencil,
                          size: 18,
                          color: RelayColors.mint,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${conversation.memberCount} members',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 12),
              // Group Description Row
              InkWell(
                onTap: isAdmin ? () => _editDescription(context, conversation) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(CupertinoIcons.info_circle, size: 20, color: RelayColors.mint),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          (conversation.description != null && conversation.description!.isNotEmpty)
                              ? conversation.description!
                              : (isAdmin ? 'Add group description' : 'No description provided'),
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: (conversation.description == null || conversation.description!.isEmpty)
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: (conversation.description == null || conversation.description!.isEmpty)
                                ? theme.textTheme.bodySmall?.color
                                : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      if (isAdmin)
                        const Icon(CupertinoIcons.chevron_right, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const Divider(height: 32),
              // Admin Actions Section: Add Members
              if (isAdmin) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: RelayColors.mint,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(CupertinoIcons.person_add_solid, size: 18, color: Colors.white),
                    ),
                    title: const Text(
                      'Add Members',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
                    onTap: () async {
                      final selected = await AddGroupMembersSheet.show(
                        context,
                        existingMemberIds: conversation.participantIds,
                      );
                      if (selected != null && selected.isNotEmpty && context.mounted) {
                        context.read<ChatBloc>().add(
                          ChatGroupMembersAdded(
                            groupId: conversation.id,
                            newMembers: selected,
                          ),
                        );
                        RelayToast.show(context, message: 'Added ${selected.length} member(s)');
                      }
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // Members Section Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  'MEMBERS (${conversation.memberCount})',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: theme.textTheme.bodySmall?.color,
                  ),
                ),
              ),
              // Members Roster
              for (final memberId in members) ...[
                GroupMemberTile(
                  userId: memberId,
                  displayName: conversation.participantNames?[memberId] ??
                      (memberId == currentUserId ? 'You' : memberId),
                  avatarUrl: conversation.participantAvatars?[memberId],
                  isAdmin: conversation.isAdmin(memberId),
                  isCurrentUser: memberId == currentUserId,
                  canManage: isAdmin && memberId != currentUserId,
                  onPromote: () {
                    context.read<ChatBloc>().add(
                      ChatGroupMemberPromoted(
                        groupId: conversation.id,
                        targetUserId: memberId,
                      ),
                    );
                    RelayToast.show(context, message: 'Appointed as admin');
                  },
                  onDemote: () {
                    context.read<ChatBloc>().add(
                      ChatGroupMemberDemoted(
                        groupId: conversation.id,
                        targetUserId: memberId,
                      ),
                    );
                    RelayToast.show(context, message: 'Dismissed as admin');
                  },
                  onRemove: () {
                    context.read<ChatBloc>().add(
                      ChatGroupMemberRemoved(
                        groupId: conversation.id,
                        targetUserId: memberId,
                      ),
                    );
                    RelayToast.show(context, message: 'Removed from group');
                  },
                ),
              ],
              const Divider(height: 32),
              // Leave Group Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ListTile(
                  leading: const Icon(
                    CupertinoIcons.square_arrow_right,
                    color: RelayColors.coralDeep,
                  ),
                  title: const Text(
                    'Leave group',
                    style: TextStyle(
                      color: RelayColors.coralDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () => _confirmLeave(context, conversation, currentUserId),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
