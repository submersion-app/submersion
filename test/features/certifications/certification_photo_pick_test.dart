import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_form_widgets.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 180, 160));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

/// One card photo pick: whether the platform picker was reached, and what
/// the pick returned.
typedef _Pick = ({Future<void> reached, Future<Uint8List?> photo});

/// Pumps a button that picks a card photo through [pick], as the card
/// photos editor does.
Future<_Pick> _pump(
  WidgetTester tester,
  Future<({Uint8List bytes, String name})?> Function(ImageSource) pick,
) async {
  final reached = Completer<void>();
  final photo = Completer<Uint8List?>();
  await tester.pumpWidget(
    testApp(
      overrides: await getBaseOverrides(),
      locale: const Locale('en'),
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => photo.complete(
              pickCertificationCardPhoto(
                context,
                pickOverride: (source) {
                  reached.complete();
                  return pick(source);
                },
              ),
            ),
            child: const Text('pick'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return (reached: reached.future, photo: photo.future);
}

/// Opens the source sheet, chooses Gallery, and waits for the encode, which
/// runs on a real isolate: what the pick returned.
Future<Uint8List?> _pickFromGallery(WidgetTester tester, _Pick pick) async {
  await tester.tap(find.text('pick'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose from Gallery'));
  await tester.pump();

  // The pick's own steps run in the test's fake zone and its encode on a
  // real isolate, so real waits (runAsync) alternate with pumps. A loaded
  // runner can take seconds over the encode: the bound is generous, and
  // the wait ends as soon as the pick does.
  Uint8List? photo;
  var done = false;
  unawaited(
    pick.photo.then((p) {
      photo = p;
      done = true;
    }),
  );
  for (var i = 0; i < 500 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(done, isTrue, reason: 'the pick finished');
  return photo;
}

/// A certification card photo is picked, then encoded to the stored size,
/// on every platform (issue #4527, phase 3: the card photos editor's pick).
void main() {
  final l = AppLocalizationsEn();

  testWidgets('a cancelled pick returns no photo', (tester) async {
    final pick = await _pump(tester, (source) async => null);

    final photo = await _pickFromGallery(tester, pick);

    // The override was reached and its null return handled cleanly.
    var reached = false;
    unawaited(pick.reached.then((_) => reached = true));
    await tester.pump();
    expect(reached, isTrue);
    expect(photo, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a successful pick returns the photo encoded to the stored '
      'size', (tester) async {
    // Larger than the 2000px ceiling: image_picker's own caps are ignored on
    // desktop, so the pick must route the bytes through the codec.
    final pick = await _pump(
      tester,
      (source) async => (bytes: _jpeg(2400, 1500), name: 'card.jpg'),
    );

    final photo = await _pickFromGallery(tester, pick);

    final decoded = img.decodeImage(photo!)!;
    expect(decoded.width, 2000);
    expect(decoded.height, 1250);
  });

  testWidgets('an undecodable pick says so and returns no photo', (
    tester,
  ) async {
    final pick = await _pump(
      tester,
      (source) async =>
          (bytes: Uint8List.fromList([0, 1, 2, 3, 4]), name: 'broken.jpg'),
    );

    final photo = await _pickFromGallery(tester, pick);

    expect(photo, isNull);
    expect(find.text(l.profilePhoto_error_undecodable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
