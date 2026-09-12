import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_bloc.dart';
import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_toast.dart';


class ChatSettingsPage extends StatelessWidget {
  const ChatSettingsPage({super.key});

  void _showMediaDownloadPicker({
    required BuildContext context,
    required String title,
    required String preferenceKey,
    required String currentValue,
  }) {
    final options = ['Never', 'Wi-Fi only', 'Wi-Fi and Cellular'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            24 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose when $title should download automatically.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (final option in options) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: currentValue == option
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: currentValue == option
                      ? const Icon(
                          CupertinoIcons.checkmark_alt,
                          color: RelayColors.coralDeep,
                        )
                      : null,
                  onTap: () {
                    context.read<AppBloc>().add(
                          AppPreferenceChanged(preferenceKey, option),
                        );
                    Navigator.pop(sheetContext);
                  },
                ),
                if (option != options.last)
                  Divider(height: 1, color: Theme.of(context).dividerColor),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showFontSizePicker(BuildContext context, String current) {
    final options = ['Small', 'Default', 'Large'];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            24 + MediaQuery.paddingOf(sheetContext).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat font size',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Adjust text scale across chat bubbles and previews.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              for (final option in options) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: current == option
                          ? FontWeight.w700
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: current == option
                      ? const Icon(
                          CupertinoIcons.checkmark_alt,
                          color: RelayColors.coralDeep,
                        )
                      : null,
                  onTap: () {
                    context.read<AppBloc>().add(
                          AppPreferenceChanged('Font size', option),
                        );
                    Navigator.pop(sheetContext);
                  },
                ),
                if (option != options.last)
                  Divider(height: 1, color: Theme.of(context).dividerColor),
              ],
            ],
          ),
        );
      },
    );
  }

  void _confirmClearMessages(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear All Messages?'),
          content: const Text(
            'This will delete cached message content across your local conversations. Conversation headers will remain.',
            style: TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: RelayColors.coralDeep,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                RelayToast.show(
                  context,
                  message: 'Local chat messages cleared',
                  icon: CupertinoIcons.checkmark_circle_fill,
                );
              },
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteChats(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete All Chats?'),
          content: const Text(
            'This will delete all conversations and message history from this device. Peer users will still have their message copies.',
            style: TextStyle(fontSize: 13.5, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: RelayColors.coralDeep,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                RelayToast.show(
                  context,
                  message: 'All chats deleted',
                  icon: CupertinoIcons.delete,
                );
              },
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppBloc>().state;
    final photosDl =
        appState.preferences['Auto-download photos'] as String? ??
            'Wi-Fi and Cellular';
    final audioDl =
        appState.preferences['Auto-download audio'] as String? ??
            'Wi-Fi and Cellular';
    final docsDl =
        appState.preferences['Auto-download documents'] as String? ??
            'Wi-Fi only';
    final savePhotos =
        appState.preferences['Save photos'] as bool? ?? false;
    final enterIsSend =
        appState.preferences['Enter is send'] as bool? ?? true;
    final fontSize =
        appState.preferences['Font size'] as String? ?? 'Default';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        leadingWidth: 48,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(CupertinoIcons.chevron_left, size: 23),
        ),
        titleSpacing: 2,
        title: Text(
          'Chats',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          const _SectionHeader('Media Auto-Download'),
          const SizedBox(height: 8),
          _GroupCard(
            children: [
              _ChatTile(
                icon: CupertinoIcons.photo,
                title: 'Photos',
                subtitle: photosDl,
                onTap: () => _showMediaDownloadPicker(
                  context: context,
                  title: 'Photos',
                  preferenceKey: 'Auto-download photos',
                  currentValue: photosDl,
                ),
              ),
              _ChatTile(
                icon: CupertinoIcons.mic,
                title: 'Voice notes',
                subtitle: audioDl,
                onTap: () => _showMediaDownloadPicker(
                  context: context,
                  title: 'Voice notes',
                  preferenceKey: 'Auto-download audio',
                  currentValue: audioDl,
                ),
              ),
              _ChatTile(
                icon: CupertinoIcons.doc,
                title: 'Documents',
                subtitle: docsDl,
                onTap: () => _showMediaDownloadPicker(
                  context: context,
                  title: 'Documents',
                  preferenceKey: 'Auto-download documents',
                  currentValue: docsDl,
                ),
              ),
              _ChatTile(
                icon: CupertinoIcons.arrow_counterclockwise,
                title: 'Reset auto-download settings',
                subtitle: 'Revert to network defaults',
                destructive: false,
                onTap: () {
                  context.read<AppBloc>().add(
                        const AppPreferenceChanged(
                          'Auto-download photos',
                          'Wi-Fi and Cellular',
                        ),
                      );
                  context.read<AppBloc>().add(
                        const AppPreferenceChanged(
                          'Auto-download audio',
                          'Wi-Fi and Cellular',
                        ),
                      );
                  context.read<AppBloc>().add(
                        const AppPreferenceChanged(
                          'Auto-download documents',
                          'Wi-Fi only',
                        ),
                      );
                  RelayToast.show(
                    context,
                    message: 'Auto-download settings reset',
                    icon: CupertinoIcons.checkmark_alt,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 22),

          const _SectionHeader('Media & Saving'),
          const SizedBox(height: 8),
          _GroupCard(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                title: const Text(
                  'Save to Photos',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Automatically save incoming photos to your device gallery',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: savePhotos,
                activeThumbColor: RelayColors.coralDeep,
                onChanged: (v) => context.read<AppBloc>().add(
                      AppPreferenceChanged('Save photos', v),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 22),

          const _SectionHeader('Chat Behavior'),
          const SizedBox(height: 8),
          _GroupCard(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                title: const Text(
                  'Enter is send',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Pressing the Enter key sends your message',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: enterIsSend,
                activeThumbColor: RelayColors.coralDeep,
                onChanged: (v) => context.read<AppBloc>().add(
                      AppPreferenceChanged('Enter is send', v),
                    ),
              ),
              _ChatTile(
                icon: CupertinoIcons.textformat_size,
                title: 'Font size',
                subtitle: fontSize,
                onTap: () => _showFontSizePicker(context, fontSize),
              ),
            ],
          ),
          const SizedBox(height: 22),

          const _SectionHeader('Chat History'),
          const SizedBox(height: 8),
          _GroupCard(
            children: [
              _ChatTile(
                icon: CupertinoIcons.clear,
                title: 'Clear all messages',
                subtitle: 'Keep conversations but clear messages',
                destructive: true,
                onTap: () => _confirmClearMessages(context),
              ),
              _ChatTile(
                icon: CupertinoIcons.delete,
                title: 'Delete all chats',
                subtitle: 'Permanently remove all conversations and history',
                destructive: true,
                onTap: () => _confirmDeleteChats(context),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Center(
            child: Text(
              'Relay Media Engine · Client-side Offline Persistence (\$0)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i != children.length - 1)
                Divider(
                  height: 1,
                  indent: 48,
                  endIndent: 14,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.75),
                ),
            ],
          ],
        ),
      ),
    );
  }
}


class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        minTileHeight: 60,
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        leading: SizedBox.square(
          dimension: 24,
          child: Icon(
            icon,
            size: 20,
            color: destructive ? RelayColors.coralDeep : null,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: destructive ? RelayColors.coralDeep : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5),
        ),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 14),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.05,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
