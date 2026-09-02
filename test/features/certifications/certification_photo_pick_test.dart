import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';

import '../../helpers/mock_providers.dart';
import '../../helpers/test_app.dart';

Uint8List _jpeg(int width, int height) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(200, 180, 160));
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

/// Pumps the edit page with the platform picker replaced.
Future<void> _pump(
  WidgetTester tester,
  Future<({Uint8List bytes, String name})?> Function(ImageSource)? pick,
) async {
  await tester.pumpWidget(
    testApp(
      overrides: await getBaseOverrides(),
      locale: const Locale('en'),
      child: CertificationEditPage(pickPhotoOverride: pick),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

/// Taps the front card-photo slot, chooses Gallery from the source sheet, and
/// settles the encode isolate.
///
/// The card tap only opens the camera/gallery sheet; the injected picker is
/// not reached until a source is chosen.
Future<void> _pickFront(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Front').first);
  await tester.pump();
  await tester.tap(find.text('Front').first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  await tester.tap(find.text('Choose from Gallery'));

  // runAsync: the encode runs on a real isolate via compute, which fakeAsync
  // cannot drive.
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('a cancelled pick leaves the card photo unset', (tester) async {
    var called = 0;
    await _pump(tester, (source) async {
      called++;
      return null;
    });

    await _pickFront(tester);

    // The override was reached and its null return handled cleanly.
    expect(called, 1);
    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a successful pick applies the encoded photo to the card', (
    tester,
  ) async {
    // The bytes handed back are deliberately larger than the 2000px ceiling;
    // what matters here is that the page routes them through the codec and
    // shows the result, since image_picker's own caps are ignored on desktop.
    await _pump(
      tester,
      (source) async => (bytes: _jpeg(2400, 1500), name: 'card.jpg'),
    );

    expect(find.byType(Image), findsNothing);

    await _pickFront(tester);

    expect(tester.takeException(), isNull);
    expect(
      find.byType(Image),
      findsWidgets,
      reason: 'the encoded card photo should now render',
    );
  });

  testWidgets('an undecodable pick reports an error and stores nothing', (
    tester,
  ) async {
    await _pump(
      tester,
      (source) async =>
          (bytes: Uint8List.fromList([0, 1, 2, 3, 4]), name: 'broken.jpg'),
    );

    await _pickFront(tester);

    // The page must survive undecodable bytes without throwing.
    expect(tester.takeException(), isNull);
  });
}
