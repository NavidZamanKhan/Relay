import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app_bloc.dart';
import '../../../core/crypto/crypto_service.dart';
import '../../../core/theme/relay_colors.dart';
import '../../../core/widgets/relay_button.dart';
import '../../../core/widgets/relay_toast.dart';
import '../../auth/auth_bloc.dart';

/// Screen displaying end-to-end encryption status, identity key fingerprint,
/// key vault backup and restore controls, and privacy preferences.
class SecuritySettingsPage extends StatelessWidget {
  const SecuritySettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final publicKey = authState.publicKey ?? '';
    final fingerprint = CryptoService.formatKeyFingerprint(publicKey);

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
          'Privacy & security',
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
          // E2EE Status Card
          _SecurityStatusCard(isDark: isDark),
          const SizedBox(height: 22),

          // Identity Key Fingerprint Section
          const _SectionHeader('Cryptographic Identity'),
          const SizedBox(height: 8),
          _IdentityKeyCard(
            fingerprint: fingerprint,
            rawPublicKey: publicKey,
            isDark: isDark,
          ),
          const SizedBox(height: 22),

          // Key Vault & Recovery Section
          const _SectionHeader('Key Vault & Recovery'),
          const SizedBox(height: 8),
          _KeyVaultGroup(
            authState: authState,
            isDark: isDark,
          ),
          const SizedBox(height: 22),

          // Privacy Preferences Section
          const _SectionHeader('Privacy Preferences'),
          const SizedBox(height: 8),
          const _PrivacyPreferencesGroup(),
          const SizedBox(height: 24),

          Center(
            child: Text(
              'Relay Security Architecture: Curve25519 and AES-GCM-256',
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

class _SecurityStatusCard extends StatelessWidget {
  const _SecurityStatusCard({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                    CupertinoIcons.shield_fill,
                    color: RelayColors.mint,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'End-to-End Encrypted',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: RelayColors.mint.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: RelayColors.mint,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'X25519 ECDH + AES-GCM-256',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Messages, voice notes, and media attachments are secured before leaving your device. Only you and your conversation peers hold the decryption keys.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityKeyCard extends StatelessWidget {
  const _IdentityKeyCard({
    required this.fingerprint,
    required this.rawPublicKey,
    required this.isDark,
  });

  final String fingerprint;
  final String rawPublicKey;
  final bool isDark;

  void _copyFingerprint(BuildContext context) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: fingerprint));
    RelayToast.show(
      context,
      message: 'Key fingerprint copied to clipboard',
      icon: CupertinoIcons.doc_on_clipboard,
    );
  }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Public Key Fingerprint',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
                tooltip: 'Copy Fingerprint',
                icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 17),
                onPressed: () => _copyFingerprint(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              fingerprint,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This 16-character hex fingerprint uniquely identifies your current Curve25519 identity key on the Relay network.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyVaultGroup extends StatelessWidget {
  const _KeyVaultGroup({
    required this.authState,
    required this.isDark,
  });

  final AuthState authState;
  final bool isDark;

  Future<void> _exportVault(BuildContext context) async {
    final uid = authState.userId ?? 'local_user';
    CryptoService? crypto;
    try {
      crypto = context.read<CryptoService>();
    } catch (_) {
      crypto = CryptoService();
    }

    try {
      final vaultJson = await crypto.exportEncryptedKeyVault(uid);
      if (!context.mounted) return;
      _showExportModal(context, vaultJson);
    } catch (e) {
      if (!context.mounted) return;
      RelayToast.show(
        context,
        message: 'Failed to export key vault',
        icon: CupertinoIcons.exclamationmark_triangle,
      );
    }
  }

  void _showExportModal(BuildContext context, String vaultJson) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
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
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.lock_shield,
                    color: RelayColors.mint,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Encrypted Key Vault',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'This bundle contains your X25519 private key, encrypted with an account-bound salt and AES-GCM-256. It can only be restored with your account credentials.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Text(
                  vaultJson,
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RelayButton(
                label: 'Copy Vault Bundle',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: vaultJson));
                  HapticFeedback.lightImpact();
                  Navigator.pop(sheetContext);
                  RelayToast.show(
                    context,
                    message: 'Encrypted vault bundle copied',
                    icon: CupertinoIcons.doc_on_clipboard,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _restoreVault(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Restore Key Vault'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Paste your encrypted key vault JSON payload below to restore your cryptographic identity.',
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
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                Navigator.pop(dialogContext);
                try {
                  context.read<AuthBloc>().add(AuthKeyVaultRestored(text));
                  RelayToast.show(
                    context,
                    message: 'Key vault restored successfully',
                    icon: CupertinoIcons.checkmark_shield_fill,
                  );
                } catch (_) {
                  RelayToast.show(
                    context,
                    message: 'Failed to restore vault: invalid payload',
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

  void _confirmKeyRegeneration(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Regenerate Keys?'),
          content: const Text(
            'Generating a new keypair will replace your existing X25519 identity key. Existing messages that were encrypted with the prior key will no longer be decipherable on this device.\n\nOnly proceed if you suspect your private key has been compromised.',
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
                context.read<AuthBloc>().add(const AuthKeyRegenerated());
                RelayToast.show(
                  context,
                  message: 'New X25519 keypair generated',
                  icon: CupertinoIcons.checkmark_shield_fill,
                );
              },
              child: const Text('Regenerate'),
            ),
          ],
        );
      },
    );
  }

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
            _VaultTile(
              icon: CupertinoIcons.arrow_up_doc,
              title: 'Export Encrypted Vault',
              subtitle: 'Create an encrypted backup of your private key',
              onTap: () => _exportVault(context),
            ),
            Divider(
              height: 1,
              indent: 48,
              endIndent: 14,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.75),
            ),
            _VaultTile(
              icon: CupertinoIcons.arrow_down_doc,
              title: 'Restore Key Vault',
              subtitle: 'Import a saved encrypted key vault bundle',
              onTap: () => _restoreVault(context),
            ),
            Divider(
              height: 1,
              indent: 48,
              endIndent: 14,
              color: Theme.of(context).dividerColor.withValues(alpha: 0.75),
            ),
            _VaultTile(
              icon: CupertinoIcons.arrow_2_circlepath,
              title: 'Regenerate Encryption Keys',
              subtitle: 'Generate a new X25519 keypair',
              destructive: true,
              onTap: () => _confirmKeyRegeneration(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultTile extends StatelessWidget {
  const _VaultTile({
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

class _PrivacyPreferencesGroup extends StatelessWidget {
  const _PrivacyPreferencesGroup();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppBloc, AppState>(
      builder: (context, state) {
        final preferences = ['Last seen', 'Read receipts', 'App lock'];
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  title: Text(
                    preferences[i],
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: state.preferences[preferences[i]] ?? true,
                  activeThumbColor: RelayColors.coralDeep,
                  onChanged: (v) => context.read<AppBloc>().add(
                        AppPreferenceChanged(preferences[i], v),
                      ),
                ),
                if (i != preferences.length - 1)
                  Divider(
                    height: 1,
                    indent: 14,
                    endIndent: 14,
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.75),
                  ),
              ],
            ],
          ),
        ),
      );
      },
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
