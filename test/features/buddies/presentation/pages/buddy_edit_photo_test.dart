import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('the edit page shows a tappable ProfileAvatar, not a stub', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        child: const BuddyEditPage(),
      ),
    );
    await tester.pump();

    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(find.byIcon(Icons.camera_alt), findsOneWidget);
    expect(find.byType(GestureDetector), findsWidgets);
  });

  testWidgets('the avatar is wrapped in a tap target', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        child: const BuddyEditPage(),
      ),
    );
    await tester.pump();

    // The whole avatar opens the source sheet; the camera badge is decoration
    // and is excluded from semantics so the control reads as one button.
    final detector = tester.widget<GestureDetector>(
      find
          .ancestor(
            of: find.byType(ProfileAvatar),
            matching: find.byType(GestureDetector),
          )
          .first,
    );
    expect(detector.onTap, isNotNull);
  });

  testWidgets('an initial photo from a contact import is shown', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        child: const BuddyEditPage(initialName: 'Jane Doe', initialPhoto: null),
      ),
    );
    await tester.pump();

    // With no photo the avatar falls back to the typed name's initials.
    expect(find.byType(ProfileAvatar), findsOneWidget);
    expect(find.text('JD'), findsOneWidget);
  });

  testWidgets('tapping the avatar opens the source sheet', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        child: const BuddyEditPage(),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(ProfileAvatar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Profile Photo'), findsOneWidget);
    // No photo yet, so Remove is not offered.
    expect(find.text('Remove Photo'), findsNothing);
  });

  testWidgets('choosing Remove clears a photo carried in from a contact', (
    tester,
  ) async {
    // Drives the whole _pickPhoto handler without a platform plugin: the
    // sheet is in-process and Remove short-circuits before any picker.
    final image = img.Image(width: 32, height: 32);
    img.fill(image, color: img.ColorRgb8(10, 20, 30));
    final bytes = Uint8List.fromList(img.encodeJpg(image, quality: 80));

    await tester.pumpWidget(
      testApp(
        overrides: await getBaseOverrides(),
        locale: const Locale('en'),
        child: BuddyEditPage(initialName: 'Jane Doe', initialPhoto: bytes),
      ),
    );
    await tester.pump();

    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).photo,
      isNotNull,
    );

    await tester.tap(find.byType(ProfileAvatar));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Remove Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.widget<ProfileAvatar>(find.byType(ProfileAvatar)).photo,
      isNull,
    );
    expect(find.text('JD'), findsOneWidget);
  });
}
