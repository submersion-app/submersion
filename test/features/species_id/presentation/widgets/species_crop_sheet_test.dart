import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/species_id/data/services/identification_crop_store.dart';
import 'package:submersion/features/species_id/data/repositories/media_identification_repository.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/species_crop_sheet.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../media/presentation/support/media_widget_harness.dart';
import '../../domain/identification_rules_fixtures.dart';
import '../species_id_fakes.dart';

/// A 1x1 PNG: a crop that decodes.
final _pixel = Uint8List.fromList(
  base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  ),
);

const grunt = SpeciesTagChip(
  speciesId: 'sp_grunt',
  storedName: 'French Grunt',
  category: SpeciesCategory.fish,
  isBuiltIn: false,
);

MediaIdentification gruntAt(String id, double x) => ruleId(
  id,
  decision: IdentificationDecision.accepted,
  decidedSpeciesId: 'sp_grunt',
  box: IdentificationBox(x: x, y: 0.2, width: 0.1, height: 0.1),
);

/// Pumps a viewer whose "open" button opens [grunt]'s crops on photo p1,
/// with [rows] as its identifications.
Future<void> pumpOpener(
  WidgetTester tester, {
  required List<MediaIdentification> rows,
  MediaType type = MediaType.photo,
  List<dynamic> extra = const [],
  Set<String> missing = const {},
  MediaIdentificationRepository? repository,
  int taps = 1,
  ValueChanged<Duration>? onMoment,
}) async {
  final overrides = await getBaseOverrides();
  final item = testMediaItem(id: 'p1', diveId: 'd1', mediaType: type);
  final router = GoRouter(
    initialLocation: '/viewer',
    routes: [
      GoRoute(
        path: '/viewer',
        builder: (_, _) => Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => openSpeciesCrops(
                context,
                ref,
                item: item,
                chip: grunt,
                onMoment: onMoment,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/species/:id',
        builder: (_, state) =>
            Scaffold(body: Text('DETAIL ${state.pathParameters['id']}')),
      ),
    ],
  );
  await tester.pumpWidget(
    testAppRouter(
      router: router,
      locale: const Locale('en'),
      overrides: [
        ...overrides,
        mediaIdentificationRepositoryProvider.overrideWithValue(
          repository ?? FixedIdentifications(rows),
        ),
        identificationCropProvider.overrideWith(
          (ref, key) async =>
              missing.contains(key.$2) ? null : CropBytes(_pixel),
        ),
        speciesProvider('sp_grunt').overrideWith(
          (ref) async => const Species(
            id: 'sp_grunt',
            commonName: 'French Grunt',
            scientificName: 'Haemulon flavolineatum',
            category: SpeciesCategory.fish,
          ),
        ),
        ...extra,
      ],
    ),
  );
  await tester.pumpAndSettle();
  for (var i = 0; i < taps; i++) {
    await tester.tap(find.text('open'));
  }
  await tester.pumpAndSettle();
}

/// A logbook whose read waits for [answer], as a slow one does.
class _SlowIdentifications extends MediaIdentificationRepository {
  final answer = Completer<List<MediaIdentification>>();

  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) => answer.future;
}

/// A logbook whose read fails.
class _FailingIdentifications extends MediaIdentificationRepository {
  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) async =>
      throw StateError('logbook closed');
}

