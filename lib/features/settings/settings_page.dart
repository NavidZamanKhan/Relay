import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../app_bloc.dart';
import '../../core/motion/relay_motion.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_button.dart';
import '../auth/auth_bloc.dart';
import '../auth/profile_setup_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final appState = context.watch<AppBloc>().state;

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
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Appearance'),
          const SizedBox(height: 8),
          const _ThemeSelector(),
          const SizedBox(height: 20),
          const _SectionLabel('Your Relay'),
          const _SettingsGroup(
            children: [
              _SettingsTile(
                icon: CupertinoIcons.lock_shield,
                title: 'Privacy & security',
                subtitle: 'Last seen, blocked contacts, app lock',
              ),
              _SettingsTile(
                icon: CupertinoIcons.bell,
                title: 'Notifications',
                subtitle: 'Messages, previews, and quiet hours',
              ),
              _SettingsTile(
                icon: CupertinoIcons.chat_bubble_2,
                title: 'Chats',
                subtitle: 'Media and automatic downloads',
              ),
            ],
          ),
          const SizedBox(height: 17),
          const _SectionLabel('Storage'),
          _SettingsGroup(
            children: [
              const _SettingsTile(
                icon: CupertinoIcons.cloud_upload,
                title: 'Chat backup',
                subtitle: 'Keep a copy of your conversations',
              ),
              _SettingsTile(
                icon: CupertinoIcons.archivebox,
                title: 'Manage local cache',
                subtitle:
                    '${appState.cacheMb} MB · photos, voice notes, and documents',
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
              'Recent media stays nearby so conversations open instantly—even when your signal disappears.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 20),
            const _StorageBar(),
            const SizedBox(height: 20),
            RelayButton(
              label: 'Clear ${context.read<AppBloc>().state.cacheMb} MB',
              onPressed: () {
                context.read<AppBloc>().add(const AppCacheCleared());
                Navigator.pop(sheetContext);
              },
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
              'Your account and message history will be removed. This action can’t be undone.',
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
                  context.read<AuthBloc>().add(const AuthRestarted());
                  Navigator.of(context).popUntil((r) => r.isFirst);
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
  });

  final String initial;
  final String name;
  final String about;

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
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [RelayColors.coralWash, RelayColors.coral],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: RelayColors.ink,
                  ),
                ),
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
  const _StorageBar();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: const Row(
            children: [
              Expanded(
                flex: 5,
                child: ColoredBox(
                  color: RelayColors.coral,
                  child: SizedBox(height: 7),
                ),
              ),
              Expanded(
                flex: 2,
                child: ColoredBox(
                  color: Color(0xFF8C72FF),
                  child: SizedBox(height: 7),
                ),
              ),
              Expanded(
                flex: 1,
                child: ColoredBox(
                  color: RelayColors.blue,
                  child: SizedBox(height: 7),
                ),
              ),
              Expanded(
                flex: 4,
                child: ColoredBox(
                  color: RelayColors.line,
                  child: SizedBox(height: 7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        const Row(
          children: [
            _Legend(color: RelayColors.coral, label: 'Photos'),
            SizedBox(width: 15),
            _Legend(color: Color(0xFF8C72FF), label: 'Voice'),
            SizedBox(width: 15),
            _Legend(color: RelayColors.blue, label: 'Files'),
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
