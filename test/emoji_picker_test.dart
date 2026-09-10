import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/widgets/relay_emoji_picker.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/message_composer.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class _FakeChatRepository extends Fake implements IChatRepository {
  @override
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId) =>
      const Stream.empty();

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) =>
      const Stream.empty();
}

void main() {
  testWidgets('RelayEmojiPicker renders cleanly without loading spinner', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayEmojiPicker(
            textEditingController: controller,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(RelayEmojiPicker), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('RelayEmojiPicker inserts emoji on tap and deletes with backspace', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayEmojiPicker(
            textEditingController: controller,
          ),
        ),
      ),
    );
    await tester.pump();

    // Find emoji buttons in grid
    final firstEmoji = find.byType(GestureDetector).first;
    await tester.tap(firstEmoji);
    await tester.pump();

    expect(controller.text.isNotEmpty, isTrue);

    // Tap backspace
    final backspace = find.byIcon(CupertinoIcons.delete_left);
    expect(backspace, findsOneWidget);
    await tester.tap(backspace);
    await tester.pump();

    expect(controller.text.isEmpty, isTrue);
  });

  testWidgets('RelayEmojiPicker searches emojis and filters results', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RelayEmojiPicker(
            textEditingController: controller,
          ),
        ),
      ),
    );
    await tester.pump();

    // Tap search button
    await tester.tap(find.byIcon(CupertinoIcons.search));
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'fire');
    await tester.pump();

    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('MessageComposer toggles emoji picker via smiley and keyboard button', (
    tester,
  ) async {
    final bloc = ChatBloc(
      chatRepository: _FakeChatRepository(),
      currentUserId: 'test_user',
      demoMode: true,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ChatBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: MessageComposer(contactName: 'Alice'),
          ),
        ),
      ),
    );
    await tester.pump();

    // Initially, emoji picker is closed and smiley icon is visible
    expect(find.byIcon(CupertinoIcons.smiley), findsOneWidget);
    expect(find.byType(RelayEmojiPicker), findsNothing);

    // Tap smiley icon to open emoji drawer
    await tester.tap(find.byIcon(CupertinoIcons.smiley));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Now keyboard toggle icon is shown and RelayEmojiPicker is rendered
    expect(find.byIcon(CupertinoIcons.keyboard), findsOneWidget);
    expect(find.byType(RelayEmojiPicker), findsOneWidget);

    // Tap keyboard toggle icon to close emoji drawer
    await tester.tap(find.byIcon(CupertinoIcons.keyboard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byIcon(CupertinoIcons.smiley), findsOneWidget);
    expect(find.byType(RelayEmojiPicker), findsNothing);
  });

  testWidgets('Tapping text field closes emoji picker', (tester) async {
    final bloc = ChatBloc(
      chatRepository: _FakeChatRepository(),
      currentUserId: 'test_user',
      demoMode: true,
    );
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<ChatBloc>.value(
          value: bloc,
          child: const Scaffold(
            body: MessageComposer(contactName: 'Alice'),
          ),
        ),
      ),
    );
    await tester.pump();

    // Open emoji picker
    await tester.tap(find.byIcon(CupertinoIcons.smiley));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(RelayEmojiPicker), findsOneWidget);

    // Tap the text field
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // Emoji picker is dismissed
    expect(find.byType(RelayEmojiPicker), findsNothing);
    expect(find.byIcon(CupertinoIcons.smiley), findsOneWidget);
  });
}
