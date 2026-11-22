import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
    await pump(tester, CropFile(File('/nowhere/a.jpg')));
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
}
