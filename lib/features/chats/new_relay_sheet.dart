import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/relay_colors.dart';
import '../../core/widgets/relay_avatar.dart';
import '../../core/widgets/relay_button.dart';
import 'chat_bloc.dart';
import 'chat_models.dart';
import 'conversation_page.dart';

sealed class _ComposeEvent {
  const _ComposeEvent();
}

final class _Query extends _ComposeEvent {
  const _Query(this.value);
  final String value;
}

final class _Group extends _ComposeEvent {
  const _Group();
}

final class _Member extends _ComposeEvent {
  const _Member(this.id);
  final String id;
}

final class _Name extends _ComposeEvent {
  const _Name(this.name);
  final String name;
}

class _ComposeState extends Equatable {
  const _ComposeState({
    this.query = '',
    this.group = false,
    this.members = const {},
    this.name = '',
  });
  final String query, name;
  final bool group;
  final Set<String> members;
  @override
  List<Object?> get props => [query, name, group, members];
}

class _ComposeBloc extends Bloc<_ComposeEvent, _ComposeState> {
  _ComposeBloc() : super(const _ComposeState()) {
    on<_Query>(
      (e, emit) => emit(
        _ComposeState(
          query: e.value,
          group: state.group,
          members: state.members,
          name: state.name,
        ),
      ),
    );
    on<_Name>(
      (e, emit) => emit(
        _ComposeState(
          query: state.query,
          group: state.group,
          members: state.members,
          name: e.name,
        ),
      ),
    );
    on<_Group>(
      (e, emit) => emit(
        _ComposeState(
          query: state.query,
          group: !state.group,
          members: state.members,
          name: state.name,
        ),
      ),
    );
    on<_Member>((e, emit) {
      final members = {...state.members};
      if (!members.add(e.id)) members.remove(e.id);
      emit(
        _ComposeState(
          query: state.query,
          group: state.group,
          members: members,
          name: state.name,
        ),
      );
    });
  }
}

class NewRelaySheet extends StatelessWidget {
  const NewRelaySheet({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocProvider(create: (_) => _ComposeBloc(), child: const _NewRelayBody());
}

class _NewRelayBody extends StatelessWidget {
  const _NewRelayBody();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<_ComposeBloc, _ComposeState>(
    builder: (context, state) {
      final contacts = context
          .read<ChatBloc>()
          .state
          .conversations
          .where(
            (c) =>
                !c.isGroup &&
                c.name.toLowerCase().contains(state.query.toLowerCase()),
          )
          .toList();
      return SizedBox(
        height: MediaQuery.sizeOf(context).height * .76,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            0,
            22,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      state.group ? 'New group' : 'New relay',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(CupertinoIcons.xmark, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (!state.group)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => context.read<_ComposeBloc>().add(const _Group()),
                  leading: const CircleAvatar(
                    backgroundColor: RelayColors.coralWash,
                    child: Icon(
                      CupertinoIcons.person_2,
                      color: RelayColors.coralDeep,
                      size: 21,
                    ),
                  ),
                  title: const Text(
                    'New group',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Bring your people together'),
                  trailing: const Icon(CupertinoIcons.chevron_right, size: 16),
                )
              else
                TextField(
                  onChanged: (v) => context.read<_ComposeBloc>().add(_Name(v)),
                  maxLength: 40,
                  decoration: const InputDecoration(hintText: 'Group name'),
                ),
              const SizedBox(height: 14),
              TextField(
                onChanged: (v) => context.read<_ComposeBloc>().add(_Query(v)),
                decoration: const InputDecoration(
                  hintText: 'Search contacts',
                  prefixIcon: Icon(CupertinoIcons.search, size: 18),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                state.group
                    ? '${state.members.length} SELECTED'
                    : 'YOUR CONTACTS',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (_, i) {
                    final c = contacts[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        if (state.group) {
                          context.read<_ComposeBloc>().add(_Member(c.id));
                        } else {
                          final nav = Navigator.of(context);
                          final bloc = context.read<ChatBloc>();
                          nav.pop();
                          ConversationPage.openWith(nav, bloc, c);
                        }
                      },
                      leading: RelayAvatar(
                        name: c.name,
                        asset: c.avatarAsset,
                        size: 43,
                      ),
                      title: Text(
                        c.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        c.online ? 'Online' : 'On Relay',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: state.group
                          ? Icon(
                              state.members.contains(c.id)
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.circle,
                              color: state.members.contains(c.id)
                                  ? RelayColors.coralDeep
                                  : RelayColors.inkFaint,
                              size: 23,
                            )
                          : null,
                    );
                  },
                ),
              ),
              if (state.group)
                RelayButton(
                  label: 'Create group',
                  onPressed: state.name.trim().isEmpty || state.members.isEmpty
                      ? null
                      : () {
                          final id =
                              'group-${DateTime.now().microsecondsSinceEpoch}';
                          final c = Conversation(
                            id: id,
                            name: state.name.trim(),
                            avatarAsset: null,
                            lastMessage: '',
                            timeLabel: 'Now',
                            isGroup: true,
                          );
                          final bloc = context.read<ChatBloc>();
                          final nav = Navigator.of(context);
                          bloc.add(
                            ChatGroupCreated(
                              id,
                              c.name,
                              state.members.toList(),
                            ),
                          );
                          nav.pop();
                          ConversationPage.openWith(nav, bloc, c);
                        },
                ),
            ],
          ),
        ),
      );
    },
  );
}
