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
}) async {
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
      child: MediaSpeciesSheet(item: item),
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

  testWidgets('toggling a chip tags or untags the photo', (tester) async {
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

    await tester.tap(find.widgetWithText(FilterChip, 'My Nudibranch'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilterChip, 'Whale Shark'));
    await tester.pump();

    expect(service.tagged, [('p1', 'c1')]);
    expect(service.untagged, [('p1', 'sp_whale_shark')]);
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
}
