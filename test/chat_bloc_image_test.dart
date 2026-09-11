import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/repositories/i_chat_repository.dart';

class _ImageTestChatRepository extends Fake implements IChatRepository {
  final List<({String chatId, String localFilePath, String? caption, String? messageId})>
      sendImageCalls = [];

  final StreamController<List<Conversation>> _convs =
      StreamController<List<Conversation>>.broadcast();
  final StreamController<List<RelayMessage>> _msgs =
      StreamController<List<RelayMessage>>.broadcast();

  @override
  Stream<List<Conversation>> watchConversations(String currentUserId) => _convs.stream;

  @override
  Stream<List<RelayMessage>> watchMessages(String chatId, String currentUserId) => _msgs.stream;

  @override
  Future<void> sendImageMessage({
    required String chatId,
    required String localFilePath,
    required String recipientPublicKey,
    String? caption,
    String? messageId,
    String? replyTo,
    String? replyToId,
  }) async {
    sendImageCalls.add((
      chatId: chatId,
      localFilePath: localFilePath,
      caption: caption,
      messageId: messageId,
    ));
  }

  @override
  Future<String> getOrDownloadImage({
    required String chatId,
    required String messageId,
    required String imageUrl,
    String? imageData,
  }) async => localFilePath(messageId);

  String localFilePath(String messageId) => '/cache/img_$messageId.jpg';
}

void main() {
  group('ChatBloc Image Attachments Pipeline', () {
    late _ImageTestChatRepository repository;

    setUp(() {
      repository = _ImageTestChatRepository();
    });

    test('ChatImagePicked dispatches sendImageMessage and adds optimistic image message', () async {
      final bloc = ChatBloc(
        chatRepository: repository,
        currentUserId: 'user1',
        demoMode: false,
      );

      // Simulate authenticated user and opening a chat thread
      bloc.emit(bloc.state.copyWith(
        activeId: 'chat_user1_user2',
        conversations: const [
          Conversation(
            id: 'chat_user1_user2',
            name: 'Sadman',
            avatarAsset: null,
            lastMessage: 'Hello',
            timeLabel: '10:00',
            recipientId: 'user2',
          ),
        ],
      ));

      expect(bloc.state.activeId, 'chat_user1_user2');

      // Dispatch ChatImagePicked
      bloc.add(const ChatImagePicked('/tmp/compressed_photo.jpg', caption: 'Sunset in Sylhet'));

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final thread = bloc.state.threads['chat_user1_user2'];
      expect(thread, isNotNull);
      expect(thread!.isNotEmpty, isTrue);

      final imageMsg = thread.last;
      expect(imageMsg.kind, MessageKind.image);
      expect(imageMsg.asset, '/tmp/compressed_photo.jpg');
      expect(imageMsg.text, 'Sunset in Sylhet');

      // Verify repository was called
      expect(repository.sendImageCalls.length, 1);
      expect(repository.sendImageCalls.first.localFilePath, '/tmp/compressed_photo.jpg');
      expect(repository.sendImageCalls.first.caption, 'Sunset in Sylhet');

      await bloc.close();
    });

    test('ChatImagePicked in demo mode appends outgoing image message', () async {
      final bloc = ChatBloc(demoMode: true);

      bloc.add(const ChatOpened('demo_chat_1'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(const ChatImagePicked('/tmp/demo_image.jpg', caption: 'Check this out'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final thread = bloc.state.threads['demo_chat_1'];
      expect(thread, isNotNull);
      expect(thread!.isNotEmpty, isTrue);
      expect(thread.last.kind, MessageKind.image);
      expect(thread.last.asset, '/tmp/demo_image.jpg');

      await bloc.close();
    });
  });
}
