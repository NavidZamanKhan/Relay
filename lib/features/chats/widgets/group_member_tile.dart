import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_avatar.dart';
import '../../../core/widgets/relay_badge.dart';

/// Renders a single participant in the group details view with admin badge
/// and administrative action triggers.
class GroupMemberTile extends StatelessWidget {
  const GroupMemberTile({
    super.key,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.isAdmin,
    required this.isCurrentUser,
    required this.canManage,
    this.onPromote,
    this.onDemote,
    this.onRemove,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final bool isAdmin;
  final bool isCurrentUser;
  final bool canManage;
  final VoidCallback? onPromote;
  final VoidCallback? onDemote;
  final VoidCallback? onRemove;

  void _showMemberActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: RelayAvatar(
                  name: displayName,
                  asset: avatarUrl,
                  size: 40,
                ),
                title: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  isAdmin ? 'Group Admin' : 'Group Member',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
              const Divider(height: 16),
              if (!isAdmin)
                ListTile(
                  leading: const Icon(CupertinoIcons.shield_lefthalf_fill, color: RelayColors.mint),
                  title: const Text('Make Group Admin'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onPromote?.call();
                  },
                )
              else
                ListTile(
                  leading: const Icon(CupertinoIcons.shield_slash, color: RelayColors.coralDeep),
                  title: const Text('Dismiss as Admin'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    onDemote?.call();
                  },
                ),
              ListTile(
                leading: const Icon(CupertinoIcons.person_badge_minus, color: RelayColors.coralDeep),
                title: const Text(
                  'Remove from group',
                  style: TextStyle(color: RelayColors.coralDeep),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmRemove(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove from group'),
        content: Text('Are you sure you want to remove $displayName from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              onRemove?.call();
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: RelayColors.coralDeep, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          RelayAvatar(
            name: displayName,
            asset: avatarUrl,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(You)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (isAdmin)
                  const RelayBadge(
                    label: 'Admin',
                    icon: CupertinoIcons.shield_fill,
                    variant: RelayBadgeVariant.accent,
                  )
                else
                  Text(
                    'Member',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
              ],
            ),
          ),
          if (canManage)
            IconButton(
              icon: const Icon(CupertinoIcons.ellipsis, size: 20),
              tooltip: 'Manage member',
              onPressed: () => _showMemberActions(context),
            ),
        ],
      ),
    );
  }
}
