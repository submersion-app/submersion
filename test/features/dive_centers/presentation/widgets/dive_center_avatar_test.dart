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

  testWidgets('shows the logo through ProfileAvatar', (tester) async {
    final logo = _jpeg();
    await tester.pumpWidget(
      testApp(child: DiveCenterAvatar(logo: logo, radius: 24)),
    );

    expect(find.byIcon(Icons.store), findsNothing);
    final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
    // The same instance, so the image cache keeps one decode per logo.
    expect(identical(avatar.photo, logo), isTrue);
    expect(avatar.radius, 24);
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

  group('DiveCenterMarkerGlyph', () {
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
      final avatar = tester.widget<ProfileAvatar>(find.byType(ProfileAvatar));
      expect(identical(avatar.photo, logo), isTrue);
      expect(avatar.radius, 18);
    });
  });
}
