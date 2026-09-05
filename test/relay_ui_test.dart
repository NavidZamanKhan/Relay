import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/app.dart';
import 'package:relay/app_bloc.dart';
import 'package:relay/features/auth/auth_bloc.dart';
import 'package:relay/features/chats/chat_bloc.dart';
import 'package:relay/features/chats/chat_models.dart';
import 'package:relay/features/chats/message_bubble.dart';

const capture = bool.fromEnvironment('RELAY_CAPTURE');
final shotKey = GlobalKey();
late ChatBloc chat;
late AuthBloc auth;
late AppBloc app;

Future<void> boot(
  WidgetTester tester, {
  double width = 390,
  double height = 844,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  tester.view.padding = const FakeViewPadding(top: 44, bottom: 28);
  tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 28);
  chat = ChatBloc();
  auth = AuthBloc();
  app = AppBloc();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => chat, lazy: false),
        BlocProvider(create: (_) => auth, lazy: false),
        BlocProvider(create: (_) => app, lazy: false),
      ],
      child: RepaintBoundary(key: shotKey, child: const RelayApp()),
    ),
  );
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final context = shotKey.currentContext!;
    await Future.wait([
      for (final asset in ['aisha', 'mom', 'sami', 'rafi'])
        for (final width in [108, 120, 129, 162, 300])
          precacheImage(
            ResizeImage(AssetImage('assets/images/$asset.png'), width: width),
            context,
          ),
    ]);
  });
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    if (!chat.isClosed) await chat.close();
    if (!auth.isClosed) await auth.close();
    if (!app.isClosed) await app.close();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewPadding();
    tester.view.resetViewInsets();
  });
}

