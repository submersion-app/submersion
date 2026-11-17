import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_avatar.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

import '../../../../helpers/test_app.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

void main() {
  testWidgets('shows the store icon with no logo', (tester) async {
    await tester.pumpWidget(testApp(child: const DiveCenterAvatar(logo: null)));

    expect(find.byIcon(Icons.store), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsNothing);
  });

  testWidgets('shows the logo clipped to a circle at drawn size', (
    tester,
  ) async {
    final logo = _jpeg();
    await tester.pumpWidget(
      testApp(child: DiveCenterAvatar(logo: logo, radius: 24)),
    );

    expect(find.byIcon(Icons.store), findsNothing);
    expect(find.byType(ClipOval), findsOneWidget);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 48);
    // The same instance, so the image cache keeps one decode per logo.
    final provider = image.image as ResizeImage;
    expect(
      identical((provider.imageProvider as MemoryImage).bytes, logo),
      isTrue,
    );
  });

  testWidgets('the fallback icon keeps the given colours and size', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: const DiveCenterAvatar(
          logo: null,
          radius: 20,
          backgroundColor: Colors.red,
          iconColor: Colors.white,
          iconSize: 18,
        ),
      ),
    );

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(circle.backgroundColor, Colors.red);
    expect(circle.radius, 20);
    final icon = tester.widget<Icon>(find.byIcon(Icons.store));
    expect(icon.color, Colors.white);
    expect(icon.size, 18);
  });

  group('rounded square', () {
    testWidgets('no logo draws the store icon in a rounded square', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: const DiveCenterAvatar(
            logo: null,
            radius: 24,
            shape: DiveCenterAvatarShape.roundedSquare,
          ),
        ),
      );

      expect(find.byIcon(Icons.store), findsOneWidget);
      expect(find.byType(CircleAvatar), findsNothing);
      final box = tester.getSize(find.byType(DiveCenterAvatar));
      expect(box, const Size(48, 48));
    });

    testWidgets('a logo is clipped to the rounded square at drawn size', (
      tester,
    ) async {
      final logo = _jpeg();
      await tester.pumpWidget(
        testApp(
          child: DiveCenterAvatar(
            logo: logo,
            radius: 20,
            shape: DiveCenterAvatarShape.roundedSquare,
          ),
        ),
      );

      expect(find.byIcon(Icons.store), findsNothing);
      expect(find.byType(ClipRRect), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      // Decoded at the size drawn, never the stored 512 px.
      final provider = image.image as ResizeImage;
      expect(provider.width, isNotNull);
      expect(provider.width, lessThanOrEqualTo(512));
      expect(
        identical((provider.imageProvider as MemoryImage).bytes, logo),
        isTrue,
      );
    });
  });

  group('rounded square image', () {
    testWidgets('is left out of semantics, so a tile reads only its name', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: DiveCenterAvatar(
            logo: _jpeg(),
            shape: DiveCenterAvatarShape.roundedSquare,
          ),
        ),
      );

      expect(
        tester.widget<Image>(find.byType(Image)).excludeFromSemantics,
        isTrue,
      );
    });

    testWidgets('unreadable bytes fall back to the store icon', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DiveCenterAvatar(
            logo: Uint8List.fromList([1, 2, 3, 4]),
            shape: DiveCenterAvatarShape.roundedSquare,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.store), findsOneWidget);
    });
  });

  testWidgets('unreadable bytes in a circle fall back to the store icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(child: DiveCenterAvatar(logo: Uint8List.fromList([1, 2, 3, 4]))),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();

    expect(find.byIcon(Icons.store), findsOneWidget);
  });

  group('DiveCenterMarkerGlyph', () {
    test('radiusFor leaves a 4 px band inside a 2 px marker border', () {
      // The selected and unselected marker sizes on both maps and the
      // detail page.
      expect(DiveCenterMarkerGlyph.radiusFor(50), 19);
      expect(DiveCenterMarkerGlyph.radiusFor(40), 14);
    });

    testWidgets('no logo is the bare store icon, as markers drew it', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: const DiveCenterMarkerGlyph(
            logo: null,
            radius: 18,
            iconColor: Colors.white,
            iconSize: 20,
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.store));
      expect(icon.color, Colors.white);
      expect(icon.size, 20);
      expect(find.byType(CircleAvatar), findsNothing);
    });

    testWidgets('a logo fills the marker circle', (tester) async {
      final logo = _jpeg();
      await tester.pumpWidget(
        testApp(
          child: DiveCenterMarkerGlyph(
            logo: logo,
            radius: 18,
            iconColor: Colors.white,
            iconSize: 20,
          ),
        ),
      );

      expect(find.byIcon(Icons.store), findsNothing);
      expect(find.byType(ClipOval), findsOneWidget);
      expect(tester.getSize(find.byType(Image)), const Size(36, 36));
    });

    testWidgets('unreadable bytes fall back to the marker\'s own icon style', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          child: DiveCenterMarkerGlyph(
            logo: Uint8List.fromList([1, 2, 3, 4]),
            radius: 18,
            iconColor: Colors.white,
            iconSize: 20,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();

      final icon = tester.widget<Icon>(find.byIcon(Icons.store));
      expect(icon.color, Colors.white);
      expect(icon.size, 20);
    });
  });
}
