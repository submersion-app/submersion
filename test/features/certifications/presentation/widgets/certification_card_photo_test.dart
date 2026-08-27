import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';

import '../../../../helpers/l10n_test_helpers.dart';

/// A valid 1x1 transparent PNG, so the image decoder has real bytes.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

Future<void> _pumpPhoto(
  WidgetTester tester, {
  Widget? badge,
  List<String> infoLines = const [],
}) async {
  await tester.pumpWidget(
    localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 202,
            child: CertificationCardPhoto(
              bytes: _onePixelPng,
              badge: badge,
              infoLines: infoLines,
            ),
          ),
        ),
      ),
    ),
  );
  // pump(), not pumpAndSettle(): these assertions only inspect the widget tree,
  // and image decoding is asynchronous work we do not need to await.
  await tester.pump();
}

void main() {
  group('CertificationCardPhoto', () {
    testWidgets('renders a blurred cover backdrop under a contained photo', (
      tester,
    ) async {
      await _pumpPhoto(tester);

      final images = tester.widgetList<Image>(find.byType(Image)).toList();
      expect(images, hasLength(2));
      expect(images[0].fit, BoxFit.cover);
      expect(images[1].fit, BoxFit.contain);
      expect(find.byType(ImageFiltered), findsOneWidget);
    });

    testWidgets('omits the info strip when no lines are given', (tester) async {
      await _pumpPhoto(tester);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('renders each info line in the strip', (tester) async {
      await _pumpPhoto(
        tester,
        infoLines: const ['PADI  -  Open Water Diver', 'ERIC GRIFFIN'],
      );

      expect(find.text('PADI  -  Open Water Diver'), findsOneWidget);
      expect(find.text('ERIC GRIFFIN'), findsOneWidget);
    });

    testWidgets('renders the badge when one is supplied', (tester) async {
      await _pumpPhoto(
        tester,
        badge: const Text('EXPIRED', key: Key('test-badge')),
      );

      expect(find.byKey(const Key('test-badge')), findsOneWidget);
    });
  });
}
