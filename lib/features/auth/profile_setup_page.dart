import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_avatar.dart';
import '../../core/widgets/relay_button.dart';
import 'auth_bloc.dart';
import 'auth_scaffold.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key, this.editing = false});
  final bool editing;

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  late final TextEditingController _name;
  late final TextEditingController _about;
  String? _pickedImagePath;
  bool _removeAvatar = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AuthBloc>().state;
    _name = TextEditingController(text: state.displayName);
    _about = TextEditingController(text: state.about);
  }

  @override
  void dispose() {
    _name.dispose();
    _about.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 82,
      );
      if (picked != null) {
        setState(() {
          _pickedImagePath = picked.path;
          _removeAvatar = false;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access camera or gallery.'),
          ),
        );
      }
    }
  }

  void _avatarSheet(BuildContext context, {required bool hasAvatar}) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Profile photo',
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you want to appear across Relay chats.',
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                      color: RelayColors.inkSoft,
                    ),
              ),
              const SizedBox(height: 18),
              _MediaChoice(
                icon: CupertinoIcons.camera,
                label: 'Take a photo',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              _MediaChoice(
                icon: CupertinoIcons.photo_on_rectangle,
                label: 'Choose from gallery',
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _pickImage(ImageSource.gallery);
                },
              ),
              if (hasAvatar) ...[
                const SizedBox(height: 8),
                _MediaChoice(
                  icon: CupertinoIcons.trash,
                  label: 'Remove photo',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    setState(() {
                      _pickedImagePath = null;
                      _removeAvatar = true;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      eyebrow: 'Make it yours',
      leading: widget.editing
          ? IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(CupertinoIcons.chevron_left),
            )
          : null,
      title: widget.editing ? 'Your profile.' : 'Make yourself at home.',
      subtitle: 'Keep it simple. You can change all of this later.',
      child: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (widget.editing &&
              state.step == AuthStep.complete &&
              !state.isVerifying) {
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          final effectiveAvatar = _pickedImagePath ??
              (_removeAvatar ? null : state.avatarUrl);
          final hasAvatar = effectiveAvatar != null && effectiveAvatar.isNotEmpty;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _avatarSheet(context, hasAvatar: hasAvatar),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  RelayColors.coralWash,
                                  RelayColors.coral,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: RelayColors.coral.withValues(alpha: 0.25),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: RelayAvatar(
                              name: _name.text.trim().isEmpty
                                  ? 'Relay'
                                  : _name.text.trim(),
                              asset: effectiveAvatar,
                              size: 96,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 2,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: RelayColors.ink,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                CupertinoIcons.camera_fill,
                                color: RelayColors.paper,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () =>
                          _avatarSheet(context, hasAvatar: hasAvatar),
                      icon: const Icon(CupertinoIcons.photo_camera, size: 16),
                      label: Text(
                        hasAvatar ? 'Change photo' : 'Add photo',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Grouped profile info card
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _name,
                        builder: (context, value, _) => TextField(
                          controller: _name,
                          maxLength: 32,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            icon: const Icon(
                              CupertinoIcons.person,
                              color: RelayColors.inkFaint,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            labelText: 'Display name',
                            counterText: '${value.text.characters.length}/32',
                          ),
                        ),
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: TextField(
                        controller: _about,
                        maxLength: 90,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          icon: Icon(
                            CupertinoIcons.quote_bubble,
                            color: RelayColors.inkFaint,
                            size: 20,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          labelText: 'About',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Verified phone badge card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: RelayColors.mint.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.phone,
                        color: RelayColors.mint,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.phone.isNotEmpty
                                ? state.phone
                                : 'Verified phone',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Phone number verified via SMS',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: RelayColors.inkSoft),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      CupertinoIcons.checkmark_seal_fill,
                      color: RelayColors.mint,
                      size: 20,
                    ),
                  ],
                ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  state.errorMessage!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: RelayColors.coralDeep),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 28),
              RelayButton(
                label: state.isVerifying
                    ? 'Saving profile...'
                    : (widget.editing ? 'Save profile' : 'Complete setup'),
                icon: state.isVerifying ? null : CupertinoIcons.check_mark,
                onPressed: state.isVerifying
                    ? () {}
                    : () {
                        if (_name.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Add a display name to continue.'),
                            ),
                          );
                          return;
                        }
                        context.read<AuthBloc>().add(
                              AuthProfileUpdated(
                                name: _name.text.trim(),
                                about: _about.text.trim(),
                                avatarFilePath: _pickedImagePath,
                                removeAvatar: _removeAvatar,
                              ),
                            );
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MediaChoice extends StatelessWidget {
  const _MediaChoice({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? RelayColors.coralDeep
        : Theme.of(context).colorScheme.onSurface;
    final bg = isDestructive
        ? RelayColors.coral.withValues(alpha: 0.12)
        : RelayColors.porcelain;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color:
                      isDestructive ? RelayColors.coralDeep : RelayColors.ink,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: Theme.of(context).dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
