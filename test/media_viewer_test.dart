import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/views/media_viewer_page.dart';
import 'package:relay/features/chats/widgets/image_attachment_preview_sheet.dart';
import 'package:relay/features/chats/widgets/relay_message_image.dart';

void main() {
  // Minimal valid 1x1 PNG in base64
  final samplePngBase64 = base64Encode(Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
    0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
    0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
    0x42, 0x60, 0x82,
  ]));

  final sampleDate = DateTime(2026, 9, 12, 18, 45);
  final expectedTime = DateFormat('d MMM, HH:mm').format(sampleDate);

  group('MediaViewerPage widget tests', () {
    testWidgets('renders header metadata and caption text', (tester) async {
      final testMessage = RelayMessage(
        id: 'msg-img-1',
        senderId: 'user-42',
        senderName: 'Farhan Rahman',
        text: 'Sunset at Cox\'s Bazar',
        sentAt: sampleDate,
        isMine: false,
        kind: MessageKind.image,
        imageData: samplePngBase64,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaViewerPage(message: testMessage),
        ),
      );

      // Verify header elements
      expect(find.text('Farhan Rahman'), findsOneWidget);
      expect(find.text(expectedTime), findsOneWidget);

      // Verify caption pill
      expect(find.text('Sunset at Cox\'s Bazar'), findsOneWidget);

      // Verify close button and share button
      expect(find.byIcon(CupertinoIcons.chevron_left), findsOneWidget);
      expect(find.byIcon(CupertinoIcons.share), findsOneWidget);
    });

    testWidgets('hides caption pill when message text is null or empty', (tester) async {
      final testMessage = RelayMessage(
        id: 'msg-img-2',
        senderId: 'user-me',
        text: null,
        sentAt: sampleDate,
        isMine: true,
        kind: MessageKind.image,
        imageData: samplePngBase64,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaViewerPage(message: testMessage),
        ),
      );

      expect(find.text('You'), findsOneWidget);
      expect(find.text(expectedTime), findsOneWidget);
      // No caption container
      expect(find.text('Sunset at Cox\'s Bazar'), findsNothing);
    });

    testWidgets('double tap initiates zoom transformation', (tester) async {
      final testMessage = RelayMessage(
        id: 'msg-img-3',
        senderId: 'user-me',
        text: 'Double tap test',
        sentAt: sampleDate,
        isMine: true,
        kind: MessageKind.image,
        imageData: samplePngBase64,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaViewerPage(message: testMessage),
        ),
      );

      final interactiveFinder = find.byType(InteractiveViewer);
      expect(interactiveFinder, findsOneWidget);

      final InteractiveViewer viewer = tester.widget(interactiveFinder);
      final controller = viewer.transformationController;
      expect(controller, isNotNull);
      expect(controller!.value.getMaxScaleOnAxis(), closeTo(1.0, 0.05));

      // Double tap on the center
      await tester.tap(interactiveFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(interactiveFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Controller scale should now be zoomed in (around 2.5)
      expect(controller.value.getMaxScaleOnAxis(), closeTo(2.5, 0.1));
    });
  });

  group('ImageAttachmentPreviewSheet widget tests', () {
    testWidgets('renders preview sheet, accepts caption and invokes onSend', (tester) async {
      String? sentCaption;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ImageAttachmentPreviewSheet(
              imagePath: '/mock/path/test_photo.jpg',
              onSend: (caption) {
                sentCaption = caption;
              },
            ),
          ),
        ),
      );

      expect(find.text('Preview'), findsOneWidget);
      expect(find.text('Add a caption...'), findsOneWidget);

      // Enter caption text
      final captionInput = find.byType(TextField);
      expect(captionInput, findsOneWidget);
      await tester.enterText(captionInput, 'Architecture snapshot');
      await tester.pump();

      // Tap send button
      final sendButton = find.byIcon(CupertinoIcons.arrow_up);
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pump();

      expect(sentCaption, equals('Architecture snapshot'));
    });
  });

  group('RelayMessageImage widget tests', () {
    testWidgets('renders placeholder or image memory gracefully', (tester) async {
      final testMessage = RelayMessage(
        id: 'msg-img-4',
        senderId: 'user-me',
        sentAt: sampleDate,
        isMine: true,
        kind: MessageKind.image,
        imageData: samplePngBase64,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RelayMessageImage(message: testMessage),
          ),
        ),
      );

      expect(find.byType(RelayMessageImage), findsOneWidget);
    });
  });
}
