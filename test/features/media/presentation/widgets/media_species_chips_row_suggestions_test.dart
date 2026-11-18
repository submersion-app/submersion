import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../species_id/presentation/species_id_fakes.dart';

const _tang = SpeciesTagChip(
  speciesId: 'sp_blue_tang',
  storedName: 'Blue Tang',
  category: SpeciesCategory.fish,
  isBuiltIn: true,
);

void main() {
  setUp(() {
    marineLifeIdEnabled = true;
  });
  tearDown(resetMarineLifeIdEnabled);

  Future<void> pump(
    WidgetTester tester, {
    List<SpeciesTagChip> chips = const [_tang],
    List<SpeciesSuggestion> suggestions = const [],
    VoidCallback? onSuggestionTap,
    double? progress,
    bool settle = true,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          mediaTagChipsProvider('p1').overrideWith((ref) async => chips),
          mediaSuggestionsProvider(
            'p1',
          ).overrideWith((ref) async => suggestions),
          mediaIdentificationProgressProvider(
            'p1',
          ).overrideWith((ref) => Stream.value(progress)),
        ],
        child: MediaSpeciesChipsRow(
          mediaId: 'p1',
          onSuggestionTap: onSuggestionTap,
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A progress ring never settles.
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('a video being scanned shows how far it has got (issue '
      '#4675)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, progress: 0.4, settle: false);
    expect(find.text('40%'), findsOneWidget);
    expect(find.bySemanticsLabel('Looking for fish, 40%'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('no progress chip once the scan is done', (tester) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('a scan shows even before any tag or suggestion', (tester) async {
    await pump(tester, chips: const [], progress: 0.1, settle: false);
    expect(find.text('10%'), findsOneWidget);
  });

  testWidgets('with no suggestions the row is as before', (tester) async {
    await pump(tester);
    expect(find.byType(ActionChip), findsOneWidget);
    expect(find.text('Blue Tang'), findsOneWidget);
  });

  testWidgets('suggestions follow the tags, with their scores', (tester) async {
    await pump(
      tester,
      suggestions: [
        suggestion(parrotfish, score: 0.92),
        suggestion(chromis, score: 0.71, cropId: 'i2'),
      ],
    );
    expect(find.text('Queen Parrotfish 92%'), findsOneWidget);
    expect(find.text('Brown Chromis 71%'), findsOneWidget);
    final labels = tester
        .widgetList<ActionChip>(find.byType(ActionChip))
        .map((c) => (c.label as Text).data)
        .toList();
    expect(labels.first, 'Blue Tang');
    expect(
      find.byKey(const ValueKey('media_suggested_chip_1')),
      findsOneWidget,
    );
  });

  testWidgets('a tap opens the sheet through the callback', (tester) async {
    var taps = 0;
    await pump(
      tester,
      suggestions: [suggestion(parrotfish)],
      onSuggestionTap: () => taps++,
    );
    await tester.tap(find.byKey(const ValueKey('media_suggested_chip_1')));
    expect(taps, 1);
  });

  testWidgets('with no callback a suggestion is shown but does nothing', (
    tester,
  ) async {
    await pump(tester, suggestions: [suggestion(parrotfish)]);
    final chip = tester.widget<ActionChip>(
      find.byKey(const ValueKey('media_suggested_chip_1')),
    );
    expect(chip.onPressed, isNull);
  });

  testWidgets('a suggestion already shown as a tag is hidden', (tester) async {
    await pump(
      tester,
      chips: const [
        SpeciesTagChip(
          speciesId: 'sp_queen_parrotfish',
          storedName: 'Queen Parrotfish',
          category: SpeciesCategory.fish,
          isBuiltIn: true,
        ),
      ],
      suggestions: [suggestion(parrotfish)],
    );
    expect(find.byKey(const ValueKey('media_suggested_chip_1')), findsNothing);
  });

  testWidgets('switched off, nothing is suggested', (tester) async {
    marineLifeIdEnabled = false;
    await pump(tester, suggestions: [suggestion(parrotfish)]);
    expect(find.byKey(const ValueKey('media_suggested_chip_1')), findsNothing);
  });
}
