import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_download_prompt_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../species_id/presentation/species_id_fakes.dart';
import '../support/media_widget_harness.dart';

class _Tagging extends SpeciesTaggingService {
  _Tagging()
    : super(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      );

  final tagged = <String>[];
  final untagged = <String>[];

  @override
  Future<MediaSpeciesTag> tagPhoto({
    required String mediaId,
    required String speciesId,
  }) async {
    tagged.add(speciesId);
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
    untagged.add(speciesId);
  }
}

const _sightings = [
  Sighting(
    id: 'sg1',
    diveId: 'd1',
    speciesId: 'sp_whale_shark',
    speciesName: 'Whale Shark',
    speciesCategory: SpeciesCategory.shark,
  ),
];

const _whaleTag = SpeciesTagChip(
  speciesId: 'sp_whale_shark',
  storedName: 'Whale Shark',
  category: SpeciesCategory.shark,
  isBuiltIn: true,
);
const _ownTag = SpeciesTagChip(
  speciesId: 'own-3',
  storedName: 'Yellowtail Snapper',
  category: SpeciesCategory.fish,
  isBuiltIn: false,
);

MediaItem _photo() => testMediaItem(id: 'p1', diveId: 'd1');
MediaItem _video() =>
    testMediaItem(id: 'p1', diveId: 'd1', mediaType: MediaType.video);

