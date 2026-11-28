import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_chips_row.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_list_sheet.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../species_id/domain/identification_rules_fixtures.dart'
    show ruleId;
import '../../../species_id/presentation/species_id_fakes.dart';
import '../support/media_widget_harness.dart';

/// On a locked photo or video a species tag opens what the species looks
/// like there: its crops (issue #5024).
void main() {
  const tag = SpeciesTagChip(
    speciesId: 'sp_grunt',
    storedName: 'French Grunt',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
  );
  const appTag = SpeciesTagChip(
    speciesId: 'sp_fan',
    storedName: 'Common Sea Fan',
    category: SpeciesCategory.coral,
    isBuiltIn: false,
    unconfirmed: true,
  );
  const handTag = SpeciesTagChip(
    speciesId: 'sp_hand',
    storedName: 'Blue Tang',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
  );

  MediaIdentification accepted(String id, String speciesId) => ruleId(
    id,
    decision: IdentificationDecision.accepted,
    decidedSpeciesId: speciesId,
  );

  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
  });

  Future<void> pump(
    WidgetTester tester, {
    required bool locked,
    VoidCallback? onSuggestionTap,
    MediaType type = MediaType.photo,
    ValueChanged<Duration>? onMoment,
    bool throughList = false,
    List<MediaIdentification>? rows,
  }) async {
    final overrides = await getBaseOverrides();
    final item = testMediaItem(id: 'p1', diveId: 'd1', mediaType: type);
    final router = GoRouter(
      initialLocation: '/viewer',
      routes: [
        GoRoute(
          path: '/viewer',
          builder: (_, _) => Scaffold(
            body: throughList
                ? Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showMediaSpeciesListSheet(
                        context,
                        item,
                        onMoment: onMoment,
                      ),
                      child: const Text('list'),
                    ),
                  )
                : MediaSpeciesChipsRow(
                    mediaId: 'p1',
                    item: item,
                    tagsOpenCrops: locked,
                    onSuggestionTap: onSuggestionTap,
                    onMoment: onMoment,
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
          mediaTagChipsProvider(
            'p1',
          ).overrideWith((ref) async => const [tag, appTag, handTag]),
          mediaSuggestionsProvider('p1').overrideWith(
            (ref) async => <SpeciesSuggestion>[
              suggestion(chromis, score: 0.71),
            ],
          ),
          recordedNearbyListProvider.overrideWith(
            (ref, request) async => const NearbySpecies(speciesKeys: {}),
          ),
          mediaIdentificationRepositoryProvider.overrideWithValue(
            FixedIdentifications(
              rows ?? [accepted('a', 'sp_grunt'), accepted('b', 'sp_fan')],
            ),
          ),
          identificationCropProvider.overrideWith((ref, key) async => null),
          presentCropIdsProvider.overrideWith((ref, _) async => const {}),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  final sheet = find.byKey(const ValueKey('species_crop_sheet'));

  group('a video (issue #5032)', () {
    final seen = [
      accepted(
        'a',
        'sp_grunt',
      ).copyWith(startMs: () => 4000, endMs: () => 9000, bestMs: () => 5000),
    ];

    testWidgets('a time on the crop sheet plays the video from there', (
      tester,
    ) async {
      Duration? played;
      await pump(
        tester,
        locked: true,
        type: MediaType.video,
        rows: seen,
        onMoment: (at) => played = at,
      );
      await tester.tap(find.text('French Grunt'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('species_crop_moment_4000')));
      await tester.pumpAndSettle();
      expect(played, const Duration(seconds: 4));
      expect(sheet, findsNothing);
    });

    testWidgets('from the whole list, a time closes both sheets', (
      tester,
    ) async {
      Duration? played;
      await pump(
        tester,
        locked: true,
        type: MediaType.video,
        rows: seen,
        throughList: true,
        onMoment: (at) => played = at,
      );
      await tester.tap(find.text('list'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('French Grunt'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('species_crop_moment_4000')));
      await tester.pumpAndSettle();
      expect(played, const Duration(seconds: 4));
      expect(sheet, findsNothing);
      expect(
        find.byKey(const ValueKey('media_species_list_sheet')),
        findsNothing,
      );
    });
  });

  group('locked', () {
    testWidgets('a tag opens its crops', (tester) async {
      await pump(tester, locked: true);
      await tester.tap(find.text('French Grunt'));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
      expect(find.text('DETAIL sp_grunt'), findsNothing);
    });

    testWidgets("the app's tag opens its crops too", (tester) async {
      await pump(tester, locked: true);
      await tester.tap(find.text('Common Sea Fan'));
      await tester.pumpAndSettle();
      expect(sheet, findsOneWidget);
    });

    testWidgets('a tag added by hand opens its species page', (tester) async {
      await pump(tester, locked: true);
      await tester.tap(find.text('Blue Tang'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL sp_hand'), findsOneWidget);
      expect(sheet, findsNothing);
    });

    testWidgets('a suggestion stays inert', (tester) async {
      await pump(tester, locked: true);
      await tester.tap(find.text('Brown Chromis'));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      expect(find.textContaining('DETAIL'), findsNothing);
    });
  });

  group('unlocked', () {
    testWidgets('a tag still opens its species page', (tester) async {
      await pump(tester, locked: false, onSuggestionTap: () {});
      await tester.tap(find.text('French Grunt'));
      await tester.pumpAndSettle();
      expect(find.text('DETAIL sp_grunt'), findsOneWidget);
      expect(sheet, findsNothing);
    });

    testWidgets("the app's tag still opens the species sheet", (tester) async {
      var opened = 0;
      await pump(tester, locked: false, onSuggestionTap: () => opened++);
      await tester.tap(find.text('Common Sea Fan'));
      await tester.pumpAndSettle();
      expect(opened, 1);
      expect(sheet, findsNothing);
    });
  });
}
