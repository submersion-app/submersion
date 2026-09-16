import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<Widget> page({String? diveId, DivePrefill? prefill}) async {
    final base = await getBaseOverrides();
    return ProviderScope(
      overrides: [
        ...base,
        diveRepositoryProvider.overrideWithValue(repository),
        diveListNotifierProvider.overrideWith(
          (ref) => DiveListNotifier(repository, ref),
        ),
        customTankPresetsProvider.overrideWith((ref) async => []),
      ].cast(),
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: DiveEditPage(diveId: diveId, prefill: prefill, embedded: true),
        ),
      ),
    );
  }

  final plannedSwitch = find.byKey(const Key('dive_edit_planned_switch'));

  /// The new-dive path starts a 10 s GPS capture and the save path shows a
  /// snackbar, so pumpAndSettle never returns; pump in bounded steps.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'a prefill with isPlanned shows the switch on and hides the number',
    (tester) async {
      await tester.pumpWidget(
        await page(prefill: const DivePrefill(isPlanned: true)),
      );
      await settle(tester);
      final sw = tester.widget<SwitchListTile>(plannedSwitch);
      expect(sw.value, isTrue);
      expect(find.text('Dive #'), findsNothing);
    },
  );

  testWidgets('a plain new dive shows the switch off and the number', (
    tester,
  ) async {
    await tester.pumpWidget(await page());
    await settle(tester);
    final sw = tester.widget<SwitchListTile>(plannedSwitch);
    expect(sw.value, isFalse);
    expect(find.text('Dive #'), findsOneWidget);
  });

  testWidgets('saving with the switch on creates an unnumbered planned dive', (
    tester,
  ) async {
    await tester.pumpWidget(
      await page(prefill: const DivePrefill(isPlanned: true)),
    );
    await settle(tester);
    await save(tester);
    final dives = await repository.getAllDives();
    expect(dives.single.isPlanned, isTrue);
    expect(dives.single.diveNumber, isNull);
  });

  testWidgets('turning the switch off on a planned dive promotes it on save', (
    tester,
  ) async {
    final planned = await repository.createPlannedDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9)),
    );
    await tester.pumpWidget(await page(diveId: planned.id));
    await settle(tester);
    expect(tester.widget<SwitchListTile>(plannedSwitch).value, isTrue);
    expect(find.text('Dive #'), findsNothing);

    await tester.tap(plannedSwitch);
    await settle(tester);
    expect(find.text('Dive #'), findsOneWidget);

    await save(tester);
    final saved = await repository.getDiveById(planned.id);
    expect(saved?.isPlanned, isFalse);
    expect(saved?.diveNumber, 1);
  });

  testWidgets(
    'saving a planned dive without touching the switch keeps it planned',
    (tester) async {
      final planned = await repository.createPlannedDive(
        Dive(id: '', dateTime: DateTime(2026, 6, 1, 9)),
      );
      await tester.pumpWidget(await page(diveId: planned.id));
      await settle(tester);
      await save(tester);
      final saved = await repository.getDiveById(planned.id);
      expect(saved?.isPlanned, isTrue);
      expect(saved?.diveNumber, isNull);
    },
  );

  testWidgets('a dive with a primary data source cannot be marked planned', (
    tester,
  ) async {
    final dive = await repository.createDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9), maxDepth: 12),
    );
    await repository.backfillPrimaryDataSource(dive.id);
    await tester.pumpWidget(await page(diveId: dive.id));
    await settle(tester);
    expect(plannedSwitch, findsNothing);
  });
}
