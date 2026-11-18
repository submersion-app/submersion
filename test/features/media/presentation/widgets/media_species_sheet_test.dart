import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../support/media_widget_harness.dart';

class _RecordingTaggingService extends SpeciesTaggingService {
  _RecordingTaggingService()
    : super(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      );

  final List<(String mediaId, String speciesId)> tagged = [];
  final List<(String mediaId, String speciesId)> untagged = [];

  @override
  Future<MediaSpeciesTag> tagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    tagged.add((mediaId, speciesId));
    return MediaSpeciesTag(
      id: 't',
      mediaId: mediaId,
      speciesId: speciesId,
      createdAt: DateTime(2024),
    );
  }

  @override
  Future<void> untagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    untagged.add((mediaId, speciesId));
  }
}

MediaItem _photo({String? diveId}) => testMediaItem(
  id: 'p1',
  diveId: diveId,
  siteId: diveId == null ? 's1' : null,
);

const _sightings = [
  Sighting(
    id: 'sg1',
    diveId: 'd1',
    speciesId: 'sp_whale_shark',
    speciesName: 'Whale Shark',
    speciesCategory: SpeciesCategory.shark,
  ),
  Sighting(
    id: 'sg2',
    diveId: 'd1',
    speciesId: 'c1',
    speciesName: 'My Nudibranch',
    speciesCategory: SpeciesCategory.invertebrate,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required MediaItem item,
  required _RecordingTaggingService service,
  List<SpeciesTagChip> chips = const [],
  EditSession<PhotoRecord>? sitting,
}) async {
  // The sheet holds its tags in the photo's sitting, which the viewer opens
  // over the stored tags.
  final shown =
      sitting ??
      EditSession<PhotoRecord>(
        PhotoRecord(item: item, species: chips, people: const []),
      );
  if (sitting == null) addTearDown(shown.dispose);
  final overrides = await getBaseOverrides();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        ...overrides,
        speciesTaggingServiceProvider.overrideWithValue(service),
        mediaTagChipsProvider('p1').overrideWith((ref) async => chips),
        diveSightingsProvider('d1').overrideWith((ref) async => _sightings),
      ],
      child: MediaSpeciesSheet(item: item, sitting: shown),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("lists the dive's sightings as chips, checked when tagged", (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    await _pump(
      tester,
      item: _photo(diveId: 'd1'),
      service: service,
      chips: const [
        SpeciesTagChip(
          speciesId: 'sp_whale_shark',
          storedName: 'Whale Shark',
          category: SpeciesCategory.shark,
          isBuiltIn: true,
        ),
      ],
    );

    expect(find.text('Species in this photo'), findsOneWidget);
    expect(find.text('Sighted on this dive'), findsOneWidget);
    final whale = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Whale Shark'),
    );
    final nudi = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'My Nudibranch'),
    );
    expect(whale.selected, isTrue);
    expect(nudi.selected, isFalse);
  });

  testWidgets('a site-only photo offers only the search', (tester) async {
    final service = _RecordingTaggingService();
    await _pump(tester, item: _photo(), service: service);

    expect(find.text('Sighted on this dive'), findsNothing);
    expect(find.byType(FilterChip), findsNothing);
    expect(
      find.text(
        'This photo is not linked to a dive. Search for a species to tag it.',
      ),
      findsOneWidget,
    );
    expect(find.text('Other species...'), findsOneWidget);
  });
  group('in a sitting (issue #4527)', () {
    const whale = SpeciesTagChip(
      speciesId: 'sp_whale_shark',
      storedName: 'Whale Shark',
      category: SpeciesCategory.shark,
      isBuiltIn: true,
    );

    EditSession<PhotoRecord> sittingWith(List<SpeciesTagChip> stored) {
      final session = EditSession<PhotoRecord>(
        PhotoRecord(
          item: _photo(diveId: 'd1'),
          species: stored,
          people: const [],
        ),
      );
      addTearDown(session.dispose);
      return session;
    }

    testWidgets('a toggle holds the tag; nothing is written', (tester) async {
      final service = _RecordingTaggingService();
      final sitting = sittingWith(const [whale]);
      await _pump(
        tester,
        item: _photo(diveId: 'd1'),
        service: service,
        chips: const [whale],
        sitting: sitting,
      );

      await tester.tap(find.widgetWithText(FilterChip, 'My Nudibranch'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilterChip, 'Whale Shark'));
      await tester.pump();

      expect(service.tagged, isEmpty);
      expect(service.untagged, isEmpty);
      expect(sitting.working.species.map((c) => c.speciesId), ['c1']);
      expect(
        tester
            .widget<FilterChip>(
              find.widgetWithText(FilterChip, 'My Nudibranch'),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<FilterChip>(find.widgetWithText(FilterChip, 'Whale Shark'))
            .selected,
        isFalse,
      );
    });

    testWidgets('a sitting that ends while the sheet is open leaves it read '
        'only', (tester) async {
      final service = _RecordingTaggingService();
      final sitting = EditSession<PhotoRecord>(
        PhotoRecord(
          item: _photo(diveId: 'd1'),
          species: const [whale],
          people: const [],
        ),
      );
      await _pump(
        tester,
        item: _photo(diveId: 'd1'),
        service: service,
        chips: const [whale],
        sitting: sitting,
      );

      sitting.dispose();
      await _pump(
        tester,
        item: _photo(diveId: 'd1'),
        service: service,
        chips: const [whale],
        sitting: sitting,
      );

      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'My Nudibranch'),
      );
      expect(chip.onSelected, isNull);
      final other = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('media_species_other')),
      );
      expect(other.onPressed, isNull);
      expect(service.tagged, isEmpty);
    });

    test('a species from the picker is held', () {
      final sitting = sittingWith(const [whale]);

      holdPickedSpecies(
        sitting,
        const Species(
          id: 'c9',
          commonName: 'Frogfish',
          category: SpeciesCategory.fish,
        ),
      );

      expect(sitting.valueOf(photoSpeciesField).added.keys, ['c9']);
    });

    test('the picker answering after the sitting ended changes nothing', () {
      final session = EditSession<PhotoRecord>(
        PhotoRecord(
          item: _photo(diveId: 'd1'),
          species: const [],
          people: const [],
        ),
      )..dispose();

      holdPickedSpecies(
        session,
        const Species(
          id: 'c9',
          commonName: 'Frogfish',
          category: SpeciesCategory.fish,
        ),
      );

      expect(session.valueOf(photoSpeciesField), SpeciesTagEdits.none);
    });
  });
}
