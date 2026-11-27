import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_sighting_row.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _sighting = Sighting(
  id: 'sg1',
  diveId: 'd1',
  speciesId: 'c1',
  speciesName: 'Grouper',
  speciesCategory: SpeciesCategory.fish,
  abundance: SightingAbundance.exact,
  count: 3,
  notes: 'Under the ledge',
);

Future<void> _pump(
  WidgetTester tester, {
  Sighting sighting = _sighting,
  int photoCount = 0,
  VoidCallback? onOpen,
  VoidCallback? onOpenPhotos,
  String? depthLabel,
  bool depthSelected = false,
  VoidCallback? onToggleDepth,
  String? seenAtLabel,
  double width = 800,
}) async {
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: overrides,
      child: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: DiveSightingRow(
              sighting: sighting,
              photoCount: photoCount,
              onOpen: onOpen ?? () {},
              onOpenPhotos: onOpenPhotos,
              depthLabel: depthLabel,
              depthSelected: depthSelected,
              onToggleDepth: onToggleDepth,
              seenAtLabel: seenAtLabel,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('where on the dive it was seen (issue #5092)', () {
    const depthChip = ValueKey('sighting_depth');

    testWidgets('tapping the depth chip toggles; the row opens the species', (
      tester,
    ) async {
      var toggled = 0;
      var opened = 0;
      await _pump(
        tester,
        depthLabel: '16 to 18 m',
        onToggleDepth: () => toggled++,
        onOpen: () => opened++,
      );
      expect(find.text('16 to 18 m'), findsOneWidget);

      await tester.tap(find.byKey(depthChip));
      await tester.pump();
      expect((toggled, opened), (1, 0));

      await tester.tap(find.text('Grouper'));
      await tester.pump();
      expect((toggled, opened), (1, 1));
    });

    testWidgets('a selected chip shows selected', (tester) async {
      await _pump(
        tester,
        depthLabel: '27 m',
        depthSelected: true,
        onToggleDepth: () {},
      );
      expect(tester.widget<FilterChip>(find.byKey(depthChip)).selected, isTrue);
    });

    testWidgets('no depth, no chip', (tester) async {
      await _pump(tester);
      expect(find.byKey(depthChip), findsNothing);
    });

    testWidgets('with nothing to highlight the depth is a plain label', (
      tester,
    ) async {
      await _pump(tester, depthLabel: '27 m');
      expect(find.byKey(depthChip), findsNothing);
      expect(find.text('27 m'), findsOneWidget);
    });

    testWidgets('a time on a profileless dive reads as text', (tester) async {
      await _pump(tester, seenAtLabel: 'at 12:30');
      expect(find.text('at 12:30'), findsOneWidget);
      expect(find.byKey(depthChip), findsNothing);
    });

    testWidgets('the chip says what it does to a screen reader', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, depthLabel: '27 m', onToggleDepth: () {});
      expect(
        find.bySemanticsLabel(RegExp('Show Grouper on the profile, 27 m')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('on a phone both chips fit beside a long name', (tester) async {
      await _pump(
        tester,
        sighting: _sighting.copyWith(
          speciesName: 'Yellowtail scad with a very long name',
        ),
        photoCount: 12,
        onOpenPhotos: () {},
        depthLabel: '106 to 134 ft',
        onToggleDepth: () {},
        width: 328,
      );
      expect(tester.takeException(), isNull);
      expect(find.byKey(depthChip), findsOneWidget);
      expect(find.byKey(const ValueKey('sighting_photos')), findsOneWidget);
    });
  });

  testWidgets('shows the name, notes and count badge', (tester) async {
    await _pump(tester);

    expect(find.text('Grouper'), findsOneWidget);
    expect(find.text('Under the ledge'), findsOneWidget);
    expect(find.text('x3'), findsOneWidget);
    expect(find.byKey(const ValueKey('sighting_photos')), findsNothing);
  });

  testWidgets('shows x1 for an exact count of one', (tester) async {
    // Issue #4337: an exact 1 is a deliberate count, unlike Seen.
    await _pump(tester, sighting: _sighting.copyWith(count: 1));

    expect(find.text('x1'), findsOneWidget);
  });

  testWidgets('shows no badge for a Seen sighting', (tester) async {
    await _pump(
      tester,
      sighting: _sighting.copyWith(abundance: SightingAbundance.seen, count: 1),
    );

    expect(find.textContaining(RegExp(r'^x\d')), findsNothing);
    expect(find.text('Seen'), findsNothing);
  });

  testWidgets('shows the REEF group name for a group', (tester) async {
    await _pump(
      tester,
      sighting: _sighting.copyWith(abundance: SightingAbundance.few, count: 1),
    );

    expect(find.text('Few'), findsOneWidget);
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
