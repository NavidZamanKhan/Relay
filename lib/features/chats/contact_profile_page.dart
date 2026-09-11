import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_avatar.dart';
import '../auth/models/user_profile.dart';
import '../auth/repositories/i_user_repository.dart';
import 'chat_bloc.dart';

class ContactProfilePage extends StatelessWidget {
  const ContactProfilePage({
    super.key,
    required this.name,
    required this.avatarAsset,
    required this.online,
    this.peerUid,
    this.about,
    this.phoneNumber,
  });

  final String name;
  final String? avatarAsset;
  final bool online;
  final String? peerUid;
  final String? about;
  final String? phoneNumber;

  @override
  Widget build(BuildContext context) {
    IUserRepository? userRepo;
    if (peerUid != null && peerUid!.isNotEmpty) {
      try {
        userRepo = context.read<IUserRepository>();
      } catch (_) {}
    }

    if (userRepo != null && peerUid != null && peerUid!.isNotEmpty) {
      return StreamBuilder<UserProfile?>(
        stream: userRepo.watchUserProfile(peerUid!),
        initialData: UserProfile(
          uid: peerUid!,
          phoneNumber: phoneNumber ?? '',
          displayName: name,
          about: about ?? '',
          publicKey: '',
          avatarUrl: avatarAsset,
          isOnline: online,
        ),
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final liveName = (profile?.displayName.trim().isNotEmpty == true)
              ? profile!.displayName.trim()
              : name;
          final liveAvatar = profile?.avatarUrl ?? avatarAsset;
          final liveOnline = profile?.isOnline ?? online;
          final liveAbout = (profile?.about.trim().isNotEmpty == true)
              ? profile!.about.trim()
              : (about?.trim().isNotEmpty == true
                  ? about!.trim()
                  : (liveName == 'Mom'
                      ? 'Call when you reach. Always.'
                      : 'Collecting quiet places and very loud memories.'));
          final livePhone = (profile?.phoneNumber.trim().isNotEmpty == true)
              ? profile!.phoneNumber.trim()
              : (phoneNumber?.trim().isNotEmpty == true
                  ? phoneNumber!.trim()
                  : '');

          return _buildScaffold(
            context,
            name: liveName,
            avatarAsset: liveAvatar,
            online: liveOnline,
            about: liveAbout,
            phoneNumber: livePhone,
          );
        },
      );
    }

    final fallbackAbout = (about?.trim().isNotEmpty == true)
        ? about!.trim()
        : (name == 'Mom'
            ? 'Call when you reach. Always.'
            : 'Collecting quiet places and very loud memories.');
    final fallbackPhone = (phoneNumber?.trim().isNotEmpty == true)
        ? phoneNumber!.trim()
        : '';

    return _buildScaffold(
      context,
      name: name,
      avatarAsset: avatarAsset,
      online: online,
      about: fallbackAbout,
      phoneNumber: fallbackPhone,
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required String name,
    required String? avatarAsset,
    required bool online,
    required String about,
    required String phoneNumber,
  }) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(CupertinoIcons.chevron_left, size: 23),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Center(
          child: RelayAvatar(name: name, asset: avatarAsset, size: 100),
        ),
        const SizedBox(height: 18),
        Text(
          name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Text(
          online ? 'Online' : 'Last seen recently',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: online ? RelayColors.mint : RelayColors.inkSoft,
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(CupertinoIcons.chat_bubble, size: 19),
            label: const Text('Message'),
          ),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ABOUT',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
              ),
              const SizedBox(height: 10),
              Text(
                about,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              if (phoneNumber.isNotEmpty) ...[
                const Divider(height: 30),
                Row(
                  children: [
                    const Icon(CupertinoIcons.phone, size: 18),
                    const SizedBox(width: 12),
                    Text(phoneNumber),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        BlocBuilder<ChatBloc, ChatState>(
          buildWhen: (a, b) => a.conversations != b.conversations,
          builder: (context, state) {
            final c = state.conversations.firstWhere(
              (c) => c.id == state.activeId,
            );
            return SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text(
                'Notifications',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              secondary: const Icon(CupertinoIcons.bell, size: 21),
              value: !c.muted,
              onChanged: (_) =>
                  context.read<ChatBloc>().add(const ChatMuteToggled()),
            );
          },
        ),
        const SizedBox(height: 24),
        Text('Shared moments', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (dialog) => Dialog(
              backgroundColor: Colors.transparent,
              child: Stack(
                children: [
                  InteractiveViewer(
                    child: Image.asset('assets/images/sylhet_evening.png'),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      tooltip: 'Close photo',
                      onPressed: () => Navigator.pop(dialog),
                      icon: const Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 1.8,
              child: Image.asset(
                'assets/images/sylhet_evening.png',
                fit: BoxFit.cover,
                cacheWidth: 1100,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
