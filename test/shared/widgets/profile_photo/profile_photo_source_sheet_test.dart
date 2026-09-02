import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_photo_source_sheet.dart';

import '../../../helpers/test_app.dart';

Future<void> _open(
  WidgetTester tester, {
  required bool hasPhoto,
  required bool allowContacts,
}) async {
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () => showProfilePhotoSourceSheet(
            context: context,
            hasPhoto: hasPhoto,
            allowContacts: allowContacts,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('hides Remove Photo when there is no photo', (tester) async {
    await _open(tester, hasPhoto: false, allowContacts: false);
    expect(find.text('Profile Photo'), findsOneWidget);
    expect(find.text('Remove Photo'), findsNothing);
  });

  testWidgets('shows Remove Photo when a photo exists', (tester) async {
    await _open(tester, hasPhoto: true, allowContacts: false);
    expect(find.text('Remove Photo'), findsOneWidget);
  });

  testWidgets('hides Choose from Contacts when not allowed', (tester) async {
    await _open(tester, hasPhoto: false, allowContacts: false);
    expect(find.text('Choose from Contacts'), findsNothing);
  });

  testWidgets('shows Choose from Contacts when allowed', (tester) async {
    await _open(tester, hasPhoto: false, allowContacts: true);
    expect(find.text('Choose from Contacts'), findsOneWidget);
  });

  testWidgets('always offers a library or file option', (tester) async {
    await _open(tester, hasPhoto: false, allowContacts: false);
    final hasLibrary = find.text('Choose from Library').evaluate().isNotEmpty;
    final hasFile = find.text('Choose File').evaluate().isNotEmpty;
    expect(hasLibrary || hasFile, isTrue);
  });

  testWidgets('tapping a source returns it', (tester) async {
    ProfilePhotoSource? chosen;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              chosen = await showProfilePhotoSourceSheet(
                context: context,
                hasPhoto: true,
                allowContacts: false,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Remove Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(chosen, ProfilePhotoSource.remove);
  });

  testWidgets('a source sheet with contacts allowed still lists the other '
      'options', (tester) async {
    await _open(tester, hasPhoto: true, allowContacts: true);
    expect(find.text('Choose from Contacts'), findsOneWidget);
    expect(find.text('Remove Photo'), findsOneWidget);
  });

  testWidgets('the sheet keeps its own bottom SafeArea', (tester) async {
    // showModalBottomSheet's useSafeArea wraps in SafeArea(bottom: false), so
    // it deliberately does NOT guard the bottom edge; the sheet "extends all
    // the way to the bottom of the screen, including any system intrusions".
    // The inner SafeArea is what keeps the last row clear of the home
    // indicator, and nesting does not double-pad because the outer one has
    // already removed the top/left/right padding from the subtree.
    await _open(tester, hasPhoto: true, allowContacts: false);

    final sheetSafeAreas = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(SafeArea),
    );
    expect(
      sheetSafeAreas,
      findsWidgets,
      reason:
          'removing the inner SafeArea would put Remove Photo under the '
          'gesture bar on a phone with no home button',
    );
  });

  testWidgets('a mobile target offers the camera and a photo library', (
    tester,
  ) async {
    // Previously unreachable: the branch is gated on the host platform, and
    // the suite runs on desktop. Switching from dart:io's Platform to
    // defaultTargetPlatform makes it overridable, so the mobile wording can
    // finally be exercised.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await _open(tester, hasPhoto: false, allowContacts: false);

    expect(find.text('Take Photo'), findsOneWidget);
    expect(find.text('Choose from Library'), findsOneWidget);
    expect(find.text('Choose File'), findsNothing);

    // Reset inside the body: the binding asserts foundation debug vars are
    // unset when the test returns, which runs before any tear-down.
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a desktop target offers a file chooser and no camera', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    await _open(tester, hasPhoto: false, allowContacts: false);

    expect(find.text('Take Photo'), findsNothing);
    expect(find.text('Choose File'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
