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
import 'repositories/i_chat_repository.dart';

sealed class _ComposeEvent {
  const _ComposeEvent();
}

final class _LoadContacts extends _ComposeEvent {
  const _LoadContacts();
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
    this.registeredContacts = const [],
    this.isLoading = false,
  });
  final String query, name;
  final bool group;
  final Set<String> members;
  final List<RelayContact> registeredContacts;
  final bool isLoading;

  _ComposeState copyWith({
    String? query,
    String? name,
    bool? group,
    Set<String>? members,
    List<RelayContact>? registeredContacts,
    bool? isLoading,
  }) => _ComposeState(
    query: query ?? this.query,
    name: name ?? this.name,
    group: group ?? this.group,
    members: members ?? this.members,
    registeredContacts: registeredContacts ?? this.registeredContacts,
    isLoading: isLoading ?? this.isLoading,
  );

  @override
  List<Object?> get props => [query, name, group, members, registeredContacts, isLoading];
}

class _ComposeBloc extends Bloc<_ComposeEvent, _ComposeState> {
  _ComposeBloc({IChatRepository? chatRepository})
      : _chatRepository = chatRepository,
        super(const _ComposeState()) {
    on<_LoadContacts>((e, emit) async {
      if (_chatRepository != null) {
        emit(state.copyWith(isLoading: true));
        try {
          final users = await _chatRepository.searchUsers(state.query);
          emit(state.copyWith(registeredContacts: users, isLoading: false));
        } catch (_) {
          emit(state.copyWith(isLoading: false));
        }
      }
    });

    on<_Query>((e, emit) async {
      emit(state.copyWith(query: e.value));
      if (_chatRepository != null) {
        try {
          final users = await _chatRepository.searchUsers(e.value);
          emit(state.copyWith(registeredContacts: users));
        } catch (_) {}
      }
    });

    on<_Name>(
      (e, emit) => emit(state.copyWith(name: e.name)),
    );

    on<_Group>(
      (e, emit) => emit(state.copyWith(group: !state.group)),
    );

    on<_Member>((e, emit) {
      final members = {...state.members};
      if (!members.add(e.id)) members.remove(e.id);
      emit(state.copyWith(members: members));
    });
  }

  final IChatRepository? _chatRepository;
}

class NewRelaySheet extends StatelessWidget {
  const NewRelaySheet({super.key});

  @override
  Widget build(BuildContext context) {
    IChatRepository? repo;
    try {
      repo = RepositoryProvider.of<IChatRepository>(context);
    } catch (_) {}

    return BlocProvider(
      create: (_) => _ComposeBloc(chatRepository: repo)..add(const _LoadContacts()),
      child: const _NewRelayBody(),
    );
  }
}

class _NewRelayBody extends StatelessWidget {
  const _NewRelayBody();
  @override
  Widget build(
    BuildContext context,
  ) => BlocBuilder<_ComposeBloc, _ComposeState>(
    builder: (context, state) {
      final convList = context
          .read<ChatBloc>()
          .state
          .conversations
          .where((c) => !c.isGroup)
          .toList();

      final existingIds = convList.map((c) => c.recipientId ?? c.id).toSet();

      final currentUid = context.read<ChatBloc>().currentUserId ?? '';

      final remoteContacts = state.registeredContacts
          .where((rc) => !existingIds.contains(rc.id))
          .map((rc) {
            final canonicalId = currentUid.isNotEmpty
                ? Conversation.directChatId(currentUid, rc.id)
                : rc.id;
            return Conversation(
              id: canonicalId,
              name: rc.displayName,
              avatarAsset: rc.avatarUrl,
              lastMessage: rc.phoneNumber.isNotEmpty
                  ? rc.phoneNumber
                  : (rc.about ?? 'On Relay'),
              timeLabel: 'Now',
              recipientId: rc.id,
              recipientPublicKey: rc.publicKey,
            );
          });

      final contacts = [...convList, ...remoteContacts]
          .where(
            (c) =>
                c.name.toLowerCase().contains(state.query.toLowerCase()) ||
                c.lastMessage.toLowerCase().contains(state.query.toLowerCase()),
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
                    final memberUid = (c.recipientId != null && c.recipientId!.isNotEmpty)
                        ? c.recipientId!
                        : (c.participantIds.isNotEmpty
                            ? c.participantIds.firstWhere(
                                (p) => p != currentUid && p.isNotEmpty,
                                orElse: () => '',
                              )
                            : (!c.id.startsWith('chat_') && !c.id.startsWith('group_')
                                ? c.id
                                : ''));
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: () {
                        if (state.group) {
                          if (memberUid.isNotEmpty) {
                            context.read<_ComposeBloc>().add(_Member(memberUid));
                          }
                        } else {
                          final nav = Navigator.of(context);
                          final bloc = context.read<ChatBloc>();
                          nav.pop();
                          bloc.add(
                            ChatDirectConversationStarted(
                              recipientUserId: c.recipientId ?? c.id,
                              recipientName: c.name,
                              recipientPublicKey: c.recipientPublicKey,
                            ),
                          );
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
                              memberUid.isNotEmpty && state.members.contains(memberUid)
                                  ? CupertinoIcons.checkmark_circle_fill
                                  : CupertinoIcons.circle,
                              color: memberUid.isNotEmpty && state.members.contains(memberUid)
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
                          final bloc = context.read<ChatBloc>();
                          final currentUserId = bloc.currentUserId ?? 'current_user';
                          final id =
                              'group_${DateTime.now().millisecondsSinceEpoch}';
                          final allParticipants =
                              <String>{currentUserId, ...state.members}.toList();
                          final c = Conversation(
                            id: id,
                            name: state.name.trim(),
                            avatarAsset: null,
                            lastMessage: 'You created this group',
                            timeLabel: 'Now',
                            lastMessageAt: DateTime.now(),
                            isGroup: true,
                            adminIds: [currentUserId],
                            participantIds: allParticipants,
                          );
                          final nav = Navigator.of(context);
                          bloc.add(
                            ChatGroupCreated(
                              id,
                              c.name,
                              state.members.toList(),
                              adminId: currentUserId,
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
