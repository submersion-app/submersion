import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_edit_fields.dart';
import 'package:submersion/features/buddies/presentation/editing/buddy_header_card_editor.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

Buddy _buddy({Uint8List? photo}) => Buddy(
  id: 'b1',
  name: 'John Doe',
  photo: photo,
  createdAt: DateTime(2020),
  updatedAt: DateTime(2020),
);

/// The header editor of [buddy] in a sitting.
Future<EditSession<Buddy>> _pumpEditor(WidgetTester tester, Buddy buddy) async {
  tester.view.physicalSize = const Size(700, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final session = EditSession(buddy);
  addTearDown(session.dispose);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      overrides: overrides,
      child: Scaffold(
        body: SingleChildScrollView(
          child: BuddyHeaderCardEditor(session: session),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

/// The buddy header block's editor (issue #4527, phase 3): the photo the
/// old form's avatar picker held.
void main() {
  final l = AppLocalizationsEn();
  final photo = Uint8List.fromList(
    img.encodeJpg(img.Image(width: 4, height: 4), quality: 80),
  );
  final photoButton = find.byKey(const ValueKey('buddy-edit-photo'));

  ProfileAvatar avatar(WidgetTester tester) => tester.widget<ProfileAvatar>(
    find.descendant(of: photoButton, matching: find.byType(ProfileAvatar)),
  );

  testWidgets('a stored photo shows, with the camera badge on it', (
    tester,
  ) async {
    await _pumpEditor(tester, _buddy(photo: photo));

    expect(avatar(tester).photo, photo);
    expect(
      find.descendant(of: photoButton, matching: find.byIcon(Icons.camera_alt)),
      findsOneWidget,
    );
  });

  testWidgets('with no photo it shows the initials and the sheet offers no '
      'Remove', (tester) async {
    await _pumpEditor(tester, _buddy());

    expect(avatar(tester).photo, isNull);
    expect(
      find.descendant(of: photoButton, matching: find.text('JD')),
      findsOneWidget,
    );
    await tester.tap(photoButton);
    await tester.pumpAndSettle();
    expect(find.text(l.profilePhoto_sheet_title), findsOneWidget);
    expect(find.text(l.profilePhoto_action_remove), findsNothing);
  });

  testWidgets('Remove Photo clears the photo in the sitting', (tester) async {
    final session = await _pumpEditor(tester, _buddy(photo: photo));

    await tester.tap(photoButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.profilePhoto_action_remove));
    await tester.pumpAndSettle();

    expect(session.valueOf(buddyPhotoField), isNull);
    expect(session.changedCardIds, {'header'});
    expect(avatar(tester).photo, isNull);
  });
}
