import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/species_id/domain/entities/label_mode.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/label_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/identification_labels.dart';
import 'package:submersion/features/species_id/presentation/widgets/photo_identification_layer.dart';
import 'package:submersion/features/species_id/presentation/widgets/track_label_view.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../media/presentation/support/media_widget_harness.dart';
import '../data/identification_fixtures.dart';
import 'species_id_fakes.dart';

class _Tagging extends SpeciesTaggingService {
  _Tagging()
    : super(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      );
}

const _rockBeauty = Species(
  id: 'sp_rock_beauty',
  commonName: 'Rock Beauty',
  category: SpeciesCategory.fish,
);

const _parrotTag = SpeciesTagChip(
  speciesId: 'sp_queen_parrotfish',
  storedName: 'Queen Parrotfish',
  category: SpeciesCategory.fish,
  isBuiltIn: true,
);

/// [i] at [x], [y], a tenth of the photo on each side.
MediaIdentification _at(MediaIdentification i, double x, double y) =>
    i.copyWith(
      box: IdentificationBox(x: x, y: y, width: 0.1, height: 0.1),
    );

/// Name pills and dots over a photo (issue #4825).
void main() {
  late RecordingIdentificationService service;

  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    service = RecordingIdentificationService();
  });

  // A suggestion, a tag, a fish that looks like something, and one that
  // does not.
  final suggestion = _at(identification('s'), 0.1, 0.5);
  final tagged = _at(
    identification(
      't',
      decision: IdentificationDecision.accepted,
      decidedSpeciesId: 'sp_queen_parrotfish',
    ),
    0.6,
    0.5,
  );
  final unnamed = _at(
    identification('u').copyWith(suggestable: false, specific: true),
    0.35,
    0.2,
  );
  final vague = _at(
    identification('v').copyWith(suggestable: false, specific: false),
    0.8,
    0.1,
  );

  Finder pill(String id) => find.byKey(ValueKey('photo_label_pill_$id'));
  Finder dot(String id) => find.byKey(ValueKey('photo_label_dot_$id'));

  EditSession<PhotoRecord> openSitting() {
    final session = EditSession<PhotoRecord>(
      PhotoRecord(
        item: testMediaItem(id: 'm1'),
        species: const [],
        people: const [],
      ),
    );
    addTearDown(session.dispose);
    return session;
  }

  /// The layer over a 400 by 300 photo shown in a 400 by 300 box, zoomed
  /// by [zoom] the way the viewer's PhotoView zooms it: the whole box
  /// scaled from its top left.
  Future<void> pump(
    WidgetTester tester, {
    List<MediaIdentification>? found,
    LabelMode mode = LabelMode.names,
    double zoom = 1,
    EditSession<PhotoRecord>? sitting,
    bool editable = true,
    Size? imageSize = const Size(400, 300),
    double bottomInset = 0,
    Offset pan = Offset.zero,
    bool centred = false,
  }) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          photoDetectionsProvider('m1').overrideWith(
            (ref) async => found ?? [suggestion, tagged, unnamed, vague],
          ),
          mediaTagChipsProvider('m1').overrideWith((ref) => const [_parrotTag]),
          allSpeciesProvider.overrideWith((ref) async => const [_rockBeauty]),
          mediaIdentificationServiceProvider.overrideWithValue(service),
          speciesTaggingServiceProvider.overrideWithValue(_Tagging()),
          suggestionAcceptorProvider.overrideWithValue(FakeAcceptor()),
          labelModeNotifierProvider.overrideWith(
            (ref) => LabelModeNotifier.unstored(mode),
          ),
        ],
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: 300,
            // PhotoView pans, then zooms about the centre.
            child: Transform.translate(
              offset: pan,
              child: Transform.scale(
                scale: zoom,
                alignment: centred ? Alignment.center : Alignment.topLeft,
                child: PhotoIdentificationLayer(
                  item: testMediaItem(id: 'm1'),
                  imageSize: imageSize,
                  zoom: ValueNotifier((scale: zoom, position: pan)),
                  sitting: sitting,
                  editable: editable,
                  bottomInset: bottomInset,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names shows a pill on a suggestion and on a tag, and a dot '
      'on an unnamed animal that looks like something', (tester) async {
    await pump(tester);
    expect(pill('s'), findsOneWidget);
    expect(pill('t'), findsOneWidget);
    expect(find.text('Queen Parrotfish'), findsNWidgets(2));
    expect(dot('u'), findsOneWidget);
    expect(dot('v'), findsNothing);
  });

  testWidgets('all life dots a vague animal too', (tester) async {
    await pump(tester, mode: LabelMode.allLife);
    expect(dot('u'), findsOneWidget);
    expect(dot('v'), findsOneWidget);
    expect(pill('s'), findsOneWidget);
  });

  testWidgets('labels show where the models cannot run (issue #4876)', (
    tester,
  ) async {
    marineLifeIdEnabled = false;
    marineLifeLabelsShown = true;
    await pump(tester);
    expect(pill('s'), findsOneWidget);
    expect(pill('t'), findsOneWidget);
  });

  testWidgets('nothing shows in a build without the feature', (tester) async {
    marineLifeIdEnabled = false;
    marineLifeLabelsShown = false;
    await pump(tester);
    expect(find.byType(TrackPill), findsNothing);
  });

  testWidgets('off draws nothing', (tester) async {
    await pump(tester, mode: LabelMode.off);
    expect(find.byType(TrackPill), findsNothing);
    expect(find.byType(TrackDot), findsNothing);
  });

  testWidgets('a pill keeps its height on screen when the photo is zoomed', (
    tester,
  ) async {
    await pump(tester);
    final plain = tester.getRect(find.byType(TrackPill).first).height;
    await pump(tester, zoom: 2);
    final zoomed = tester.getRect(find.byType(TrackPill).first).height;
    expect(plain, closeTo(TrackLabelGeometry.pillHeight, 0.01));
    expect(zoomed, closeTo(plain, 0.01));
  });

  testWidgets('a label sits on its animal at any zoom', (tester) async {
    for (final zoom in [1.0, 2.0, 3.0]) {
      await pump(tester, zoom: zoom);
      // The unnamed animal's box centre, on screen: the photo fills the
      // 400 by 300 box, scaled from its top left.
      final centre = Offset(
        (0.35 + 0.05) * 400 * zoom,
        (0.2 + 0.05) * 300 * zoom,
      );
      final dotOnScreen = tester.getCenter(dot('u'));
      expect(dotOnScreen.dx, closeTo(centre.dx, 0.01), reason: 'zoom $zoom');
      expect(dotOnScreen.dy, closeTo(centre.dy, 0.01), reason: 'zoom $zoom');
    }
  });

  testWidgets('labels sit inside the photo where it is letterboxed', (
    tester,
  ) async {
    // A square photo in the 400 by 300 box: 300 wide, 50 in from each side.
    await pump(tester, imageSize: const Size(1000, 1000));
    final dotOnScreen = tester.getCenter(dot('u'));
    expect(dotOnScreen.dx, closeTo(50 + 0.4 * 300, 0.01));
    expect(dotOnScreen.dy, closeTo(0.25 * 300, 0.01));
  });

  testWidgets('locked, the labels take no taps', (tester) async {
    await pump(tester, sitting: openSitting(), editable: false);
    final context = tester.element(find.byType(IdentificationLabels));
    expect(
      identificationLabelTap(
        View.of(context).viewId,
        tester.getCenter(dot('u')),
      ),
      isFalse,
    );
  });

  testWidgets('unlocked, a dot names the animal and claims the detection', (
    tester,
  ) async {
    final session = openSitting();
    await pump(tester, sitting: session);
    final context = tester.element(find.byType(IdentificationLabels));
    expect(
      identificationLabelTap(
        View.of(context).viewId,
        tester.getCenter(dot('u')),
      ),
      isTrue,
    );
    await tester.pumpAndSettle();
    final picker = tester.widget<SpeciesPickerSheet>(
      find.byType(SpeciesPickerSheet),
    );
    picker.onSpeciesSelected(_rockBeauty, (
      abundance: SightingAbundance.seen,
      count: 1,
    ), '');
    await tester.pumpAndSettle();
    expect(service.claimed, [('m1', 'u', 'sp_rock_beauty')]);
    expect(session.working.species.map((c) => c.speciesId), ['sp_rock_beauty']);
  });

  testWidgets('zoomed in, a tap still finds the label under it', (
    tester,
  ) async {
    // Zoomed in two times, the animal is still in view.
    await pump(tester, sitting: openSitting(), zoom: 2);
    final context = tester.element(find.byType(IdentificationLabels));
    expect(
      identificationLabelTap(
        View.of(context).viewId,
        tester.getCenter(dot('u')),
      ),
      isTrue,
    );
  });

  testWidgets('a photo with a hundred detections draws them all', (
    tester,
  ) async {
    await pump(
      tester,
      mode: LabelMode.allLife,
      found: [
        for (var k = 0; k < 100; k++)
          identification('p$k').copyWith(
            suggestable: false,
            box: IdentificationBox(
              x: (k % 10) * 0.1,
              y: (k ~/ 10) * 0.1,
              width: 0.05,
              height: 0.05,
            ),
          ),
      ],
    );
    expect(find.byType(TrackDot), findsNWidgets(100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing is drawn before the photo\'s size is known', (
    tester,
  ) async {
    await pump(tester, imageSize: null, mode: LabelMode.allLife);
    expect(find.byType(TrackDot), findsNothing);
    expect(find.byType(TrackPill), findsNothing);
  });

  testWidgets('nothing is drawn with the feature off', (tester) async {
    marineLifeIdEnabled = false;
    await pump(tester, mode: LabelMode.allLife);
    expect(find.byType(TrackDot), findsNothing);
  });

  group('above the controls (issue #4825)', () {
    /// The pill drawn, inside its larger touch target.
    Rect drawn(WidgetTester tester, String id) => tester.getRect(
      find.descendant(of: pill(id), matching: find.byType(TrackPill)),
    );

    // An animal near the photo's foot, under 100 of controls.
    final low = _at(identification('low'), 0.45, 0.85);

    testWidgets('a pill keeps above them', (tester) async {
      await pump(tester, found: [low], bottomInset: 100);
      expect(drawn(tester, 'low').bottom, lessThanOrEqualTo(200.5));
    });

    testWidgets('zoomed and panned, a pill still keeps above them', (
      tester,
    ) async {
      await pump(
        tester,
        // On screen near 260 down: under the controls' edge at 200.
        found: [_at(identification('low'), 0.45, 0.75)],
        bottomInset: 100,
        zoom: 2,
        centred: true,
        pan: const Offset(0, -40),
      );
      expect(drawn(tester, 'low').bottom, lessThanOrEqualTo(200.5));
    });

    testWidgets('with no controls a pill goes where it would', (tester) async {
      await pump(tester, found: [low]);
      expect(drawn(tester, 'low').bottom, greaterThan(200.5));
    });
  });
}
