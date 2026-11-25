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

/// A species tag's crops on a locked photo or video (issue #5024).
class _Identifications extends MediaIdentificationRepository {
  _Identifications(this.rows);

  final List<MediaIdentification> rows;

  @override
  Future<List<MediaIdentification>> forMedia(String mediaId) async => rows;
}

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
              onPressed: () =>
                  openSpeciesCrops(context, ref, item: item, chip: grunt),
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
          _Identifications(rows),
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
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

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
}
