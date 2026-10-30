import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/compact_dive_center_list_tile.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dense_dive_center_list_tile.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_closed_tag.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';

import '../../../../helpers/test_app.dart';

/// Every dive center list tile greys a permanently closed center and tags it
/// (#3379).
DiveCenter _center({required bool closed}) {
  final now = DateTime(2026);
  return DiveCenter(
    id: 'c1',
    name: 'Toucan Diving',
    city: 'Kralendijk',
    isPermanentlyClosed: closed,
    createdAt: now,
    updatedAt: now,
  );
}

Finder _greyed() => find.ancestor(
  of: find.text('Toucan Diving'),
  matching: find.byWidgetPredicate(
    (w) => w is Opacity && w.opacity == kClosedDiveCenterOpacity,
  ),
);

void main() {
  final tiles = <String, Widget Function(DiveCenter)>{
    'detailed': (c) => DiveCenterListTile(center: c),
    'compact': (c) => CompactDiveCenterListTile(center: c, diveCount: 3),
    'dense': (c) => DenseDiveCenterListTile(center: c, diveCount: 3),
  };

  for (final entry in tiles.entries) {
    for (final closed in [true, false]) {
      testWidgets('${entry.key} tile, closed: $closed', (tester) async {
        await tester.pumpWidget(
          testApp(
            overrides: [
              diveCenterDiveCountProvider.overrideWith((ref, id) => 3),
            ],
            child: entry.value(_center(closed: closed)),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(DiveCenterClosedTag),
          closed ? findsOneWidget : findsNothing,
        );
        expect(_greyed(), closed ? findsOneWidget : findsNothing);
      });
    }
  }

  const phoneWidths = {'detailed': 420.0, 'compact': 380.0, 'dense': 320.0};

  for (final entry in tiles.entries) {
    testWidgets('${entry.key} tile fits the German tag on a phone', (
      tester,
    ) async {
      // The narrowest width the open tile fits at under the test font.
      tester.view.physicalSize = Size(phoneWidths[entry.key]!, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          locale: const Locale('de'),
          overrides: [diveCenterDiveCountProvider.overrideWith((ref, id) => 3)],
          child: entry.value(
            _center(
              closed: true,
            ).copyWith(name: 'Toucan Diving Kralendijk Bonaire Resort'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DiveCenterClosedTag), findsOneWidget);
    });

    testWidgets('${entry.key} tile says Closed to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        testApp(
          overrides: [diveCenterDiveCountProvider.overrideWith((ref, id) => 3)],
          child: entry.value(_center(closed: true)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp('Closed')), findsWidgets);
      handle.dispose();
    });
  }
}
