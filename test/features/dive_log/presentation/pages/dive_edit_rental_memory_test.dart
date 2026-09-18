import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #2075: applying the last dive at a center copies its weights and
/// tanks into the dive being edited.
void main() {
  late DiveRepository dives;
  late DiveCenter center;
  late String diverId;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    final now = DateTime.now();
    diverId = (await DiverRepository().createDiver(
      Diver(id: '', name: 'Tester', createdAt: now, updatedAt: now),
    )).id;
    center = await DiveCenterRepository().createDiveCenter(
      DiveCenter(
        id: '',
        diverId: diverId,
        name: 'Reef Divers',
        createdAt: now,
        updatedAt: now,
      ),
    );
    // The earlier dive at the center: 6 kg belt, one AL80.
    await dives.createDive(
      Dive(
        id: 'earlier',
        diverId: diverId,
        dateTime: DateTime(2026, 3, 12, 9),
        diveCenter: center,
        weights: const [
          DiveWeight(
            id: 'w-earlier',
            diveId: 'earlier',
            weightType: WeightType.belt,
            amountKg: 6,
          ),
        ],
        tanks: const [
          DiveTank(
            id: 't-earlier',
            volume: 11.1,
            workingPressure: 207,
            startPressure: 180,
            endPressure: 60,
            presetName: 'al80',
          ),
        ],
      ),
    );
    // The dive being edited: same center, no weights, no tanks.
    await dives.createDive(
      Dive(
        id: 'current',
        diverId: diverId,
        dateTime: DateTime(2026, 9, 18, 9),
        diveCenter: center,
      ),
    );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<void> pumpEditor(WidgetTester tester, String diveId) async {
    tester.view.physicalSize = const Size(1000, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(dives),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(dives, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DiveEditPage(diveId: diveId, embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveEditPage)),
    );
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(diverId);
    await tester.pumpAndSettle();
  }

  /// The trip group is collapsed by default and mounts its rows only when
  /// open; the header row is the toggle.
  Future<void> expandTrip(WidgetTester tester) async {
    final header = find.text('Trip');
    await tester.scrollUntilVisible(
      header,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(header);
    await tester.pumpAndSettle();
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('apply copies the earlier weights and tanks into the form', (
    tester,
  ) async {
    await pumpEditor(tester, 'current');
    await expandTrip(tester);
    expect(find.text('Last time at Reef Divers'), findsOneWidget);
    expect(find.text('Lead: 6.0 kg'), findsOneWidget);

    await tester.ensureVisible(find.text('Apply last dive'));
    await tester.tap(find.text('Apply last dive'));
    await tester.pumpAndSettle();
    // The editor seeds a default tank row into a tankless dive, so the form
    // already holds a tank and the replace is confirmed first.
    expect(find.text('Replace weights and tanks?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Weights and tanks copied'), findsOneWidget);

    await save(tester);

    final saved = (await dives.getDiveById('current'))!;
    expect(saved.weights.single.weightType, WeightType.belt);
    expect(saved.weights.single.amountKg, 6);
    expect(saved.weights.single.id, isNot('w-earlier'));
    expect(saved.tanks.single.volume, 11.1);
    expect(saved.tanks.single.presetName, 'al80');
    expect(saved.tanks.single.id, isNot('t-earlier'));
    // The pressures are the defaults for a new tank (200 bar start, 50 bar
    // end), not the old dive's 180 and 60.
    expect(saved.tanks.single.startPressure, 200);
    expect(saved.tanks.single.endPressure, 50);
  });

  testWidgets('apply on a form that already has weights replaces them', (
    tester,
  ) async {
    await dives.updateDive(
      (await dives.getDiveById('current'))!.copyWith(
        weights: const [
          DiveWeight(
            id: 'w-current',
            diveId: 'current',
            weightType: WeightType.integrated,
            amountKg: 4,
          ),
        ],
      ),
    );
    await pumpEditor(tester, 'current');
    await expandTrip(tester);

    await tester.ensureVisible(find.text('Apply last dive'));
    await tester.tap(find.text('Apply last dive'));
    await tester.pumpAndSettle();
    expect(find.text('Replace weights and tanks?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    await save(tester);
    final saved = (await dives.getDiveById('current'))!;
    expect(saved.weights.single.weightType, WeightType.belt);
    expect(saved.weights.single.amountKg, 6);
  });
}
