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

/// The result of one card photo pick, run from a button with the platform
/// picker replaced by [pick].
class _Pick {
  int calls = 0;
  bool done = false;
  Uint8List? photo;
}

/// Pumps a button that picks a card photo through [pick], as the card
/// photos editor does.
Future<_Pick> _pump(
  WidgetTester tester,
  Future<({Uint8List bytes, String name})?> Function(ImageSource) pick,
) async {
  final result = _Pick();
  await tester.pumpWidget(
    testApp(
      overrides: await getBaseOverrides(),
      locale: const Locale('en'),
      child: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result.photo = await pickCertificationCardPhoto(
                context,
                pickOverride: (source) {
                  result.calls++;
                  return pick(source);
                },
              );
              result.done = true;
            },
            child: const Text('pick'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return result;
}

/// Opens the source sheet, chooses Gallery, and settles the encode.
Future<void> _pickFromGallery(WidgetTester tester, _Pick result) async {
  await tester.tap(find.text('pick'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Choose from Gallery'));

  // runAsync: the encode runs on a real isolate via compute, which fakeAsync
  // cannot drive.
  for (var i = 0; i < 100 && !result.done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  await tester.pump();
  expect(result.done, isTrue, reason: 'the pick finished');
}

/// A certification card photo is picked, then encoded to the stored size,
/// on every platform (issue #4527, phase 3: the card photos editor's pick).
void main() {
  final l = AppLocalizationsEn();

  testWidgets('a cancelled pick returns no photo', (tester) async {
    final result = await _pump(tester, (source) async => null);

    await _pickFromGallery(tester, result);

    // The override was reached and its null return handled cleanly.
    expect(result.calls, 1);
    expect(result.photo, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a successful pick returns the photo encoded to the stored '
      'size', (tester) async {
    // Larger than the 2000px ceiling: image_picker's own caps are ignored on
    // desktop, so the pick must route the bytes through the codec.
    final result = await _pump(
      tester,
      (source) async => (bytes: _jpeg(2400, 1500), name: 'card.jpg'),
    );

    await _pickFromGallery(tester, result);

    final decoded = img.decodeImage(result.photo!)!;
    expect(decoded.width, 2000);
    expect(decoded.height, 1250);
  });

  testWidgets('an undecodable pick says so and returns no photo', (
    tester,
  ) async {
    final result = await _pump(
      tester,
      (source) async =>
          (bytes: Uint8List.fromList([0, 1, 2, 3, 4]), name: 'broken.jpg'),
    );

    await _pickFromGallery(tester, result);

    expect(result.photo, isNull);
    expect(find.text(l.profilePhoto_error_undecodable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
