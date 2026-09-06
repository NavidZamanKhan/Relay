import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/relay_colors.dart';
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
          if (widget.editing && state.step == AuthStep.complete && !state.isVerifying) {
            Navigator.pop(context);
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: () => _avatarSheet(context),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [RelayColors.coralWash, RelayColors.coral],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _name.text.trim().isNotEmpty
                                ? _name.text.trim().substring(0, 1).toUpperCase()
                                : 'R',
                            style: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              color: RelayColors.ink,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: 2,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: RelayColors.ink,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            CupertinoIcons.camera,
                            color: RelayColors.paper,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _name,
                builder: (context, value, _) => TextField(
                  controller: _name,
                  maxLength: 32,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Display name',
                    counterText: '${value.text.characters.length}/32',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _about,
                maxLength: 90,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'About',
                  alignLabelWithHint: true,
                ),
              ),
              if (state.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  state.errorMessage!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: RelayColors.coralDeep),
                ),
              ],
              const SizedBox(height: 24),
              RelayButton(
                label: state.isVerifying
                    ? 'Saving profile…'
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

  void _avatarSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 34),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add your photo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 18),
            _MediaChoice(
              icon: CupertinoIcons.camera,
              label: 'Take a photo',
              onTap: () => Navigator.pop(context),
            ),
            _MediaChoice(
              icon: CupertinoIcons.photo,
              label: 'Choose from gallery',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaChoice extends StatelessWidget {
  const _MediaChoice({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: RelayColors.coral.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: RelayColors.coralDeep),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(CupertinoIcons.chevron_right, size: 15),
    );
  }
}
