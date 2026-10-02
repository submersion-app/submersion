import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Issue #2508: with diver A at dive 213 and diver B at dive 50, a dive
/// logged by hand for B suggested number 214, the next number across every
/// diver, instead of B's own 51.
void main() {
  late DiveRepository repository;
  late String diverA;
  late String diverB;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    final now = DateTime(2026, 3, 1);
    final divers = DiverRepository();
    diverA = (await divers.createDiver(
      Diver(id: '', name: 'A', createdAt: now, updatedAt: now),
    )).id;
    diverB = (await divers.createDiver(
      Diver(id: '', name: 'B', createdAt: now, updatedAt: now),
    )).id;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive buildDive(String id, String diverId, int number) => Dive(
    id: id,
    diverId: diverId,
    diveNumber: number,
    dateTime: DateTime(2026, 3, 28, 10, 0),
    bottomTime: const Duration(minutes: 40),
    maxDepth: 20.0,
    tanks: const [],
    profile: const [],
    gear: looseGear(const []),
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );

  testWidgets("a new dive suggests the active diver's next number", (
    tester,
  ) async {
    await repository.createDive(buildDive('a-213', diverA, 213));
    await repository.createDive(buildDive('b-50', diverB, 50));

    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => diverB),
        ],
        locale: const Locale('en'),
        child: const DiveEditPage(embedded: true),
      ),
    );
    // The new-dive path starts a 10 s GPS capture, so pumpAndSettle never
    // returns; pump in bounded steps while the suggestion resolves.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('51'), findsOneWidget);
    expect(find.text('214'), findsNothing);
  });
}
