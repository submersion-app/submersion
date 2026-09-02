import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

import '../../../helpers/test_app.dart';

Uint8List _jpeg() {
  final image = img.Image(width: 64, height: 64);
  img.fill(image, color: img.ColorRgb8(10, 20, 30));
  return Uint8List.fromList(img.encodeJpg(image, quality: 80));
}

void main() {
  testWidgets('falls back to initials when there is no photo', (tester) async {
    await tester.pumpWidget(
      testApp(child: const ProfileAvatar(photo: null, initials: 'JD')),
    );
    await tester.pump();

    expect(find.text('JD'), findsOneWidget);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNull);
  });

  testWidgets('renders the photo and hides initials when present', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: ProfileAvatar(photo: _jpeg(), initials: 'JD'),
      ),
    );
    await tester.pump();

    expect(find.text('JD'), findsNothing);
    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(avatar.backgroundImage, isNotNull);
  });

  testWidgets('decodes through ResizeImage, not a bare MemoryImage', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: ProfileAvatar(photo: _jpeg(), initials: 'JD', radius: 20),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      avatar.backgroundImage,
      isA<ResizeImage>(),
      reason:
          'a bare MemoryImage decodes at intrinsic size, so a list of '
          'avatars would hold megabytes of bitmaps each',
    );
  });

  testWidgets('the decode target never exceeds the stored 512px', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        child: ProfileAvatar(photo: _jpeg(), initials: 'JD', radius: 200),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    final resize = avatar.backgroundImage! as ResizeImage;
    expect(resize.width, lessThanOrEqualTo(512));
    expect(resize.height, lessThanOrEqualTo(512));
  });

  testWidgets('draws a ring when ringColor is given', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const ProfileAvatar(
          photo: null,
          initials: 'JD',
          radius: 20,
          ringColor: Color(0xFF00FF00),
        ),
      ),
    );
    await tester.pump();

    final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(
      avatar.radius,
      18,
      reason: 'the ring is drawn outside, so the avatar shrinks to fit',
    );
  });

  testWidgets('honours a custom initials text style', (tester) async {
    await tester.pumpWidget(
      testApp(
        child: const ProfileAvatar(
          photo: null,
          initials: 'JD',
          textStyle: TextStyle(fontSize: 36),
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.text('JD'));
    expect(text.style?.fontSize, 36);
  });
}
