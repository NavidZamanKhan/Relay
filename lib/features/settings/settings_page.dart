import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_bloc.dart';
import '../../core/motion/relay_motion.dart';
import '../../core/services/cache_service.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_avatar.dart';
import '../../core/widgets/relay_button.dart';
import '../../core/widgets/relay_toast.dart';
import '../auth/auth_bloc.dart';
import '../auth/profile_setup_page.dart';
import 'views/backup_settings_page.dart';
import 'views/chat_settings_page.dart';
import 'views/notification_settings_page.dart';
import 'views/security_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.showBackButton = true});
  final bool showBackButton;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  void initState() {
    super.initState();
    _refreshCache();
  }

  Future<void> _refreshCache() async {
    final usage = await const CacheService().calculateCacheUsage();
    if (mounted) {
      context.read<AppBloc>().add(
            AppCacheUpdated(
              cacheMb: usage.totalMb,
              photosBytes: usage.photosBytes,
              voiceBytes: usage.voiceBytes,
              fileBytes: usage.fileBytes,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final appState = context.watch<AppBloc>().state;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 52,
        leadingWidth: widget.showBackButton ? 48 : 20,
        automaticallyImplyLeading: false,
        leading: widget.showBackButton
            ? IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(CupertinoIcons.chevron_left, size: 23),
              )
            : null,
        titleSpacing: 2,
        title: Text(
          'Settings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          5,
          16,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _ProfileRow(
            initial: auth.displayName.isEmpty
                ? 'N'
                : auth.displayName.characters.first.toUpperCase(),
            name: auth.displayName,
            about: auth.about,
            avatarUrl: auth.avatarUrl,
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Appearance'),
          const SizedBox(height: 8),
          const _ThemeSelector(),
          const SizedBox(height: 20),
          const _SectionLabel('Your Relay'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: CupertinoIcons.lock_shield,
                title: 'Privacy & security',
                subtitle: 'End-to-end encryption, key vault, and privacy',
                onTap: () => Navigator.of(context).push(
                  RelayMotion.route(const SecuritySettingsPage()),
                ),
              ),
              _SettingsTile(
                icon: CupertinoIcons.bell,
                title: 'Notifications',
                subtitle: 'Messages, previews, and quiet hours',
                onTap: () => Navigator.of(context).push(
                  RelayMotion.route(const NotificationSettingsPage()),
                ),
              ),
              _SettingsTile(
                icon: CupertinoIcons.chat_bubble_2,
                title: 'Chats',
                subtitle: 'Media and automatic downloads',
                onTap: () => Navigator.of(context).push(
                  RelayMotion.route(const ChatSettingsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const _SectionLabel('Storage'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: CupertinoIcons.cloud_upload,
                title: 'Chat backup',
                subtitle: 'Keep a copy of your conversations',
                onTap: () => Navigator.of(context).push(
                  RelayMotion.route(const BackupSettingsPage()),
                ),
              ),
              _SettingsTile(
                icon: CupertinoIcons.archivebox,
                title: 'Manage local cache',
                subtitle:
                    '${CacheUsage.formatBytes(appState.photosBytes + appState.voiceBytes + appState.fileBytes)} · photos, voice notes, and documents',
                onTap: () => _cacheSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 17),
          const _SectionLabel('Prototype'),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: CupertinoIcons.refresh,
                title: 'Replay onboarding',
                subtitle: 'Preview phone, OTP, and profile setup',
                onTap: () {
                  context.read<AuthBloc>().add(const AuthRestarted());
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
          const SizedBox(height: 17),
          _SettingsGroup(
            children: [
              _SettingsTile(
                icon: CupertinoIcons.delete,
                title: 'Delete account',
                subtitle: 'Permanently remove your Relay identity',
                destructive: true,
                onTap: () => _deleteSheet(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Relay · 0.3.0',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        ],
      ),
    );
  }


  void _cacheSheet(BuildContext context) {
    final appState = context.read<AppBloc>().state;
    final totalBytes =
        appState.photosBytes + appState.voiceBytes + appState.fileBytes;
    final formattedTotal = CacheUsage.formatBytes(totalBytes);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local cache',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            Text(
              'Recent media stays nearby so conversations open instantly - even when your signal disappears.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 20),
            _StorageBar(
              photosBytes: appState.photosBytes,
              voiceBytes: appState.voiceBytes,
              fileBytes: appState.fileBytes,
            ),
            const SizedBox(height: 20),
            RelayButton(
              label: totalBytes > 0 ? 'Clear $formattedTotal' : 'Cache is empty',
              onPressed: totalBytes > 0
                  ? () async {
                      await const CacheService().purgeLocalCache();
                      if (context.mounted) {
                        context.read<AppBloc>().add(const AppCacheCleared());
                        Navigator.pop(sheetContext);
                        RelayToast.show(
                          context,
                          message: 'Local cache cleared',
                          icon: CupertinoIcons.checkmark_circle_fill,
                        );
                      }
                    }
                  : () => Navigator.pop(sheetContext),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              CupertinoIcons.delete,
              color: RelayColors.coralDeep,
              size: 25,
            ),
            const SizedBox(height: 13),
            Text(
              'Delete your Relay?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            Text(
              'Your account, cryptographic identity, and cloud records will be permanently erased. This action cannot be undone.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 20),
            RelayButton(
              label: 'Keep my account',
              onPressed: () => Navigator.pop(sheetContext),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  final bloc = context.read<AuthBloc>();
                  Navigator.pop(sheetContext);
                  bloc.add(const AuthAccountDeleted());
                },
                child: const Text(
                  'Delete permanently',
                  style: TextStyle(color: RelayColors.coralDeep),
                ),
              ),

            ),
          ],
        ),
      ),
    );
  }

}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.initial,
    required this.name,
    required this.about,
    this.avatarUrl,
  });

  final String initial;
  final String name;
  final String about;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () => Navigator.of(
          context,
        ).push(RelayMotion.route(const ProfileSetupPage(editing: true))),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              RelayAvatar(
                name: name.isEmpty ? initial : name,
                asset: avatarUrl,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(
                      about,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(CupertinoIcons.chevron_right, size: 15),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      buildWhen: (a, b) => a.themeMode != b.themeMode,
      builder: (context, state) {
        return Container(
          height: 44,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).colorScheme.surface,
          ),
          child: Row(
            children: [
              _ThemeChoice(
                label: 'System',
                icon: CupertinoIcons.device_phone_portrait,
                value: ThemeMode.system,
                selected: state.themeMode == ThemeMode.system,
              ),
              _ThemeChoice(
                label: 'Light',
                icon: CupertinoIcons.sun_max,
                value: ThemeMode.light,
                selected: state.themeMode == ThemeMode.light,
              ),
              _ThemeChoice(
                label: 'Dark',
                icon: CupertinoIcons.moon,
                value: ThemeMode.dark,
                selected: state.themeMode == ThemeMode.dark,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.label,
    required this.icon,
    required this.value,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final ThemeMode value;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBackground = isDark ? RelayColors.coral : RelayColors.ink;
    final selectedForeground = isDark ? RelayColors.ink : RelayColors.paper;

    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<AppBloc>().add(AppThemeChanged(value)),
        child: AnimatedContainer(
          height: double.infinity,
          duration: RelayMotion.quick,
          curve: RelayMotion.enter,
          decoration: BoxDecoration(
            color: selected ? selectedBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? selectedForeground : null),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? selectedForeground : null,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 3),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(letterSpacing: 1.05),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).dividerColor.withValues(alpha: .75),
              ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        minTileHeight: 60,
        onTap:
            onTap ??
            () => Navigator.of(
              context,
            ).push(RelayMotion.route(_PreferencesPage(title: title))),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13),
        leading: SizedBox.square(
          dimension: 23,
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

class _StorageBar extends StatelessWidget {
  const _StorageBar({
    this.photosBytes = 0,
    this.voiceBytes = 0,
    this.fileBytes = 0,
  });

  final int photosBytes;
  final int voiceBytes;
  final int fileBytes;

  @override
  Widget build(BuildContext context) {
    final total = photosBytes + voiceBytes + fileBytes;
    final photosFlex =
        total > 0 ? ((photosBytes / total) * 100).round().clamp(1, 100) : 0;
    final voiceFlex =
        total > 0 ? ((voiceBytes / total) * 100).round().clamp(1, 100) : 0;
    final fileFlex =
        total > 0 ? ((fileBytes / total) * 100).round().clamp(1, 100) : 0;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 7,
            child: total == 0
                ? const ColoredBox(color: RelayColors.line)
                : Row(
                    children: [
                      if (photosFlex > 0)
                        Expanded(
                          flex: photosFlex,
                          child: const ColoredBox(color: RelayColors.coral),
                        ),
                      if (voiceFlex > 0)
                        Expanded(
                          flex: voiceFlex,
                          child: const ColoredBox(color: Color(0xFF8C72FF)),
                        ),
                      if (fileFlex > 0)
                        Expanded(
                          flex: fileFlex,
                          child: const ColoredBox(color: RelayColors.blue),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 11),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _Legend(
              color: RelayColors.coral,
              label: 'Photos · ${CacheUsage.formatBytes(photosBytes)}',
            ),
            _Legend(
              color: const Color(0xFF8C72FF),
              label: 'Voice · ${CacheUsage.formatBytes(voiceBytes)}',
            ),
            _Legend(
              color: RelayColors.blue,
              label: 'Files · ${CacheUsage.formatBytes(fileBytes)}',
            ),
          ],
        ),
      ],
    );
  }
}


class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _PreferencesPage extends StatelessWidget {
  const _PreferencesPage({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final keys = switch (title) {
      'Privacy & security' => ['Last seen', 'Read receipts', 'App lock'],
      'Notifications' => [
        'Message notifications',
        'Message previews',
        'Quiet hours',
      ],
      'Chats' => ['Save photos', 'Download on Wi-Fi'],
      _ => <String>[],
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (keys.isEmpty) ...[
              const SizedBox(height: 30),
              const Icon(CupertinoIcons.cloud_upload, size: 48),
              const SizedBox(height: 22),
              Text(
                'Your conversations, kept close.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              const Text(
                'Choose when to back up your messages and media.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              const ListTile(
                title: Text('Last backup'),
                trailing: Text('Never'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Automatic backups'),
                value: state.preferences['Automatic backups'] ?? false,
                onChanged: (v) => context.read<AppBloc>().add(
                  AppPreferenceChanged('Automatic backups', v),
                ),
              ),
            ],
            for (final key in keys)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  key,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: state.preferences[key] ?? false,
                activeThumbColor: RelayColors.coralDeep,
                onChanged: (v) =>
                    context.read<AppBloc>().add(AppPreferenceChanged(key, v)),
              ),
          ],
        ),
      ),
    );
  }
}