Future<void> save(WidgetTester tester, String name) async {
  if (!capture) return;
  await tester.runAsync(() async {
    final boundary =
        shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/previews/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> openChat(WidgetTester tester) async {
  await tester.tap(find.text('Aisha Rahman').first);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (family, path) in [
      ('Manrope', 'assets/fonts/Manrope.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
      (
        'packages/cupertino_icons/CupertinoIcons',
        'packages/cupertino_icons/assets/CupertinoIcons.ttf',
      ),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });
  testWidgets(
    'inbox, distinct thread, navigation, themes and settings render',
    (tester) async {
      await boot(tester);
      await save(tester, '01-inbox-light');
      expect(find.text('Relay'), findsOneWidget);
      await openChat(tester);
      await save(tester, '02-chat-light');
      expect(find.text('Okay, listen to this first'), findsOneWidget);
      expect(tester.takeException(), isNull);
      app.add(const AppThemeChanged(ThemeMode.dark));
      await tester.pumpAndSettle();
      await save(tester, '03-chat-dark');
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      await save(tester, '04-inbox-dark');
      app.add(const AppThemeChanged(ThemeMode.light));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open profile and settings'));
      await tester.pumpAndSettle();
      await save(tester, '05-settings');
      await tester.tap(find.text('Privacy & security'));
      await tester.pumpAndSettle();
      expect(find.text('Read receipts'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'rapid sends preserve IDs and conversations keep separate histories',
    (tester) async {
      await boot(tester);
      await openChat(tester);
      final before = chat.state.messages.length;
      for (var i = 0; i < 3; i++) {
        chat.add(ChatComposerChanged('Message $i'));
        chat.add(const ChatTextSent());
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(chat.state.messages.length, before + 3);
      expect(chat.state.messages.map((m) => m.id).toSet().length, before + 3);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pump();
      expect(chat.state.messages.length, before + 4);
      expect(
        chat.state.messages
            .where((m) => m.isMine)
            .every((m) => m.delivery == DeliveryStage.read),
        isTrue,
      );
      await tester.tap(find.byTooltip('Back').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mom'));
      await tester.pumpAndSettle();
      expect(find.text('Come home before it rains.'), findsOneWidget);
      expect(find.text('Message 2'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('hold recognizer survives recording UI then release sends once', (
    tester,
  ) async {
    await boot(tester);
    await openChat(tester);
    final before = chat.state.messages.length;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('record-gesture'))),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(chat.state.isRecording, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await save(tester, '06-recording');
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(chat.state.isRecording, isFalse);
    expect(chat.state.messages.length, before + 1);
    expect(chat.state.messages.last.kind, MessageKind.voice);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'slide left cancels; slide up locks; releasing locked note does not send',
    (tester) async {
      await boot(tester);
      await openChat(tester);
      final before = chat.state.messages.length;
      var origin = tester.getCenter(
        find.byKey(const ValueKey('record-gesture')),
      );
      var gesture = await tester.startGesture(origin);
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(chat.state.messages.length, before);
      expect(chat.state.isRecording, isFalse);
      origin = tester.getCenter(find.byKey(const ValueKey('record-gesture')));
      gesture = await tester.startGesture(origin);
      await tester.pump(const Duration(milliseconds: 700));
      await gesture.moveBy(const Offset(0, -80));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 200));
      expect(chat.state.recordingLocked, isTrue);
      expect(chat.state.messages.length, before);
      await save(tester, '07-recording-locked');
      await tester.tap(find.byKey(const ValueKey('record-gesture')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(chat.state.messages.length, before + 1);
      expect(chat.state.isRecording, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'clearing resets timeline item count and new messages still insert',
    (tester) async {
      await boot(tester);
      await openChat(tester);
      chat.add(const ChatHistoryCleared());
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(MessageBubble), findsNothing);
      chat.add(const ChatComposerChanged('A fresh start'));
      chat.add(const ChatTextSent());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await save(tester, '11-cleared-and-sent');
      expect(chat.state.messages.last.text, 'A fresh start');
      expect(find.text('A fresh start'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('small phone onboarding and country selection remain readable', (
    tester,
  ) async {
    await boot(tester, width: 320, height: 720);
    auth.add(const AuthRestarted());
    await tester.pumpAndSettle();
    await save(tester, '08-onboarding-small');
    expect(find.text('A little closer.'), findsOneWidget);
    await tester.tap(find.text('+880'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('India'));
    await tester.pumpAndSettle();
    expect(auth.state.countryCode, '+91');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    await save(tester, '09-otp-small');
    expect(auth.state.step, AuthStep.otp);
    expect(tester.takeException(), isNull);
    auth.add(const AuthOtpChanged('123456'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();
    await save(tester, '10-profile-small');
    expect(auth.state.step, AuthStep.profile);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard resize keeps latest message within timeline', (
    tester,
  ) async {
    await boot(tester);
    await openChat(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    tester.view.padding = const FakeViewPadding(top: 44);
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byKey(const ValueKey('record-gesture')));
    expect(rect.bottom, lessThanOrEqualTo(844 - 280));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'new group, inbox filters and search update their visible content',
    (tester) async {
      await boot(tester);
      await tester.tap(find.text('Groups'));
      await tester.pumpAndSettle();
      expect(find.text('Aisha Rahman'), findsNothing);
      expect(find.text('The home team'), findsOneWidget);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Mom');
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Mom'),
        findsOneWidget,
      );
      expect(find.text('Aisha Rahman'), findsNothing);
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('New relay'));
      await tester.pumpAndSettle();
      await save(tester, '12-new-relay');
      await tester.tap(find.text('New group'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.hintText == 'Group name',
        ),
        'Saturday crew',
      );
      await tester.tap(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Mom').last,
      );
      await tester.pumpAndSettle();
      await save(tester, '13-new-group');
      await tester.tap(find.text('Create group'));
      await tester.pumpAndSettle();
      expect(find.text('Saturday crew'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('pausing and seeking retain playback position and speed', (
    tester,
  ) async {
    await boot(tester);
    await openChat(tester);
    final id = chat.state.messages
        .firstWhere((m) => m.kind == MessageKind.voice)
        .id;
    chat.add(ChatVoiceSeeked(id, .4));
    await tester.pump();
    chat.add(ChatVoiceToggled(id));
    await tester.pump();
    expect(chat.state.voicePaused, isFalse);
    expect(chat.state.voiceProgress, .4);
    chat.add(ChatVoiceToggled(id));
    await tester.pump();
    expect(chat.state.voicePaused, isTrue);
    expect(chat.state.voiceProgress, .4);
    chat.add(const ChatVoiceSpeedChanged());
    await tester.pump();
    expect(chat.state.voiceSpeed, 1.5);
    expect(tester.takeException(), isNull);
  });
  testWidgets('capture coordinated insertion and recording frames', (
    tester,
  ) async {
    await boot(tester);
    await openChat(tester);
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      await save(tester, 'motion/frame-${i.toString().padLeft(3, '0')}');
    }
    chat.add(const ChatComposerChanged('Next time, I’m coming with you.'));
    chat.add(const ChatTextSent());
    for (var i = 15; i < 115; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      await save(tester, 'motion/frame-${i.toString().padLeft(3, '0')}');
    }
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('record-gesture'))),
    );
    for (var i = 115; i < 165; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      await save(tester, 'motion/frame-${i.toString().padLeft(3, '0')}');
    }
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    await gesture.up();
    for (var i = 165; i < 210; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      await save(tester, 'motion/frame-${i.toString().padLeft(3, '0')}');
    }
    await tester.tap(find.byKey(const ValueKey('record-gesture')));
    for (var i = 210; i < 255; i++) {
      await tester.pump(const Duration(milliseconds: 33));
      await save(tester, 'motion/frame-${i.toString().padLeft(3, '0')}');
    }
  }, skip: !capture);
}
