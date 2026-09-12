import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_bloc.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/services/backup_service.dart';
import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_button.dart';
import '../../../core/widgets/relay_toast.dart';
import '../../auth/auth_bloc.dart';
import '../../chats/chat_bloc.dart';

class BackupSettingsPage extends StatefulWidget {
  const BackupSettingsPage({super.key});

  @override
  State<BackupSettingsPage> createState() => _BackupSettingsPageState();
}

class _BackupSettingsPageState extends State<BackupSettingsPage> {
  bool _isBackingUp = false;
  BackupMetadata? _latestBackup;

  @override
  void initState() {
    super.initState();
    _loadLatestBackup();
  }

  Future<void> _loadLatestBackup() async {
    final service = BackupService(
      cryptoService: context.read<CryptoService>(),
    );
    final backups = await service.listLocalBackups();
    if (mounted && backups.isNotEmpty) {
      setState(() {
        _latestBackup = backups.first;
      });
    }
  }

  Future<void> _performBackup() async {
    setState(() => _isBackingUp = true);
    final authState = context.read<AuthBloc>().state;
    final chatState = context.read<ChatBloc>().state;
    final uid = authState.userId ?? 'local_user';

    final service = BackupService(
      cryptoService: context.read<CryptoService>(),
    );

    try {
      final conversationsList = chatState.conversations.map((c) {
        return {
          'id': c.id,
          'name': c.name,
          'lastMessage': c.lastMessage,
          'lastMessageAt': c.lastMessageAt?.toIso8601String(),
          'unread': c.unread,
          'isGroup': c.isGroup,
        };
      }).toList();


      final totalMessages = chatState.messages.length;

      final metadata = await service.createEncryptedBackup(
        userId: uid,
        conversationsData: conversationsList,
        totalMessages: totalMessages,
      );

      if (!mounted) return;

      final formattedDate =
          '${metadata.timestamp.hour.toString().padLeft(2, '0')}:${metadata.timestamp.minute.toString().padLeft(2, '0')} · ${metadata.formattedSize}';

      context.read<AppBloc>().add(
            AppPreferenceChanged('Last backup timestamp', formattedDate),
          );

      setState(() {
        _isBackingUp = false;
        _latestBackup = metadata;
      });

      RelayToast.show(
        context,
        message: 'Encrypted backup created',
        icon: CupertinoIcons.checkmark_seal_fill,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBackingUp = false);
      RelayToast.show(
        context,
        message: 'Failed to create backup',
        icon: CupertinoIcons.exclamationmark_triangle,
      );
    }
  }

  Future<void> _exportBackupPayload() async {
    if (_latestBackup == null) {
      RelayToast.show(
        context,
        message: 'Create a backup first before exporting',
        icon: CupertinoIcons.info_circle,
      );
      return;
    }

    try {
      final file = _latestBackup!.filePath;
      Clipboard.setData(ClipboardData(text: file));
      RelayToast.show(
        context,
        message: 'Backup location copied to clipboard',
        icon: CupertinoIcons.doc_on_clipboard,
      );
    } catch (_) {
      RelayToast.show(
        context,
        message: 'Export failed',
        icon: CupertinoIcons.exclamationmark_triangle,
      );
    }
  }

  void _restoreBackupDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore Backup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your encrypted Relay backup ciphertext bundle below to restore conversation history.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText: '{"ciphertext":"...","nonce":"...","v":1}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final payload = controller.text.trim();
                if (payload.isEmpty) return;
                Navigator.pop(dialogContext);

                final service = BackupService(
                  cryptoService: context.read<CryptoService>(),
                );
                final uid =
                    context.read<AuthBloc>().state.userId ?? 'local_user';
                final restored =
                    await service.decryptBackupBundle(payload, uid);

                if (!mounted) return;

                if (restored != null) {
                  RelayToast.show(
                    context,
                    message:
                        'Restored ${restored['totalConversations'] ?? 0} conversations',
                    icon: CupertinoIcons.checkmark_seal_fill,
                  );
                } else {
                  RelayToast.show(
                    context,
                    message: 'Invalid or incompatible backup bundle',
                    icon: CupertinoIcons.exclamationmark_triangle,
                  );
                }
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
  }

  void _showFrequencyPicker(BuildContext context, String current) {
    final options = ['Daily', 'Weekly', 'Monthly'];
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
                'Backup Frequency',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how often automatic backups are generated in background.',
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
                          AppPreferenceChanged('Backup frequency', option),
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

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppBloc>().state;
    final lastBackup =
        appState.preferences['Last backup timestamp'] as String? ?? '';
    final autoBackup =
        appState.preferences['Automatic backups'] as bool? ?? false;
    final frequency =
        appState.preferences['Backup frequency'] as String? ?? 'Weekly';

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
          'Chat backup',
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
          // Header Status Card
          _StatusCard(
            lastBackup: lastBackup.isEmpty ? 'Never' : lastBackup,
            latestMetadata: _latestBackup,
          ),
          const SizedBox(height: 18),

          // Primary Backup Trigger
          RelayButton(
            label: _isBackingUp ? 'Creating encrypted backup...' : 'Back Up Now',
            icon: _isBackingUp ? null : CupertinoIcons.cloud_upload_fill,
            onPressed: _isBackingUp ? () {} : _performBackup,
          ),
          const SizedBox(height: 22),

          const _SectionHeader('Backup Actions'),
          const SizedBox(height: 8),
          _GroupCard(
            children: [
              _BackupTile(
                icon: CupertinoIcons.arrow_up_doc,
                title: 'Export Backup Location',
                subtitle: 'Copy device file path for offline archiving',
                onTap: _exportBackupPayload,
              ),
              _BackupTile(
                icon: CupertinoIcons.arrow_down_doc,
                title: 'Restore from Backup',
                subtitle: 'Import conversations from encrypted payload',
                onTap: _restoreBackupDialog,
              ),
            ],
          ),
          const SizedBox(height: 22),

          const _SectionHeader('Automation'),
          const SizedBox(height: 8),
          _GroupCard(
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                title: const Text(
                  'Automatic backups',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Periodically back up chats when device is idle and on Wi-Fi',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: autoBackup,
                activeThumbColor: RelayColors.coralDeep,
                onChanged: (v) => context.read<AppBloc>().add(
                      AppPreferenceChanged('Automatic backups', v),
                    ),
              ),
              _BackupTile(
                icon: CupertinoIcons.calendar,
                title: 'Frequency',
                subtitle: frequency,
                onTap: () => _showFrequencyPicker(context, frequency),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Center(
            child: Text(
              'Relay Vault Engine · Client-Side AES-GCM-256 (\$0)',
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

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.lastBackup,
    this.latestMetadata,
  });

  final String lastBackup;
  final BackupMetadata? latestMetadata;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: RelayColors.mint.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: RelayColors.mint.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.cloud_upload_fill,
                    color: RelayColors.mint,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Encrypted Chat Backup',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Curve25519 & AES-GCM-256 protected',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last backup:',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                lastBackup,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (latestMetadata != null) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Backup size:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  latestMetadata!.formattedSize,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
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

class _BackupTile extends StatelessWidget {
  const _BackupTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
          child: Icon(icon, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
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
