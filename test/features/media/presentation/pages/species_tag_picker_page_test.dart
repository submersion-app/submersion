import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/species_tag_candidate_group.dart';
import 'package:submersion/features/media/presentation/pages/species_tag_picker_page.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';

import '../support/media_widget_harness.dart';

/// Records what the page asks to tag instead of touching a database.
class _RecordingTaggingService extends SpeciesTaggingService {
  _RecordingTaggingService()
    : super(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      );

  final List<String> taggedIds = [];
  String? taggedSpecies;

  @override
  Future<TagPhotosResult> tagPhotos({
    required List<String> mediaIds,
    required String speciesId,
  }) async {
    taggedIds.addAll(mediaIds);
    taggedSpecies = speciesId;
    return TagPhotosResult(tagged: mediaIds.length);
  }
}

List<SpeciesTagCandidateGroup> _groups() => [
  SpeciesTagCandidateGroup(
    diveId: 'd2',
    diveNumber: 102,
    diveDateTime: DateTime(2024, 3, 5),
    siteName: null,
    sightingId: 'sg2',
    items: [testMediaItem(id: 'p4', diveId: 'd2')],
  ),
  SpeciesTagCandidateGroup(
    diveId: 'd1',
    diveNumber: 101,
    diveDateTime: DateTime(2024, 1, 10),
    siteName: 'Blue Hole',
    sightingId: 'sg1',
    items: [
      testMediaItem(id: 'p2', diveId: 'd1'),
      testMediaItem(id: 'p3', diveId: 'd1'),
    ],
  ),
];

/// Opens the picker from a button so the popped value can be captured.
Future<TagPhotosResult? Function()> _open(
  WidgetTester tester,
  List<SpeciesTagCandidateGroup> groups,
  _RecordingTaggingService service,
) async {
  TagPhotosResult? popped;
  // Three-column tiles are large; a tall surface keeps every group above
  // the bottom bar so taps land on the tiles.
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    await mediaTestApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popped = await Navigator.of(context).push<TagPhotosResult>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const SpeciesTagPickerPage(speciesId: 'sp_x'),
                  ),
                );
              },
              child: const Text('OPEN'),
            ),
          ),
        ),
      ),
      overrides: [
        speciesTagCandidatesProvider(
          'sp_x',
        ).overrideWith((ref) async => groups),
        speciesTaggingServiceProvider.overrideWithValue(service),
      ],
    ),
  );
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return () => popped;
}

void main() {
  testWidgets('groups candidates by dive with a header per dive', (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    await _open(tester, _groups(), service);

    expect(find.byType(MediaThumbnailTile), findsNWidgets(3));
    expect(find.textContaining('Dive 102'), findsOneWidget);
    expect(find.textContaining('Blue Hole'), findsOneWidget);
    expect(find.textContaining('Unknown site'), findsOneWidget);
  });

  testWidgets('the confirm button counts the selection and tags it', (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    final read = await _open(tester, _groups(), service);

    final confirm = find.byKey(const ValueKey('tag_picker_confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byType(MediaThumbnailTile).at(1));
    await tester.tap(find.byType(MediaThumbnailTile).at(2));
    await tester.pump();
    expect(find.text('Tag 2 photos'), findsOneWidget);

    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(service.taggedSpecies, 'sp_x');
    expect(service.taggedIds.toSet(), {'p2', 'p3'});
    expect(read()?.tagged, 2);
  });

  testWidgets('Select all checks every candidate across groups', (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    await _open(tester, _groups(), service);

    await tester.tap(find.byKey(const ValueKey('tag_picker_select_all')));
    await tester.pump();

    expect(find.text('Tag 3 photos'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing is left to tag', (
    tester,
  ) async {
    final service = _RecordingTaggingService();
    await _open(tester, const [], service);

    expect(
      find.text('No untagged photos on dives where you logged this species.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('tag_picker_confirm')), findsNothing);
  });
}
