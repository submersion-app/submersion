import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';
import 'package:submersion/features/media/presentation/widgets/media_tagged_species_section.dart';
import 'package:submersion/shared/widgets/dashed_outline_painter.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../support/media_widget_harness.dart';

/// A tag the app applied looks apart from the diver's own, on every device,
/// and can be confirmed from the species sheet (issue #4727).
void main() {
  const appTag = SpeciesTagChip(
    speciesId: 'sp_app',
    storedName: 'Queen Parrotfish',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
    unconfirmed: true,
  );
  const handTag = SpeciesTagChip(
    speciesId: 'sp_hand',
    storedName: 'Blue Tang',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
  );

  setUp(() {
    // The mark is not a marine life identification feature: it shows where
    // the feature is off too.
    marineLifeIdEnabled = false;
    addTearDown(resetMarineLifeIdEnabled);
  });

  group('chip row', () {
    Future<void> pump(WidgetTester tester, {VoidCallback? onTap}) async {
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            mediaTagChipsProvider(
              'p1',
            ).overrideWith((ref) async => const [appTag, handTag]),
          ],
          child: MediaSpeciesChipsRow(mediaId: 'p1', onSuggestionTap: onTap),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('draws the app\'s tag apart, after the diver\'s', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);

      final mark = find.byKey(const ValueKey('media_unconfirmed_chip_sp_app'));
      expect(mark, findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Blue Tang')).dx,
        lessThan(tester.getTopLeft(find.text('Queen Parrotfish')).dx),
      );
      expect(
        // Within the row's own "species tags" label.
        find.bySemanticsLabel(
          RegExp('Queen Parrotfish, tagged by the app, not yet confirmed'),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('opens the sheet when the photo allows edits', (tester) async {
      var opened = 0;
      await pump(tester, onTap: () => opened++);

      await tester.tap(find.text('Queen Parrotfish'));
      expect(opened, 1);
    });

    testWidgets('is inert on a locked photo', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Queen Parrotfish'));
      await tester.pumpAndSettle();
      expect(find.text('Queen Parrotfish'), findsOneWidget);
    });
  });

  group('tagged on this photo', () {
    testWidgets('lists the app\'s tag first, even when sighted, with Confirm '
        'held in the sitting', (tester) async {
      final overrides = await getBaseOverrides();
      final item = testMediaItem(id: 'p1', diveId: 'd1');
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [handTag, appTag], people: []),
      );
      addTearDown(sitting.dispose);
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            diveSightingsProvider('d1').overrideWith(
              (ref) async => const [
                Sighting(
                  id: 'sg1',
                  diveId: 'd1',
                  speciesId: 'sp_app',
                  speciesName: 'Queen Parrotfish',
                ),
              ],
            ),
          ],
          // The sheet rebuilds its sections as the sitting changes.
          child: SingleChildScrollView(
            child: ListenableBuilder(
              listenable: sitting,
              builder: (_, _) =>
                  MediaTaggedSpeciesSection(item: item, sitting: sitting),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final confirm = find.byKey(const ValueKey('media_tagged_confirm_sp_app'));
      expect(confirm, findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Queen Parrotfish')).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.text('Blue Tang')).dy),
      );

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(sitting.valueOf(photoSpeciesField).confirmed, {'sp_app'});
      expect(confirm, findsNothing);
    });

    Future<void> pumpSection(WidgetTester tester) async {
      final overrides = await getBaseOverrides();
      final item = testMediaItem(id: 'p1', diveId: 'd1');
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: const [handTag, appTag], people: []),
      );
      addTearDown(sitting.dispose);
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            ...overrides,
            diveSightingsProvider('d1').overrideWith((ref) async => const []),
          ],
          child: SingleChildScrollView(
            child: MediaTaggedSpeciesSection(item: item, sitting: sitting),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a screen reader reaches the app\'s tag and its remove '
        'action', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSection(tester);

      expect(
        find.bySemanticsLabel(
          'Queen Parrotfish, tagged by the app, not yet confirmed',
        ),
        findsOneWidget,
      );
      // The chip's remove button: a node of its own that a screen reader
      // can press, not swallowed by the chip's label.
      expect(
        tester.getSemantics(
          find.byKey(const ValueKey('media_tagged_remove_sp_app')),
        ),
        isSemantics(
          tooltip: 'Remove Queen Parrotfish',
          isButton: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('the dashed outline hugs the chip, not its tap area', (
      tester,
    ) async {
      await pumpSection(tester);

      final dashed = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.foregroundPainter is DashedOutlinePainter,
      );
      expect(dashed, findsOneWidget);
      expect(tester.getSize(dashed).height, lessThan(kMinInteractiveDimension));
    });
  });
}
