import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_avatar.dart';
import 'chat_bloc.dart';

class ContactProfilePage extends StatelessWidget {
  const ContactProfilePage({
    super.key,
    required this.name,
    required this.avatarAsset,
    required this.online,
  });
  final String name;
  final String? avatarAsset;
  final bool online;
  @override
  Widget build(BuildContext context) => Scaffold(
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
                name == 'Mom'
                    ? 'Call when you reach. Always.'
                    : 'Collecting quiet places and very loud memories.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
              const Divider(height: 30),
              const Row(
                children: [
                  Icon(CupertinoIcons.phone, size: 18),
                  SizedBox(width: 12),
                  Text('+880 17•• ••• ••42'),
                ],
              ),
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
