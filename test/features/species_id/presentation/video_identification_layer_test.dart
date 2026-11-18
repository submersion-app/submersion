import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_sheet.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/track_label_view.dart';
import 'package:submersion/features/species_id/presentation/widgets/video_identification_layer.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../media/presentation/support/media_widget_harness.dart';
import '../data/identification_fixtures.dart';
import 'species_id_fakes.dart';

/// Name pills and dots over a video (issue #4675).
class _Tagging extends SpeciesTaggingService {
  _Tagging()
    : super(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      );

  final tagged = <String>[];

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
}

/// [t] moved down to [y].
MediaIdentification at(MediaIdentification t, double y) => t.copyWith(
  path: [for (final s in t.path) s.copyWith(box: s.box.copyWith(y: y))],
);

const _rockBeautyTag = SpeciesTagChip(
  speciesId: 'sp_rock_beauty',
  storedName: 'Rock Beauty',
  category: SpeciesCategory.fish,
  isBuiltIn: false,
);

const _rockBeauty = Species(
  id: 'sp_rock_beauty',
  commonName: 'Rock Beauty',
  category: SpeciesCategory.fish,
);

void main() {
  late RecordingIdentificationService service;
  late _Tagging tagging;
  late ValueNotifier<VideoPlayerValue> playback;

  setUp(() {
    marineLifeIdEnabled = true;
    service = RecordingIdentificationService();
    tagging = _Tagging();
    playback = ValueNotifier(
      const VideoPlayerValue(
        duration: Duration(seconds: 25),
        size: Size(1920, 1080),
        position: Duration(milliseconds: 1500),
        isInitialized: true,
      ),
    );
  });
  tearDown(() {
    resetMarineLifeIdEnabled();
    playback.dispose();
  });

  final confident = track('a', confident: true);
  final suggestion = at(track('b', confident: false), 0.1);
  final unnamed = at(track('c', suggestable: false, confident: false), 0.7);

  var playerTaps = 0;

  Future<void> pump(
    WidgetTester tester, {
    List<MediaIdentification>? tracks,
    List<SpeciesTagChip> chips = const [],
    bool tagsLoading = false,
    bool playing = false,
    bool editable = true,
    EditSession<PhotoRecord>? sitting,
  }) async {
    playerTaps = 0;
    playback.value = playback.value.copyWith(isPlaying: playing);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          videoTracksProvider('v1').overrideWith(
            (ref) async => tracks ?? [confident, suggestion, unnamed],
          ),
          mediaTagChipsProvider('v1').overrideWith(
            (ref) =>
                tagsLoading ? Completer<List<SpeciesTagChip>>().future : chips,
          ),
          allSpeciesProvider.overrideWith((ref) async => const [_rockBeauty]),
          mediaIdentificationServiceProvider.overrideWithValue(service),
          speciesTaggingServiceProvider.overrideWithValue(tagging),
          suggestionAcceptorProvider.overrideWithValue(FakeAcceptor()),
          identificationCropFileProvider.overrideWith((ref, key) async => null),
        ],
        child: Center(
          child: SizedBox.square(
            dimension: 400,
            // The player under the labels, as in the viewer: a tap
            // anywhere plays or pauses.
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => playerTaps++,
                ),
                VideoIdentificationLayer(
                  playback: playback,
                  item: testMediaItem(id: 'v1', mediaType: MediaType.video),
                  sitting: sitting,
                  editable: editable,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The unlocked video's sitting, which a name picked on a label is held
  /// in until Save (issue #4527).
  EditSession<PhotoRecord> openSitting() {
    final session = EditSession<PhotoRecord>(
      PhotoRecord(
        item: testMediaItem(id: 'v1', mediaType: MediaType.video),
        species: const [],
        people: const [],
      ),
    );
    addTearDown(session.dispose);
    return session;
  }

  Finder pill(String id) => find.byKey(ValueKey('video_label_pill_$id'));
  Finder dot(String id) => find.byKey(ValueKey('video_label_dot_$id'));

  testWidgets('playing shows only the confident pill', (tester) async {
    await pump(tester, playing: true);
    expect(pill('a'), findsOneWidget);
    expect(find.text('Queen Parrotfish'), findsOneWidget);
    expect(pill('b'), findsNothing);
    expect(dot('c'), findsNothing);
  });

  testWidgets('paused shows suggestion pills and dots', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, sitting: openSitting());
    expect(pill('a'), findsOneWidget);
    expect(pill('b'), findsOneWidget);
    expect(dot('c'), findsOneWidget);
    expect(find.bySemanticsLabel('Unnamed fish, tap to name'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a dot needs a crop that looks like something', (tester) async {
    await pump(
      tester,
      tracks: [
        at(
          track('c', suggestable: false, confident: false, specific: false),
          0.7,
        ),
      ],
    );
    expect(dot('c'), findsNothing);
  });

  testWidgets('an accepted track shows a filled pill with the tagged name', (
    tester,
  ) async {
    await pump(
      tester,
      tracks: [
        track(
          'a',
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp_rock_beauty',
        ),
      ],
      chips: const [_rockBeautyTag],
      playing: true,
    );
    expect(find.text('Rock Beauty'), findsOneWidget);
    expect(find.text('Queen Parrotfish'), findsNothing);
  });

  testWidgets('a tagged fish keeps its pill while the tags load', (
    tester,
  ) async {
    await pump(
      tester,
      tracks: [
        track(
          'a',
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp_rock_beauty',
        ),
      ],
      tagsLoading: true,
      playing: true,
    );
    expect(find.text('Rock Beauty'), findsOneWidget);
  });

  testWidgets('a tag shown on the video changes the labels before it is '
      'stored', (tester) async {
    await pump(
      tester,
      tracks: [
        at(
          track(
            'c',
            suggestable: false,
            confident: false,
            claimedSpeciesId: 'sp_rock_beauty',
          ),
          0.7,
        ),
      ],
      chips: const [_rockBeautyTag],
    );
    expect(dot('c'), findsNothing);
    expect(find.text('Rock Beauty'), findsOneWidget);
  });

  testWidgets('tapping a dot opens the picker, claims the track and holds '
      'the tag', (tester) async {
    final session = openSitting();
    await pump(tester, sitting: session);
    await tester.tap(dot('c'));
    await tester.pumpAndSettle();
    final picker = tester.widget<SpeciesPickerSheet>(
      find.byType(SpeciesPickerSheet),
    );
    picker.onSpeciesSelected(_rockBeauty, (
      abundance: SightingAbundance.seen,
      count: 1,
    ), '');
    await tester.pumpAndSettle();
    expect(service.claimed, [('v1', 'c', 'sp_rock_beauty')]);
    expect(tagging.tagged, isEmpty);
    expect(session.working.species.map((c) => c.speciesId), ['sp_rock_beauty']);
  });

  testWidgets('with no sitting the labels take no taps', (tester) async {
    await pump(tester);
    await tester.tap(dot('c'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesPickerSheet), findsNothing);
  });

  testWidgets('tapping a pill opens its crop view with Other species and '
      'Dismiss', (tester) async {
    await pump(tester, sitting: openSitting());
    await tester.tap(pill('b'));
    await tester.pumpAndSettle();
    expect(find.text('Other species...'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('video_label_dismiss')));
    await tester.pumpAndSettle();
    expect(service.rejected.single.$1, 'v1');
    expect(service.rejected.single.$2, ['b']);
  });

  testWidgets('Add in a pill\'s crop view claims that fish', (tester) async {
    await pump(tester, sitting: openSitting());
    await tester.tap(pill('b'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('media_suggested_candidate_2393681')),
        matching: find.text('Add'),
      ),
    );
    await tester.pumpAndSettle();
    expect(service.claimed.single.$2, 'b');
  });

  testWidgets('a locked video draws labels but ignores taps', (tester) async {
    await pump(tester, editable: false);
    expect(pill('b'), findsOneWidget);
    await tester.tap(pill('b'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Other species...'), findsNothing);
    // The tap went through to the player.
    expect(playerTaps, 1);
  });

  testWidgets('a tap away from the labels plays or pauses', (tester) async {
    await pump(tester);
    final layer = tester.getRect(find.byType(VideoIdentificationLayer));
    await tester.tapAt(layer.bottomRight - const Offset(10, 120));
    await tester.pumpAndSettle();
    expect(playerTaps, 1);
    expect(find.text('Other species...'), findsNothing);
  });

  testWidgets('on a locked video a dot does not offer to name the fish', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, editable: false);
    expect(find.bySemanticsLabel('Unnamed fish'), findsOneWidget);
    expect(find.bySemanticsLabel('Unnamed fish, tap to name'), findsNothing);
    semantics.dispose();
  });

  testWidgets('labels follow a sitting\'s held tags, and Cancel puts them '
      'back', (tester) async {
    final session = EditSession<PhotoRecord>(
      PhotoRecord(
        item: testMediaItem(id: 'v1', mediaType: MediaType.video),
        species: const [],
        people: const [],
      ),
    );
    addTearDown(session.dispose);
    await pump(
      tester,
      tracks: [
        at(
          track(
            'c',
            suggestable: false,
            confident: false,
            claimedSpeciesId: 'sp_rock_beauty',
          ),
          0.7,
        ),
      ],
      sitting: session,
    );
    expect(dot('c'), findsOneWidget);
    holdPickedSpecies(session, _rockBeauty);
    await tester.pumpAndSettle();
    expect(dot('c'), findsNothing);
    expect(find.text('Rock Beauty'), findsOneWidget);
    session.set(photoSpeciesField, SpeciesTagEdits.none);
    await tester.pumpAndSettle();
    expect(dot('c'), findsOneWidget);
  });

  testWidgets('nothing is drawn with the flag off', (tester) async {
    marineLifeIdEnabled = false;
    await pump(tester);
    expect(pill('a'), findsNothing);
    expect(dot('c'), findsNothing);
  });

  testWidgets('a pill is as wide as its name, not the space it has', (
    tester,
  ) async {
    await pump(
      tester,
      tracks: [
        track(
          'a',
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp_rock_beauty',
        ),
      ],
      chips: const [_rockBeautyTag],
      playing: true,
    );
    final pillWidth = tester
        .getSize(
          find.descendant(of: pill('a'), matching: find.byType(TrackPill)),
        )
        .width;
    final textWidth = tester.getSize(find.text('Rock Beauty')).width;
    // 12 of padding and 1.5 of border each side.
    expect(pillWidth, closeTo(textWidth + 27, 1));
  });

  testWidgets('a pill pushed in from the edge still sits over its dot', (
    tester,
  ) async {
    final nearEdge = track(
      'a',
      decision: IdentificationDecision.accepted,
      decidedSpeciesId: 'sp_rock_beauty',
    );
    await pump(
      tester,
      tracks: [
        nearEdge.copyWith(
          path: [
            for (final s in nearEdge.path)
              s.copyWith(box: s.box.copyWith(x: 0, width: 0.06)),
          ],
        ),
      ],
      chips: const [_rockBeautyTag],
      playing: true,
    );
    final layer = tester.getRect(find.byType(VideoIdentificationLayer));
    final pillRect = tester.getRect(
      find.descendant(of: pill('a'), matching: find.byType(TrackPill)),
    );
    final dotX = layer.left + 0.03 * 400;
    expect(pillRect.left, lessThanOrEqualTo(dotX));
    expect(pillRect.right, greaterThanOrEqualTo(dotX));
    expect(pillRect.left, greaterThanOrEqualTo(layer.left));
  });

  testWidgets('a pill with room is centred on its dot', (tester) async {
    await pump(
      tester,
      tracks: [
        track(
          'a',
          decision: IdentificationDecision.accepted,
          decidedSpeciesId: 'sp_rock_beauty',
        ),
      ],
      chips: const [_rockBeautyTag],
      playing: true,
    );
    final layer = tester.getRect(find.byType(VideoIdentificationLayer));
    final pillRect = tester.getRect(
      find.descendant(of: pill('a'), matching: find.byType(TrackPill)),
    );
    // At 1.5 s the fish is at x 0.12, 0.2 wide: its centre is 0.22.
    expect(pillRect.center.dx, closeTo(layer.left + 0.22 * 400, 0.5));
  });

  testWidgets('a fish filling the frame keeps its pill inside the video', (
    tester,
  ) async {
    final tall = track('a', confident: true);
    await pump(
      tester,
      tracks: [
        tall.copyWith(
          path: [
            for (final s in tall.path)
              s.copyWith(box: s.box.copyWith(y: 0.02, height: 0.96)),
          ],
        ),
      ],
      playing: true,
    );
    final layer = tester.getRect(find.byType(VideoIdentificationLayer));
    final videoBottom = layer.top + 87.5 + 225;
    final pillRect = tester.getRect(
      find.descendant(of: pill('a'), matching: find.byType(TrackPill)),
    );
    expect(pillRect.bottom, lessThanOrEqualTo(videoBottom + 0.5));
  });

  testWidgets('labels sit inside the contain-fitted video rect', (
    tester,
  ) async {
    await pump(tester);
    // 16:9 in a 400 square: 400 by 225, from y 87.5. The fish at 1.5 s is
    // at x 0.12, y 0.7, 0.2 by 0.1, so its centre is (88, 87.5 + 0.75 * 225).
    final origin = tester.getTopLeft(find.byType(VideoIdentificationLayer));
    final centre = tester.getCenter(dot('c')) - origin;
    expect(centre.dx, closeTo(88, 0.5));
    expect(centre.dy, closeTo(87.5 + 0.75 * 225, 0.5));
  });
}
