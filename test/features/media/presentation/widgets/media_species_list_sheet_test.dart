import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
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

/// Every species on a locked photo or video, from its "+N" chip (issue
/// #4825).
void main() {
  late List<NearbyListRequest> nearbyAsked;

  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
    nearbyAsked = [];
  });

  const tang = SpeciesTagChip(
    speciesId: 'sp_blue_tang',
    storedName: 'Blue Tang',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
  );

  const handTag = SpeciesTagChip(
    speciesId: 'sp_hand',
    storedName: 'Hand Tagged',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
  );

  const appTag = SpeciesTagChip(
    speciesId: 'sp_rock_beauty',
    storedName: 'Rock Beauty',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
    unconfirmed: true,
  );

  Future<void> pump(
    WidgetTester tester, {
    MediaType type = MediaType.photo,
  }) async {
    final overrides = await getBaseOverrides();
    final item = testMediaItem(id: 'p1', diveId: 'd1', mediaType: type);
    final router = GoRouter(
      initialLocation: '/viewer',
      routes: [
        GoRoute(
          path: '/viewer',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showMediaSpeciesListSheet(context, item),
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
          mediaTagChipsProvider(
            'p1',
          ).overrideWith((ref) async => const [tang, appTag, handTag]),
          mediaIdentificationRepositoryProvider.overrideWithValue(
            FixedIdentifications([
              for (final (id, species) in [
                ('a', 'sp_blue_tang'),
                ('b', 'sp_rock_beauty'),
              ])
                ruleId(
                  id,
                  decision: IdentificationDecision.accepted,
                  decidedSpeciesId: species,
                ),
            ]),
          ),
          identificationCropProvider.overrideWith((ref, key) async => null),
          mediaSuggestionsProvider('p1').overrideWith(
            (ref) async => <SpeciesSuggestion>[
              suggestion(chromis, score: 0.71),
            ],
          ),
          recordedNearbyListProvider.overrideWith((ref, request) async {
            nearbyAsked.add(request);
            return const NearbySpecies(speciesKeys: {2});
          }),
        ],
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists every species, tagged and suggested, and says how to '
      'change them', (tester) async {
    await pump(tester);
    expect(
      find.byKey(const ValueKey('media_species_list_sheet')),
      findsOneWidget,
    );
    expect(find.text('Species in this photo'), findsOneWidget);
    expect(find.text('Unlock to add or dismiss'), findsOneWidget);
    expect(find.text('Blue Tang'), findsOneWidget);
    expect(find.text('Brown Chromis 71%'), findsOneWidget);
  });

  testWidgets('says video for a video', (tester) async {
    await pump(tester, type: MediaType.video);
    expect(find.text('Species in this video'), findsOneWidget);
  });

  // The list is only shown while the photo is locked (issue #5024).
  testWidgets('a tag opens its crops', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Blue Tang'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('species_crop_sheet')), findsOneWidget);
    expect(find.text('DETAIL sp_blue_tang'), findsNothing);
  });

  testWidgets('a tag with no crop opens its species page', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Hand Tagged'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL sp_hand'), findsOneWidget);
  });

  testWidgets('a suggestion is shown but does nothing', (tester) async {
    await pump(tester);
    final chip = tester.widget<ActionChip>(
      find.ancestor(
        of: find.text('Brown Chromis 71%'),
        matching: find.byType(ActionChip),
      ),
    );
    expect(chip.onPressed, isNull);
  });

  testWidgets('a tag the app applied opens its crops too', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Rock Beauty'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('species_crop_sheet')), findsOneWidget);
  });

  testWidgets('a suggestion recorded near the dive carries the pin '
      '(issue #4668)', (tester) async {
    await pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('media_suggested_chip_2')),
        matching: find.byKey(const ValueKey('recorded_nearby_pin')),
      ),
      findsOneWidget,
    );
    expect(nearbyAsked.toSet(), {(diveId: 'd1', photo: null, siteId: null)});
  });
}
