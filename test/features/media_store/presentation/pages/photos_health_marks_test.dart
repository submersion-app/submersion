// Issue #4561: each Photos page item with a problem carries the photos
// mark, the page's one status colour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/domain/data_health/feature_health.dart';
import 'package:submersion/features/settings/domain/data_health/media_health.dart';
import 'package:submersion/features/settings/presentation/widgets/data_health/health_symbol.dart';

import 'photos_page_harness.dart';

FeatureHealth _media(HealthReason reason, {String? subjectId}) =>
    pickHealth(DataFeature.media, [
      FeatureHealth(
        feature: DataFeature.media,
        level: HealthLevel.attention,
        reason: reason,
        subjectId: subjectId,
      ),
    ]);

void main() {
  late PhotosPageHarness h;

  setUp(() async => h = await PhotosPageHarness.create());

  Finder markIn(Finder of) =>
      find.descendant(of: of, matching: find.byType(HealthSymbol));

  Finder tileWith(String text) =>
      find.ancestor(of: find.text(text), matching: find.byType(ListTile));

  testWidgets('an unreachable store marks the status line, icon uncoloured', (
    tester,
  ) async {
    await tester.pumpWidget(
      h.app(
        statusHint: 'B2',
        reachable: false,
        mediaHealth: _media(HealthReason.mediaStoreUnreachable),
      ),
    );
    await tester.pumpAndSettle();

    final line = find.byKey(const Key('photos-status'));
    expect(markIn(line), findsOneWidget);
    expect(
      tester
          .widget<Icon>(
            find.descendant(
              of: line,
              matching: find.byIcon(Icons.error_outline),
            ),
          )
          .color,
      isNull,
    );
  });

  testWidgets('a Lightroom setup item marks Photo sources, not the store', (
    tester,
  ) async {
    await tester.pumpWidget(
      h.app(
        statusHint: 'B2',
        mediaHealth: _media(
          HealthReason.mediaFinishSetup,
          subjectId: mediaSetupLightroom,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(markIn(tileWith('Photo library and files')), findsOneWidget);
    expect(markIn(find.byKey(const Key('photos-using'))), findsNothing);
  });

  testWidgets('a store setup item marks the Using row', (tester) async {
    await tester.pumpWidget(
      h.app(
        statusHint: 'B2',
        mediaHealth: _media(
          HealthReason.mediaFinishSetup,
          subjectId: mediaSetupStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(markIn(find.byKey(const Key('photos-using'))), findsOneWidget);
    expect(markIn(tileWith('Photo library and files')), findsNothing);
  });
}
