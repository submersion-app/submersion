import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/buddies/data/services/contact_photo_loader.dart';

import '../../../helpers/test_app.dart';

Contact _contact({Uint8List? fullSize, Uint8List? thumbnail}) => Contact(
  id: 'c1',
  displayName: 'Jane Doe',
  photo: fullSize == null && thumbnail == null
      ? null
      : Photo(fullSize: fullSize, thumbnail: thumbnail),
);

/// Runs [loadContactPhoto] with the native picker replaced and returns its
/// result plus the built context, so snackbars can be asserted.
Future<Uint8List?> _run(
  WidgetTester tester,
  Future<Contact?> Function() picker,
) async {
  Uint8List? result;
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      child: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            result = await loadContactPhoto(
              context,
              // Granted explicitly: these cases exercise photo selection, and
              // flutter_test reports defaultTargetPlatform as android, so the
              // real guard would reach the flutter_contacts platform channel.
              ensureAccessOverride: () async => true,
              pickContactOverride: picker,
            );
          },
          child: const Text('load'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('load'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return result;
}

void main() {
  testWidgets('prefers the full resolution photo over the thumbnail', (
    tester,
  ) async {
    // A contact thumbnail is typically 96x96 or 150x150, well under the 512
    // the codec stores, so it is a fallback rather than a preference.
    final full = Uint8List.fromList([1, 1, 1, 1]);
    final thumb = Uint8List.fromList([2, 2]);

    final result = await _run(
      tester,
      () async => _contact(fullSize: full, thumbnail: thumb),
    );

    expect(result, full);
  });

  testWidgets('falls back to the thumbnail when there is no full size', (
    tester,
  ) async {
    final thumb = Uint8List.fromList([2, 2]);

    final result = await _run(tester, () async => _contact(thumbnail: thumb));

    expect(result, thumb);
  });

  testWidgets('a contact with no photo reports it plainly, not as an error', (
    tester,
  ) async {
    final result = await _run(tester, () async => _contact());

    expect(result, isNull);
    expect(find.text('That contact does not have a photo.'), findsOneWidget);
  });

  testWidgets('cancelling the picker returns null and says nothing', (
    tester,
  ) async {
    final result = await _run(tester, () async => null);

    expect(result, isNull);
    // Cancelling is not a failure, so no message is shown.
    expect(find.text('That contact does not have a photo.'), findsNothing);
  });

  testWidgets('property access needs no permission off Android', (
    tester,
  ) async {
    // The native picker is permissionless on both platforms, and asking it for
    // properties always works on iOS. Only Android needs READ_CONTACTS, which
    // is why the iOS build shows no address-book prompt for a contact photo.
    //
    // The platform is pinned rather than read from the host: the
    // implementation uses defaultTargetPlatform, which flutter_test reports as
    // android on every machine.
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await expectLater(ensureContactPropertyAccess(), completion(isTrue));
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('a denied permission explains itself rather than doing nothing', (
    tester,
  ) async {
    // Only Android can deny here, so the branch is unreachable on the test
    // host without a seam. Silence would read as a broken menu action: the
    // user taps "Choose from Contacts" and nothing happens.
    Uint8List? result;
    var pickerCalls = 0;

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await loadContactPhoto(
                context,
                ensureAccessOverride: () async => false,
                pickContactOverride: () async {
                  pickerCalls++;
                  return null;
                },
              );
            },
            child: const Text('load'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('load'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, isNull);
    expect(pickerCalls, 0, reason: 'the picker must not open without access');
    // Photo-specific wording: this path is reached from "Choose from
    // Contacts" in the photo sheet, where the buddy-import string would
    // describe the wrong action.
    expect(
      find.text('Contacts permission is required to choose a photo.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('import buddies'),
      findsNothing,
      reason: 'the buddy-import wording must not leak into the photo flow',
    );
  });
}
