import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_sighting_row.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _sighting = Sighting(
  id: 'sg1',
  diveId: 'd1',
  speciesId: 'c1',
  speciesName: 'Grouper',
  speciesCategory: SpeciesCategory.fish,
  count: 3,
  notes: 'Under the ledge',
);

Future<void> _pump(
  WidgetTester tester, {
  Sighting sighting = _sighting,
  int photoCount = 0,
  VoidCallback? onOpen,
  VoidCallback? onOpenPhotos,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: overrides,
      child: Scaffold(
        body: DiveSightingRow(
          sighting: sighting,
          photoCount: photoCount,
          onOpen: onOpen ?? () {},
          onOpenPhotos: onOpenPhotos,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the name, notes and count badge', (tester) async {
    await _pump(tester);

    expect(find.text('Grouper'), findsOneWidget);
    expect(find.text('Under the ledge'), findsOneWidget);
    expect(find.text('x3'), findsOneWidget);
    expect(find.byKey(const ValueKey('sighting_photos')), findsNothing);
  });

  testWidgets('hides the count badge for a single animal', (tester) async {
    await _pump(tester, sighting: _sighting.copyWith(count: 1));

    expect(find.text('x1'), findsNothing);
  });

  testWidgets('tapping the row opens the species', (tester) async {
    var opened = false;
    await _pump(tester, onOpen: () => opened = true);

    await tester.tap(find.text('Grouper'));

    expect(opened, isTrue);
  });

  testWidgets('a positive photo count shows a chip that opens the photos', (
    tester,
  ) async {
    var openedPhotos = false;
    await _pump(tester, photoCount: 2, onOpenPhotos: () => openedPhotos = true);

    expect(find.text('2 photos'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sighting_photos')));

    expect(openedPhotos, isTrue);
  });

  testWidgets('the chip singularizes one photo', (tester) async {
    await _pump(tester, photoCount: 1, onOpenPhotos: () {});

    expect(find.text('1 photo'), findsOneWidget);
  });

  testWidgets('no chip without a photo callback', (tester) async {
    await _pump(tester, photoCount: 2);

    expect(find.byKey(const ValueKey('sighting_photos')), findsNothing);
  });
}