/// A species tag's crops on a locked photo or video (issue #5024).
void main() {
  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
  });

  group('opening', () {
    testWidgets('with no crop the tag opens the species page', (tester) async {
      await pumpOpener(tester, rows: const []);
      expect(find.text('DETAIL sp_grunt'), findsOneWidget);
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsNothing);
    });

    testWidgets('with labels off the tag opens the species page', (
      tester,
    ) async {
      marineLifeIdEnabled = false;
      await pumpOpener(tester, rows: [gruntAt('a', 0.1)]);
      expect(find.text('DETAIL sp_grunt'), findsOneWidget);
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsNothing);
    });

    testWidgets('when the read fails the tag opens the species page', (
      tester,
    ) async {
      await pumpOpener(
        tester,
        rows: const [],
        repository: _FailingIdentifications(),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('DETAIL sp_grunt'), findsOneWidget);
    });

    testWidgets('a second tap while the first is opening is ignored', (
      tester,
    ) async {
      final slow = _SlowIdentifications();
      await pumpOpener(tester, rows: const [], repository: slow, taps: 2);
      slow.answer.complete([gruntAt('a', 0.1)]);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsOneWidget);
    });

    testWidgets('with a crop the sheet opens', (tester) async {
      await pumpOpener(tester, rows: [gruntAt('a', 0.1)]);
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsOneWidget);
      expect(find.text('DETAIL sp_grunt'), findsNothing);
    });
  });

  group('the sheet', () {
    Finder large() => find.byKey(const ValueKey('species_crop_large'));

    String largeId(WidgetTester tester) => tester
        .widget<IdentificationCrop>(
          find.descendant(
            of: large(),
            matching: find.byType(IdentificationCrop),
          ),
        )
        .identificationId;

    testWidgets('shows the name, the scientific name and the crop large', (
      tester,
    ) async {
      await pumpOpener(tester, rows: [gruntAt('a', 0.1)]);
      expect(find.text('French Grunt'), findsOneWidget);
      expect(find.text('Haemulon flavolineatum'), findsOneWidget);
      expect(largeId(tester), 'a');
      expect(
        find.descendant(of: large(), matching: find.byType(Image)),
        findsOneWidget,
      );
    });

    testWidgets('one crop shows no count and no thumbnails', (tester) async {
      await pumpOpener(tester, rows: [gruntAt('a', 0.1)]);
      expect(find.byKey(const ValueKey('species_crop_thumbs')), findsNothing);
      expect(find.textContaining('in this photo'), findsNothing);
    });

    testWidgets('three crops show the count and thumbnails; tapping one '
        'shows it large', (tester) async {
      await pumpOpener(
        tester,
        rows: [gruntAt('c', 0.8), gruntAt('a', 0.1), gruntAt('b', 0.4)],
      );
      expect(find.text('3 in this photo'), findsOneWidget);
      expect(find.byKey(const ValueKey('species_crop_thumbs')), findsOneWidget);
      expect(largeId(tester), 'a');
      await tester.tap(find.byKey(const ValueKey('species_crop_thumb_c')));
      await tester.pumpAndSettle();
      expect(largeId(tester), 'c');
    });

    testWidgets('a screen reader can pick a thumbnail', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpOpener(tester, rows: [gruntAt('a', 0.1), gruntAt('b', 0.4)]);
      tester.semantics.tap(find.semantics.byLabel('Image 2 of 2'));
      await tester.pumpAndSettle();
      expect(largeId(tester), 'b');
      semantics.dispose();
    });

    testWidgets('a video says video', (tester) async {
      MediaIdentification track(String id, int startMs) =>
          gruntAt(id, 0.1).copyWith(
            startMs: () => startMs,
            endMs: () => startMs + 500,
            bestMs: () => startMs,
          );
      await pumpOpener(
        tester,
        type: MediaType.video,
        rows: [track('a', 1000), track('b', 2000), track('c', 3000)],
      );
      expect(find.text('3 in this video'), findsOneWidget);
    });

    testWidgets('a crop not on this device shows the placeholder', (
      tester,
    ) async {
      await pumpOpener(
        tester,
        rows: [gruntAt('a', 0.1), gruntAt('b', 0.4)],
        missing: {'b'},
      );
      expect(find.text('Image not on this device'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('species_crop_thumb_b')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: large(),
          matching: find.text('Image not on this device'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Species page closes the sheet and opens the page; Back '
        'returns to the viewer', (tester) async {
      await pumpOpener(tester, rows: [gruntAt('a', 0.1)]);
      await tester.tap(find.byKey(const ValueKey('species_crop_species_page')));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL sp_grunt'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget);
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsNothing);
    });

    testWidgets('thirty crops scroll in one row at phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpOpener(
        tester,
        rows: [for (var i = 0; i < 30; i++) gruntAt('f$i', i / 30)],
      );
      expect(tester.takeException(), isNull);
      expect(find.text('30 in this photo'), findsOneWidget);
      final row = tester.widget<ListView>(
        find.byKey(const ValueKey('species_crop_thumbs')),
      );
      expect(row.scrollDirection, Axis.horizontal);
    });
  });

  group('a video (issue #5032)', () {
    /// A grunt followed from [start] to [end] ms, with a box of [area].
    MediaIdentification gruntTrack(
      String id,
      int start,
      int end, {
      int area = 100,
    }) => gruntAt(id, 0.1).copyWith(
      startMs: () => start,
      endMs: () => end,
      bestMs: () => start,
      boxPixelWidth: area,
      boxPixelHeight: 1,
    );

    Future<void> pumpVideo(
      WidgetTester tester,
      List<MediaIdentification> rows, {
      required Set<String> present,
      ValueChanged<Duration>? onMoment,
    }) => pumpOpener(
      tester,
      rows: rows,
      type: MediaType.video,
      onMoment: onMoment,
      extra: [presentCropIdsProvider.overrideWith((ref, _) async => present)],
    );

    Finder thumbs() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('species_crop_thumb_'),
    );

    Finder moments() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('species_crop_moment_'),
    );

    testWidgets('shows the kept crops and 3 best of 5 sightings', (
      tester,
    ) async {
      await pumpVideo(
        tester,
        [
          for (var k = 0; k < 5; k++)
            gruntTrack('t$k', k * 1000, k * 1000 + 500),
        ],
        present: {'t0', 't2', 't4'},
        onMoment: (_) {},
      );
      expect(thumbs(), findsNWidgets(3));
      expect(find.text('3 best of 5 sightings'), findsOneWidget);
    });

    testWidgets('tapping a time chip closes the sheet and reports the '
        'moment', (tester) async {
      Duration? reported;
      await pumpVideo(
        tester,
        [gruntTrack('a', 4000, 9000), gruntTrack('b', 30000, 31000)],
        present: {'a', 'b'},
        onMoment: (at) => reported = at,
      );
      expect(find.text('Seen at'), findsOneWidget);
      expect(find.text('0:04 to 0:09'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('species_crop_moment_4000')));
      await tester.pumpAndSettle();
      expect(reported, const Duration(milliseconds: 4000));
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsNothing);
    });

    testWidgets('a track under a second is one time', (tester) async {
      await pumpVideo(
        tester,
        [gruntTrack('a', 12000, 12400)],
        present: {'a'},
        onMoment: (_) {},
      );
      expect(find.text('0:12'), findsOneWidget);
    });

    testWidgets('without a way to jump there are no time chips', (
      tester,
    ) async {
      await pumpVideo(tester, [gruntTrack('a', 4000, 9000)], present: {'a'});
      expect(moments(), findsNothing);
      expect(find.text('Seen at'), findsNothing);
    });

    testWidgets('a sheet whose tracks lost their crops still opens', (
      tester,
    ) async {
      await pumpVideo(
        tester,
        [
          for (var k = 0; k < 5; k++)
            gruntTrack('t$k', k * 1000, k * 1000 + 500),
        ],
        present: const {},
        onMoment: (_) {},
      );
      expect(find.byKey(const ValueKey('species_crop_sheet')), findsOneWidget);
      expect(find.byKey(const ValueKey('species_crop_large')), findsOneWidget);
      expect(find.text('5 in this video'), findsOneWidget);
    });

    testWidgets('15 stretches wrap on a phone without overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpVideo(
        tester,
        [
          for (var k = 0; k < 15; k++)
            gruntTrack('t$k', k * 4000, k * 4000 + 1500),
        ],
        present: {'t0'},
        onMoment: (_) {},
      );
      expect(tester.takeException(), isNull);
      expect(moments(), findsNWidgets(15));
    });

    testWidgets('an hour-long video reads 1:02:05', (tester) async {
      await pumpVideo(
        tester,
        [gruntTrack('a', 3725000, 3730000)],
        present: {'a'},
        onMoment: (_) {},
      );
      expect(find.text('1:02:05 to 1:02:10'), findsOneWidget);
    });
  });
}
