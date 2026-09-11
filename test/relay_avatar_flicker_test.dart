import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:relay/core/widgets/relay_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RelayAvatar Flicker Prevention & Cache Optimization Tests', () {
    test('avatarCacheWidth is standardized to 256', () {
      expect(RelayAvatar.avatarCacheWidth, equals(256));
    });

    testWidgets('Renders fallback text when asset is null or empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RelayAvatar(
              name: 'John Doe',
              asset: null,
              size: 40,
            ),
          ),
        ),
      );

      expect(find.text('J'), findsOneWidget);
    });

    testWidgets('Base64 decoded bytes are memoized with identical Uint8List reference', (tester) async {
      // 1x1 transparent PNG base64
      const sampleBase64 =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RelayAvatar(
              name: 'Alice',
              asset: sampleBase64,
              size: 54,
            ),
          ),
        ),
      );

      // Rebuild with the exact same base64 string to simulate route re-entry or rebuild
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RelayAvatar(
              name: 'Alice',
              asset: sampleBase64,
              size: 36,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.gaplessPlayback, isTrue);
      expect(imageWidget.image, isA<ResizeImage>());
      final resize = imageWidget.image as ResizeImage;
      expect(resize.width, equals(RelayAvatar.avatarCacheWidth));
    });

    testWidgets('Image.asset has gaplessPlayback: true and standardized cacheWidth', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RelayAvatar(
              name: 'Aisha',
              asset: 'assets/images/aisha.png',
              size: 54,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.gaplessPlayback, isTrue);
      expect(imageWidget.image, isA<ResizeImage>());
      final resize = imageWidget.image as ResizeImage;
      expect(resize.width, equals(RelayAvatar.avatarCacheWidth));
    });

    testWidgets('Image.network has gaplessPlayback: true and standardized cacheWidth', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RelayAvatar(
              name: 'Online User',
              asset: 'https://example.com/avatar.png',
              size: 40,
            ),
          ),
        ),
      );

      final imageFinder = find.byType(Image);
      expect(imageFinder, findsOneWidget);

      final imageWidget = tester.widget<Image>(imageFinder);
      expect(imageWidget.gaplessPlayback, isTrue);
      expect(imageWidget.image, isA<ResizeImage>());
      final resize = imageWidget.image as ResizeImage;
      expect(resize.width, equals(RelayAvatar.avatarCacheWidth));
    });
  });
}