void main() {
  late _Tagging tagging;
  late RecordingIdentificationService service;
  late FakeAcceptor acceptor;
  late List<NearbyListRequest> nearbyAsked;

  setUp(() {
    marineLifeIdEnabled = true;
    tagging = _Tagging();
    service = RecordingIdentificationService();
    acceptor = FakeAcceptor();
    nearbyAsked = [];
  });
  tearDown(resetMarineLifeIdEnabled);

  /// Pumps the sheet over [sitting], or over a sitting opened on [chips]
  /// as the viewer does, and returns the sitting it holds in. The
  /// "Recorded nearby" list is [nearby], or [pending] until it completes,
  /// so no test here reaches GBIF.
  Future<EditSession<PhotoRecord>> pump(
    WidgetTester tester, {
    List<SpeciesSuggestion> suggestions = const [],
    List<SpeciesTagChip> chips = const [_whaleTag, _ownTag],
    bool busy = false,
    EditSession<PhotoRecord>? sitting,
    bool settle = true,
    List<Species> allSpecies = const [],
    MediaItem? item,
    double? progress,
    bool promptWanted = false,
    NearbySpecies? nearby,
    Completer<NearbySpecies?>? pending,
  }) async {
    final shown =
        sitting ??
        EditSession<PhotoRecord>(
          PhotoRecord(item: item ?? _photo(), species: chips, people: const []),
        );
    if (sitting == null) addTearDown(shown.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          speciesTaggingServiceProvider.overrideWithValue(tagging),
          mediaTagChipsProvider('p1').overrideWith((ref) async => chips),
          diveSightingsProvider('d1').overrideWith((ref) async => _sightings),
          mediaSuggestionsProvider(
            'p1',
          ).overrideWith((ref) async => suggestions),
          mediaIdentificationBusyProvider(
            'p1',
          ).overrideWith((ref) => Stream.value(busy)),
          mediaIdentificationServiceProvider.overrideWithValue(service),
          suggestionAcceptorProvider.overrideWithValue(acceptor),
          identificationCropProvider.overrideWith((ref, key) async => null),
          allSpeciesProvider.overrideWith((ref) async => allSpecies),
          mediaIdentificationProgressProvider(
            'p1',
          ).overrideWith((ref) => Stream.value(progress)),
          speciesDownloadPromptProvider.overrideWithValue(promptWanted),
          recordedNearbyListProvider.overrideWith((ref, request) {
            nearbyAsked.add(request);
            return pending?.future ?? Future.value(nearby);
          }),
        ],
        child: MediaSpeciesSheet(item: item ?? _photo(), sitting: shown),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      // A spinner never settles.
      await tester.pump();
      await tester.pump();
    }
    return shown;
  }

  group('Suggested', () {
    testWidgets('lists one row per species, with its count', (tester) async {
      await pump(
        tester,
        suggestions: [
          suggestion(parrotfish, score: 0.92),
          suggestion(chromis, score: 0.71, count: 3, cropId: 'i2'),
        ],
      );
      expect(find.text('Suggested'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('media_suggested_row_1')),
        findsOneWidget,
      );
      expect(find.text('Brown Chromis (3)'), findsOneWidget);
      expect(find.text('92%'), findsOneWidget);
    });

    testWidgets('nothing suggested and nothing running shows no section', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Suggested'), findsNothing);
    });

    testWidgets('with no model it offers the download (#4773)', (tester) async {
      await pump(tester, promptWanted: true);
      expect(
        find.byKey(const ValueKey('species_download_prompt')),
        findsOneWidget,
      );
    });

    testWidgets('a video says video in its title (issue #4675)', (
      tester,
    ) async {
      await pump(tester, item: _video());
      expect(find.text('Species in this video'), findsOneWidget);
      expect(find.text('Species in this photo'), findsNothing);
    });

    testWidgets('a video suggestion shows no count', (tester) async {
      await pump(
        tester,
        item: _video(),
        suggestions: [suggestion(chromis, score: 0.71, count: 3)],
      );
      expect(find.text('Brown Chromis'), findsOneWidget);
      expect(find.text('Brown Chromis (3)'), findsNothing);
    });

    testWidgets('a video being scanned shows how far it has got, above '
        'what it found', (tester) async {
      await pump(
        tester,
        item: _video(),
        busy: true,
        progress: 0.4,
        suggestions: [suggestion(parrotfish, score: 0.92)],
        settle: false,
      );
      expect(find.text('Looking for fish, 40%'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('media_suggested_row_1')),
        findsOneWidget,
      );
    });

    testWidgets('while analysing it says so', (tester) async {
      await pump(tester, busy: true, settle: false);
      expect(find.text('Looking for fish...'), findsOneWidget);
    });

    testWidgets('Add holds the species in a sitting', (tester) async {
      final session = EditSession<PhotoRecord>(
        PhotoRecord(item: _photo(), species: const [], people: const []),
      );
      addTearDown(session.dispose);
      await pump(
        tester,
        suggestions: [suggestion(parrotfish)],
        sitting: session,
      );
      await tester.tap(find.byKey(const ValueKey('media_suggested_add_1')));
      await tester.pumpAndSettle();
      expect(acceptor.resolved, [parrotfish]);
      expect(tagging.tagged, isEmpty);
      // Save's tag write reconciles them, not Add.
      expect(service.reconciled, isEmpty);
      expect(session.working.species.map((c) => c.speciesId), [
        'sp_queen_parrotfish',
      ]);
    });

    testWidgets('Add in a sitting takes the row away, also for a species '
        'from outside the catalogue', (tester) async {
      final session = EditSession<PhotoRecord>(
        PhotoRecord(item: _photo(), species: const [], people: const []),
      );
      addTearDown(session.dispose);
      await pump(
        tester,
        suggestions: [suggestion(chromis, cropId: 'i2')],
        sitting: session,
        // The species Add created for it.
        allSpecies: const [
          Species(
            id: 'own-2',
            commonName: 'Brown Chromis',
            scientificName: 'Chromis multilineata',
            category: SpeciesCategory.fish,
          ),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('media_suggested_add_2')));
      await tester.pumpAndSettle();
      expect(session.working.species.map((c) => c.speciesId), ['own-2']);
      expect(find.byKey(const ValueKey('media_suggested_row_2')), findsNothing);
    });

    testWidgets('Add on a possible match in the crop view holds it', (
      tester,
    ) async {
      acceptor.delay = const Duration(seconds: 1);
      final session = await pump(
        tester,
        suggestions: [suggestion(parrotfish)],
        chips: const [],
      );
      await tester.tap(find.byKey(const ValueKey('media_suggested_crop_1')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('media_suggested_candidate_2')),
          matching: find.text('Add'),
        ),
      );
      // Past the sheet closing and the slow lookup.
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      expect(tagging.tagged, isEmpty);
      expect(session.working.species.map((c) => c.speciesId), ['own-2']);
    });

    testWidgets('dismissing rejects every identification of the species', (
      tester,
    ) async {
      await pump(
        tester,
        suggestions: [
          suggestion(chromis, cropId: 'i2', ids: ['i2', 'i3']),
        ],
      );
      await tester.tap(find.byKey(const ValueKey('media_suggested_dismiss_2')));
      await tester.pumpAndSettle();
      expect(service.rejected.single.$1, 'p1');
      expect(service.rejected.single.$2, ['i2', 'i3']);
    });

    testWidgets('Add all holds each suggestion', (tester) async {
      final session = await pump(
        tester,
        suggestions: [
          suggestion(parrotfish),
          suggestion(chromis, cropId: 'i2'),
        ],
        chips: const [],
      );
      await tester.tap(find.byKey(const ValueKey('media_suggested_addAll')));
      await tester.pumpAndSettle();
      expect(tagging.tagged, isEmpty);
      expect(session.working.species.map((c) => c.speciesId), [
        'sp_queen_parrotfish',
        'own-2',
      ]);
    });

    testWidgets('a crop that is not on the device shows a placeholder', (
      tester,
    ) async {
      await pump(tester, suggestions: [suggestion(parrotfish)]);
      await tester.tap(find.byKey(const ValueKey('media_suggested_crop_1')));
      await tester.pumpAndSettle();
      expect(find.text('Image not on this device'), findsOneWidget);
      expect(find.text('Possible matches'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('media_suggested_candidate_2')),
        findsOneWidget,
      );
    });
  });

  group('Recorded nearby (issue #4668)', () {
    Finder markerIn(String key) => find.descendant(
      of: find.byKey(ValueKey(key)),
      matching: find.text('Recorded nearby'),
    );

    testWidgets('a suggestion recorded nearby says so', (tester) async {
      await pump(
        tester,
        suggestions: [
          suggestion(parrotfish, score: 0.92),
          suggestion(chromis, score: 0.71, cropId: 'i2'),
        ],
        nearby: const NearbySpecies(speciesKeys: {1}),
      );
      expect(markerIn('media_suggested_row_1'), findsOneWidget);
      expect(markerIn('media_suggested_row_2'), findsNothing);
      // The photo's dive, and no GPS of its own.
      expect(nearbyAsked.toSet(), {(diveId: 'd1', photo: null)});
    });

    testWidgets('a catalogue species on the list says so, whatever its key', (
      tester,
    ) async {
      await pump(
        tester,
        suggestions: [suggestion(parrotfish)],
        nearby: const NearbySpecies(
          matched: [
            MatchedNearbySpecies(
              speciesId: 'sp_queen_parrotfish',
              occurrenceCount: 4,
            ),
          ],
        ),
      );
      expect(markerIn('media_suggested_row_1'), findsOneWidget);
    });

    testWidgets('while the list loads, no row shows the marker', (
      tester,
    ) async {
      await pump(
        tester,
        suggestions: [suggestion(parrotfish)],
        pending: Completer<NearbySpecies?>(),
      );
      expect(find.byKey(const ValueKey('media_suggested_row_1')), findsOne);
      expect(find.text('Recorded nearby'), findsNothing);
    });

    testWidgets('with no list, no row shows the marker', (tester) async {
      await pump(tester, suggestions: [suggestion(parrotfish)]);
      expect(find.byKey(const ValueKey('media_suggested_row_1')), findsOne);
      expect(find.text('Recorded nearby'), findsNothing);
    });

    testWidgets('the marker arriving late moves no row or button', (
      tester,
    ) async {
      // Add and dismiss act at once, so a line that pushed them down as
      // the list arrived could turn a tap into the neighbour's.
      final pending = Completer<NearbySpecies?>();
      await pump(
        tester,
        suggestions: [
          suggestion(parrotfish),
          suggestion(chromis, cropId: 'i2'),
        ],
        pending: pending,
      );
      List<Rect> buttons() => [
        for (final key in [
          'media_suggested_add_1',
          'media_suggested_dismiss_1',
          'media_suggested_add_2',
          'media_suggested_dismiss_2',
        ])
          tester.getRect(find.byKey(ValueKey(key))),
      ];
      final before = buttons();

      pending.complete(const NearbySpecies(speciesKeys: {1}));
      await tester.pumpAndSettle();

      expect(markerIn('media_suggested_row_1'), findsOneWidget);
      expect(buttons(), before);
    });

    testWidgets('while the list loads, the crop view shows no marker', (
      tester,
    ) async {
      await pump(
        tester,
        suggestions: [suggestion(parrotfish)],
        pending: Completer<NearbySpecies?>(),
      );
      await tester.tap(find.byKey(const ValueKey('media_suggested_crop_1')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('media_suggested_candidate_2')),
        findsOne,
      );
      expect(find.text('Recorded nearby'), findsNothing);
    });

    testWidgets('a possible match recorded nearby says so in the crop view', (
      tester,
    ) async {
      await pump(
        tester,
        suggestions: [suggestion(parrotfish)],
        nearby: const NearbySpecies(speciesKeys: {2}),
      );
      await tester.tap(find.byKey(const ValueKey('media_suggested_crop_1')));
      await tester.pumpAndSettle();
      expect(markerIn('media_suggested_candidate_2'), findsOneWidget);
      expect(markerIn('media_suggested_candidate_1'), findsNothing);
    });
  });

  group('Tagged on this photo', () {
    testWidgets('lists tags that are not the dive\'s sightings', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Tagged on this photo'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('media_tagged_remove_own-3')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('media_tagged_remove_sp_whale_shark')),
        findsNothing,
      );
    });

    testWidgets('removing in a sitting is held', (tester) async {
      final session = EditSession<PhotoRecord>(
        PhotoRecord(item: _photo(), species: const [_ownTag], people: const []),
      );
      addTearDown(session.dispose);
      await pump(tester, chips: const [_ownTag], sitting: session);
      await tester.tap(find.byKey(const ValueKey('media_tagged_remove_own-3')));
      await tester.pumpAndSettle();
      expect(tagging.untagged, isEmpty);
      expect(session.working.species, isEmpty);
    });

    testWidgets('with only sightings tagged it shows nothing', (tester) async {
      await pump(tester, chips: const [_whaleTag]);
      expect(find.text('Tagged on this photo'), findsNothing);
    });
  });
}
