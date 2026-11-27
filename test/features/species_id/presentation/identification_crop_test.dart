import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';

import '../../../helpers/test_app.dart';

/// An identification's crop as the widget draws it (issue #4876): a file
/// analysed here, a synced crop's bytes, or a placeholder.
void main() {
  Future<void> pump(WidgetTester tester, IdentificationCropImage? crop) =>
      tester.pumpWidget(
        testApp(
          overrides: [
            identificationCropProvider.overrideWith((ref, key) async => crop),
          ],
          child: const SizedBox.square(
            dimension: 48,
            child: IdentificationCrop(mediaId: 'm1', identificationId: 'a'),
          ),
        ),
      );

  testWidgets('a synced crop draws from its bytes', (tester) async {
    await pump(tester, CropBytes(Uint8List.fromList([0xFF, 0xD8])));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<MemoryImage>());
  });

  testWidgets('a file crop draws from its file', (tester) async {
    // Never read: the widget only builds its image from the path.
    final file = File(p.join(Directory.systemTemp.path, 'no_crop', 'a.jpg'));
    await pump(tester, CropFile(file));
    await tester.pump();
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<FileImage>());
  });

  testWidgets('no crop draws the placeholder', (tester) async {
    await pump(tester, null);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets('a crop still loading draws neither the placeholder nor its '
      'reason (issue #5024)', (tester) async {
    final never = Completer<IdentificationCropImage?>();
    await tester.pumpWidget(
      testApp(
        // English, so the reason's absence is checked against its text.
        locale: const Locale('en'),
        overrides: [
          identificationCropProvider.overrideWith((ref, key) => never.future),
        ],
        child: const SizedBox.square(
          dimension: 200,
          child: IdentificationCrop(
            mediaId: 'm1',
            identificationId: 'a',
            showReason: true,
          ),
        ),
      ),
    );
    await tester.pump();
    // Laid out for its size, but neither shown nor reachable.
    expect(
      find.byIcon(Icons.image_not_supported_outlined).hitTestable(),
      findsNothing,
    );
    expect(find.text('Image not on this device').hitTestable(), findsNothing);
    expect(tester.widget<Visibility>(find.byType(Visibility)).visible, isFalse);
  });

  testWidgets('a crop still loading keeps the height of the placeholder, so '
      'the sheet does not jump when it arrives (issue #5024)', (tester) async {
    Future<double> heightWhile(Future<IdentificationCropImage?> read) async {
      // A fresh provider scope, so no earlier read is cached.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            identificationCropProvider.overrideWith((ref, key) => read),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: const IdentificationCrop(
                  key: ValueKey('crop'),
                  mediaId: 'm1',
                  identificationId: 'a',
                  showReason: true,
                ),
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byKey(const ValueKey('crop'))).height;
    }

    final absent = await heightWhile(Future.value());
    final loading = await heightWhile(
      Completer<IdentificationCropImage?>().future,
    );
    expect(absent, greaterThan(0));
    expect(loading, absent);
  });
}
