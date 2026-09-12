import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app_bloc.dart';
import '../../chat_bloc.dart';
import '../../chat_models.dart';
import 'relay_desktop_chat_list_pane.dart';
import 'relay_desktop_detail_pane.dart';
import 'relay_desktop_nav_rail.dart';

class RelayDesktopScaffold extends StatefulWidget {
  const RelayDesktopScaffold({super.key});

  @override
  State<RelayDesktopScaffold> createState() => _RelayDesktopScaffoldState();
}

class _RelayDesktopScaffoldState extends State<RelayDesktopScaffold> {
  DesktopNavTab _selectedTab = DesktopNavTab.chats;

  void _onSelectChat(Conversation chat) {
    final readReceipts =
        context.read<AppBloc>().state.preferences['Read receipts'] as bool? ??
            true;

    context.read<ChatBloc>().add(
          ChatOpened(chat.id, markAsRead: readReceipts),
        );

    if (_selectedTab != DesktopNavTab.chats) {
      setState(() {
        _selectedTab = DesktopNavTab.chats;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = context.watch<ChatBloc>().state;

    final activeConversation = chatState.conversations
        .where((c) => c.id == chatState.activeId)
        .firstOrNull;

    return Scaffold(
      body: Row(
        children: [
          // Left Dock Navigation Rail
          RelayDesktopNavRail(
            selectedTab: _selectedTab,
            onTabChanged: (tab) {
              setState(() {
                _selectedTab = tab;
              });
            },
          ),

          // Master Chat List Pane
          RelayDesktopChatListPane(
            selectedChatId: chatState.activeId,
            onSelectChat: _onSelectChat,
          ),

          // Detail Pane (Active Chat or WhatsApp-style Desktop Branding)
          Expanded(
            child: RelayDesktopDetailPane(
              selectedTab: _selectedTab,
              activeConversation: activeConversation,
            ),
          ),
        ],
      ),
    );
  }
}
