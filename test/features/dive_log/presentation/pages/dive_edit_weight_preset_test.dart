import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/weight_presets/data/repositories/weight_preset_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Issue #1609 — saving the current weighting as a reusable preset from the
/// dive editor, and applying one to a new dive.
void main() {
  late DiveRepository dives;
  late WeightPresetRepository presets;
  late String diverId;

  setUp(() async {
    await setUpTestDatabase();
    dives = DiveRepository();
    presets = WeightPresetRepository();
    final now = DateTime.now();
    diverId = (await DiverRepository().createDiver(
      Diver(id: '', name: 'Tester', createdAt: now, updatedAt: now),
    )).id;
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

    // Seed the (base-mocked) current diver so weight presets resolve.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveEditPage)),
    );
    await container
        .read(currentDiverIdProvider.notifier)
        .setCurrentDiver(diverId);
    await tester.pumpAndSettle();

    final gasGear = find.text('1 tank · Air').first;
    await tester.ensureVisible(gasGear);
    await tester.pumpAndSettle();
    await tester.tap(gasGear);
    await tester.pumpAndSettle();
  }

  testWidgets('saves the current weighting as a named preset', (tester) async {
    final dive = await dives.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 3, 1, 10),
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: '',
            weightType: WeightType.belt,
            amountKg: 4.0,
          ),
        ],
      ),
    );

    await pumpEditor(tester, dive.id);

    await tester.tap(find.text('Save as preset'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Steel backmount');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();

    final saved = await presets.getPresets(diverId: diverId);
    expect(saved, hasLength(1));
    expect(saved.single.displayName, 'Steel backmount');
    expect(saved.single.entries.single.amountKg, 4.0);
  });

  testWidgets('applies a saved preset to a new dive as editable rows', (
    tester,
  ) async {
    await presets.createFromWeights(
      diverId: diverId,
      displayName: 'Wetsuit',
      weights: const [
        DiveWeight(
          id: '',
          diveId: '',
          weightType: WeightType.belt,
          amountKg: 2.5,
        ),
      ],
    );
    final dive = await dives.createDive(
      Dive(id: '', dateTime: DateTime(2026, 3, 8, 10)),
    );

    await pumpEditor(tester, dive.id);

    await tester.tap(find.text('Use preset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wetsuit'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, '2.5'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final reloaded = (await dives.getDiveById(dive.id))!;
    expect(reloaded.weights.single.amountKg, closeTo(2.5, 1e-9));
  });

  testWidgets('the weights total follows every amount edit (#956)', (
    tester,
  ) async {
    final dive = await dives.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 3, 1, 10),
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: '',
            weightType: WeightType.belt,
            amountKg: 4.0,
          ),
        ],
      ),
    );
    await pumpEditor(tester, dive.id);
    expect(find.text('Total: 4.0 kg'), findsOneWidget);

    // The first edit marks the page dirty, which rebuilds it once anyway;
    // the second must refresh the total on its own.
    await tester.enterText(find.widgetWithText(TextFormField, '4'), '5');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '5'), '6');
    await tester.pumpAndSettle();

    expect(find.text('Total: 6.0 kg'), findsOneWidget);
  });

  testWidgets('a dive with only the legacy weight opens as one editable row', (
    tester,
  ) async {
    final dive = await dives.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 3, 2, 10),
        weightAmount: 5.0,
        weightType: WeightType.ankleWeights,
      ),
    );
    await pumpEditor(tester, dive.id);

    expect(find.widgetWithText(TextFormField, '5'), findsOneWidget);
    expect(find.text('Ankle Weights'), findsOneWidget);
    expect(find.text('Total: 5.0 kg'), findsOneWidget);
  });

  testWidgets('Add Weight Entry appends a row after the existing ones', (
    tester,
  ) async {
    final dive = await dives.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 3, 3, 10),
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: '',
            weightType: WeightType.belt,
            amountKg: 4.0,
          ),
        ],
      ),
    );
    await pumpEditor(tester, dive.id);
    final add = find.text('Add Weight Entry');
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.pumpAndSettle();

    expect(find.text('Weight Belt'), findsOneWidget);
    expect(find.text('Integrated Weights'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '4'), findsOneWidget);
  });

  testWidgets('a name typed in the editor is saved with the dive (#956)', (
    tester,
  ) async {
    final dive = await dives.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 3, 4, 10),
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: '',
            weightType: WeightType.trimWeights,
            amountKg: 2.0,
          ),
        ],
      ),
    );
    await pumpEditor(tester, dive.id);
    final name = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.labelText == 'Name (optional)',
    );
    await tester.enterText(name, 'Top pocket');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final reloaded = (await dives.getDiveById(dive.id))!;
    expect(reloaded.weights.single.label, 'Top pocket');
    expect(reloaded.weights.single.amountKg, 2.0);
  });

  testWidgets('removing a weight row deletes it on save', (tester) async {
    final dive = await dives.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 3, 5, 10),
        weights: const [
          DiveWeight(
            id: 'w1',
            diveId: '',
            weightType: WeightType.belt,
            amountKg: 4.0,
          ),
          DiveWeight(
            id: 'w2',
            diveId: '',
            weightType: WeightType.trimWeights,
            amountKg: 1.0,
          ),
        ],
      ),
    );
    await pumpEditor(tester, dive.id);
    await tester.tap(find.byTooltip('Remove').first);
    await tester.pumpAndSettle();
    expect(find.text('Weight Belt'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final reloaded = (await dives.getDiveById(dive.id))!;
    expect(reloaded.weights.single.weightType, WeightType.trimWeights);
  });
}
