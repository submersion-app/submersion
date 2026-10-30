import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_card_photo.dart';

import '../../../../helpers/l10n_test_helpers.dart';
import '../../../../helpers/theme_sentinels.dart';

/// A valid 1x1 transparent PNG, so the image decoder has real bytes.
final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGA'
  'hKmMIQAAAABJRU5ErkJggg==',
);

Future<void> _pumpPhoto(
  WidgetTester tester, {
  Widget? badge,
  List<String> infoLines = const [],
  double radius = CertificationCardPhoto.borderRadius,
  bool showShadow = true,
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
              radius: radius,
              showShadow: showShadow,
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

    testWidgets('keeps the last frame while reloaded bytes decode', (
      tester,
    ) async {
      // A provider reload hands over a fresh buffer, a new image key; without
      // gapless playback every card would blank out until it decodes (#3383).
      await _pumpPhoto(tester);

      final images = tester.widgetList<Image>(find.byType(Image));
      expect(images.every((image) => image.gaplessPlayback), isTrue);
    });

    testWidgets('keeps the e-card corner radius and shadow by default', (
      tester,
    ) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          locale: const Locale('en'),
          home: Scaffold(
            body: SizedBox(
              width: 320,
              height: 202,
              child: CertificationCardPhoto(bytes: _onePixelPng),
            ),
          ),
        ),
      );
      await tester.pump();

      final decoration = _frameDecoration(tester);
      expect(
        decoration.borderRadius,
        BorderRadius.circular(CertificationCardPhoto.borderRadius),
      );
      expect(decoration.boxShadow, isNotEmpty);
    });

    testWidgets('takes a smaller radius and no shadow for a thumbnail', (
      tester,
    ) async {
      await _pumpPhoto(tester, radius: 4, showShadow: false);

      final decoration = _frameDecoration(tester);
      expect(decoration.borderRadius, BorderRadius.circular(4));
      expect(decoration.boxShadow, isNull);
    });
  });

  testWidgets('the card shadow follows the theme', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        locale: const Locale('en'),
        home: Scaffold(
          body: Center(
            child: Theme(
              data: sentinelTheme(),
              child: SizedBox(
                width: 320,
                height: 202,
                child: CertificationCardPhoto(bytes: _onePixelPng),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final shadows = boxShadowsUnder(
      tester,
      find.byType(CertificationCardPhoto),
    );
    expect(shadows, isNotEmpty);
    expect(
      shadows.every((s) => sameHue(s.color, sentinelShadow)),
      isTrue,
      reason: 'a shadow is fixed black instead of the theme shadow',
    );
  });
}

/// The decoration of the clipped frame around the photo.
BoxDecoration _frameDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(CertificationCardPhoto),
          matching: find.byType(Container),
        )
        .first,
  );
  return container.decoration! as BoxDecoration;
}
