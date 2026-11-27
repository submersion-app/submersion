import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_practice_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/practice/leitner.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_practice_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_gallery_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/suggested_species_section.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../widgets/species_picture_test_support.dart';

class _RecordingPractice extends SpeciesPracticeRepository {
  final saved = <PracticeState>[];
  bool fail = false;

  @override
  Future<void> save(String diverId, PracticeState state) async {
    if (fail) throw StateError('disk full');
    saved.add(state);
  }

  @override
  Future<Map<String, PracticeState>> statesFor(String diverId) async =>
      const {};

  @override
  Stream<void> watchChanges() => const Stream.empty();
}

SeenSpecies _seen(String id, String name, {String? scientific}) => SeenSpecies(
  species: Species(
    id: id,
    commonName: name,
    scientificName: scientific,
    category: SpeciesCategory.fish,
  ),
  totalSightings: 1,
  diveCount: 1,
  siteCount: 1,
  firstSeen: DateTime.utc(2025),
  lastSeen: DateTime.utc(2025),
);

final _species = [
  _seen('grouper', 'Grouper', scientific: 'Epinephelus'),
  _seen('snapper', 'Snapper', scientific: 'Lutjanus'),
  _seen('grunt', 'Grunt', scientific: 'Haemulon'),
  _seen('wrasse', 'Wrasse', scientific: 'Thalassoma'),
  _seen('tang', 'Tang', scientific: 'Acanthurus'),
];

void main() {
  Future<_RecordingPractice> pump(
    WidgetTester tester, {
    List<SeenSpecies>? seen,
    bool poolFails = false,
  }) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final practice = _RecordingPractice();
    final list = seen ?? _species;
    final base = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/practice',
      routes: [
        GoRoute(
          path: '/practice',
          builder: (context, state) => SpeciesPracticePage(
            random: Random(7),
            now: () => DateTime.utc(2026, 11, 25),
          ),
        ),
        GoRoute(
          path: '/species/:id',
          builder: (context, state) =>
              Scaffold(body: Text('SPECIES ${state.pathParameters['id']}')),
        ),
      ],
    );
    await pumpPicturesApp(
      tester,
      testAppRouter(
        router: router,
        overrides: [
          ...base,
          speciesPracticeRepositoryProvider.overrideWithValue(practice),
          speciesPracticeStatesProvider.overrideWith((ref) async => const {}),
          seenSpeciesProvider.overrideWith((ref) async => list),
          speciesPracticePoolProvider.overrideWith(
            (ref) async => poolFails
                ? throw StateError('no database')
                : {
                    for (final s in list)
                      s.species.id: [
                        testCrop(
                          'crop_${s.species.id}',
                          mediaId: 'm_${s.species.id}',
                        ),
                      ],
                  },
          ),
        ],
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpeciesPracticePage)),
    );
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver('diver-a');
    await tester.pumpAndSettle();
    return practice;
  }

  /// The species the round shows, read from its crop.
  String shown(WidgetTester tester) => tester
      .widget<IdentificationCrop>(find.byType(IdentificationCrop))
      .identificationId
      .substring('crop_'.length);

  String nameOf(String id) =>
      _species.firstWhere((s) => s.species.id == id).species.commonName;

  testWidgets('explains when fewer than 4 species have confirmed crops', (
    tester,
  ) async {
    await pump(tester, seen: _species.take(3).toList());
    expect(find.textContaining('at least 4 species'), findsOneWidget);
  });

  testWidgets('a right answer saves box 2', (tester) async {
    final practice = await pump(tester);
    final answer = shown(tester);
    await tester.tap(find.text(nameOf(answer)));
    await tester.pumpAndSettle();

    expect(find.text('Right'), findsOneWidget);
    expect(practice.saved.single.speciesId, answer);
    expect(practice.saved.single.box, 2);
  });

  testWidgets(
    'a wrong answer saves box 1 and lists the species in the summary',
    (tester) async {
      final practice = await pump(tester);
      var missed = '';
      for (var round = 0; round < 5; round++) {
        final answer = shown(tester);
        final wrong = find.byWidgetPredicate(
          (w) =>
              w is FilledButton &&
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'practice_choice_',
              ) &&
              (w.key! as ValueKey<String>).value != 'practice_choice_$answer',
        );
        if (round == 0) {
          missed = answer;
          await tester.tap(wrong.first);
        } else {
          await tester.tap(find.byKey(ValueKey('practice_choice_$answer')));
        }
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('practice_next')));
        await tester.pumpAndSettle();
      }

      expect(practice.saved.first.box, 1);
      expect(practice.saved.first.wrongCount, 1);
      expect(find.text('4 of 5 right'), findsOneWidget);
      await tester.tap(find.text(nameOf(missed)));
      await tester.pumpAndSettle();
      expect(find.text('SPECIES $missed'), findsOneWidget);
    },
  );

  testWidgets('scientific names switch', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('practice_scientific')));
    await tester.pumpAndSettle();
    final answer = shown(tester);
    final scientific = _species
        .firstWhere((s) => s.species.id == answer)
        .species
        .scientificName!;
    expect(find.text(scientific), findsOneWidget);
    expect(find.text(nameOf(answer)), findsNothing);
  });

  testWidgets('leaving mid-session keeps saved answers', (tester) async {
    final practice = await pump(tester);
    await tester.tap(find.byKey(ValueKey('practice_choice_${shown(tester)}')));
    await tester.pumpAndSettle();
    expect(practice.saved, hasLength(1));
  });

  testWidgets('a failed load says so instead of spinning', (tester) async {
    await pump(tester, poolFails: true);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Could not load your species'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a failed save leaves the round unanswered', (tester) async {
    final practice = await pump(tester);
    practice.fail = true;
    await tester.tap(find.byKey(ValueKey('practice_choice_${shown(tester)}')));
    await tester.pumpAndSettle();
    expect(find.text('Right'), findsNothing);
    expect(find.byKey(const ValueKey('practice_next')), findsNothing);
    expect(
      find.text("Couldn't save your changes. Nothing was changed."),
      findsOneWidget,
    );
  });
}
