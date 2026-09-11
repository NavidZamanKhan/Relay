import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_bloc.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_button.dart';
import '../../../core/widgets/relay_toast.dart';
import '../../chats/widgets/in_app_notification_banner.dart';

/// Screen managing push notifications, message previews, quiet hours,
/// and live device alert test triggers.
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _isRequestingPermission = false;

  Future<void> _requestSystemPermissions() async {
    setState(() => _isRequestingPermission = true);
    INotificationService? service;
    try {
      service = context.read<INotificationService>();
    } catch (_) {}

    final granted = await service?.requestPermissions() ?? false;
    if (mounted) {
      setState(() => _isRequestingPermission = false);
      RelayToast.show(
        context,
        message: granted
            ? 'Notification permissions enabled'
            : 'Permissions not granted in system settings',
        icon: granted
            ? CupertinoIcons.checkmark_circle_fill
            : CupertinoIcons.exclamationmark_circle,
      );
    }
  }

  void _sendTestNotification() {
    final appState = context.read<AppBloc>().state;
    final notificationsEnabled =
        appState.preferences['Message notifications'] ?? true;
    final previewsEnabled = appState.preferences['Message previews'] ?? true;
    final quietHours = appState.preferences['Quiet hours'] ?? false;

    if (!notificationsEnabled) {
      RelayToast.show(
        context,
        message: 'Enable message notifications to preview alerts',
        icon: CupertinoIcons.bell_slash,
      );
      return;
    }

    final testPayload = NotificationPayload(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: 'test_preview_chat',
      title: 'Aisha Chowdhury',
      body: previewsEnabled
          ? 'Hey! The new encrypted voice notes sound amazing.'
          : 'New message',
      timestamp: DateTime.now(),
    );

    // Trigger in-app floating banner
    InAppNotificationBanner.show(
      context,
      payload: testPayload,
      showPreview: previewsEnabled,
      onTap: () {
        RelayToast.show(
          context,
          message: 'Tapped notification for Aisha Chowdhury',
          icon: CupertinoIcons.chat_bubble_fill,
        );
      },
    );

    // Trigger local system notification if quiet hours is not enabled
    if (!quietHours) {
      try {
        final service = context.read<INotificationService>();
        service.showLocalNotification(
          payload: testPayload,
          showPreview: previewsEnabled,
        );
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
          'Notifications',
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
          _NotificationStatusCard(
            isDark: isDark,
            isRequesting: _isRequestingPermission,
            onRequestPermissions: _requestSystemPermissions,
          ),
          const SizedBox(height: 22),

          // Notification Preferences
          const _SectionHeader('Message Alerts'),
          const SizedBox(height: 8),
          _NotificationPreferencesGroup(appState: appState),
          const SizedBox(height: 22),

          // Live Test Trigger
          const _SectionHeader('Test & Verification'),
          const SizedBox(height: 8),
          _TestNotificationCard(
            onSendTest: _sendTestNotification,
          ),
          const SizedBox(height: 24),

          Center(
            child: Text(
              'Relay Push Engine: Firebase Cloud Messaging & Local Alerts (\$0)',
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

class _NotificationStatusCard extends StatelessWidget {
  const _NotificationStatusCard({
    required this.isDark,
    required this.isRequesting,
    required this.onRequestPermissions,
  });

  final bool isDark;
  final bool isRequesting;
  final VoidCallback onRequestPermissions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: RelayColors.blue.withValues(alpha: 0.35),
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
                  color: RelayColors.blue.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    CupertinoIcons.bell_fill,
                    color: RelayColors.blue,
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
                      'Real-time Message Alerts',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Stay in sync when new messages arrive',
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
          Text(
            'Relay delivers push notifications across iOS and Android with background wakes and foreground banners.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isRequesting ? null : onRequestPermissions,
              icon: isRequesting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(CupertinoIcons.check_mark_circled, size: 16),
              label: Text(
                isRequesting
                    ? 'Checking permissions...'
                    : 'Check system permissions',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationPreferencesGroup extends StatelessWidget {
  const _NotificationPreferencesGroup({required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final preferences = [
      ('Message notifications', 'Receive alerts for incoming messages'),
      ('Message previews', 'Show message content snippet in alert banners'),
      ('Quiet hours', 'Mute notification sounds and vibrations'),
    ];

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
            for (var i = 0; i < preferences.length; i++) ...[
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                title: Text(
                  preferences[i].$1,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  preferences[i].$2,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                value: appState.preferences[preferences[i].$1] ??
                    (preferences[i].$1 != 'Quiet hours'),
                activeThumbColor: RelayColors.coralDeep,
                onChanged: (v) => context.read<AppBloc>().add(
                      AppPreferenceChanged(preferences[i].$1, v),
                    ),
              ),
              if (i != preferences.length - 1)
                Divider(
                  height: 1,
                  indent: 14,
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

class _TestNotificationCard extends StatelessWidget {
  const _TestNotificationCard({required this.onSendTest});

  final VoidCallback onSendTest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                CupertinoIcons.paperplane_fill,
                color: RelayColors.coralDeep,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                'Send Test Notification',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Trigger an interactive mock message from Aisha Chowdhury to test the in-app drop banner and device notifications with your current preferences.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          RelayButton(
            label: 'Test alert banner',
            onPressed: onSendTest,
          ),
        ],
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
