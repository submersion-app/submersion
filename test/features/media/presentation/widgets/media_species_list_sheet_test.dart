import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/media/presentation/widgets/media_species_list_sheet.dart';
import 'package:submersion/features/species_id/domain/entities/media_identification.dart';
import 'package:submersion/features/species_id/presentation/providers/species_id_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../species_id/presentation/species_id_fakes.dart';
import '../support/media_widget_harness.dart';

/// Every species on a locked photo or video, from its "+N" chip (issue
/// #4825).
void main() {
  setUp(() {
    marineLifeIdEnabled = true;
    addTearDown(resetMarineLifeIdEnabled);
  });

  const tang = SpeciesTagChip(
    speciesId: 'sp_blue_tang',
    storedName: 'Blue Tang',
    category: SpeciesCategory.fish,
    isBuiltIn: false,
  );

  Future<void> pump(
    WidgetTester tester, {
    MediaType type = MediaType.photo,
  }) async {
    final overrides = await getBaseOverrides();
    final item = testMediaItem(id: 'p1', mediaType: type);
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
          mediaTagChipsProvider('p1').overrideWith((ref) async => const [tang]),
          mediaSuggestionsProvider('p1').overrideWith(
            (ref) async => <SpeciesSuggestion>[
              suggestion(chromis, score: 0.71),
            ],
          ),
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

  testWidgets('a tag opens its species page', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Blue Tang'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL sp_blue_tang'), findsOneWidget);
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
}
