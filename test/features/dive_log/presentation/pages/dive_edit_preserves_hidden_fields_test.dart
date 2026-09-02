import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Widget-level regression for issue #1392:
/// "Saving a dive in the editor silently resets dive computer, deco and
/// planned-dive fields".
///
/// The edit form owns a subset of the dive's columns. Everything else on the
/// row (where the dive was downloaded from, the deco settings it ran on, the
/// planner flag that keeps it out of statistics) must survive a save untouched,
/// because `DiveRepository.updateDive` writes every column from the entity it
/// is handed. This drives the real edit flow against a real database so the
/// assertion is on the stored row, not on what the form thinks it sent.
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    void Function(String)? onSaved,
  }) async {
    // The finders below match English literals. flutter_test forwards the
    // host machine's locale list rather than a fixed en_US, so an unpinned
    // MaterialApp renders a translated UI for a developer whose primary
    // locale is one of the eleven this app supports, and every finder misses.
    // Forcing a non-English host locale here means the pin on MaterialApp
    // below is load-bearing everywhere, instead of only on those machines:
    // remove it and this test fails on any runner, CI included.
    tester.platformDispatcher.localesTestValue = const [
      Locale('fr'),
      Locale('en'),
    ];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides.cast<Override>(),
          diveRepositoryProvider.overrideWithValue(repository),
          diveListNotifierProvider.overrideWith(
            (ref) => DiveListNotifier(repository, ref),
          ),
          customTankPresetsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          // Pinned: flutter_test forwards the host machine's locale list, so
          // an unpinned MaterialApp resolves to a translated UI on a
          // non-English dev machine and every English finder below misses.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: DiveEditPage(
              diveId: diveId,
              embedded: true,
              onSaved: onSaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'saving an edited dive keeps the fields the form does not display',
    (tester) async {
      // Every value here is one the edit form has no widget for. Each is set
      // to something other than the entity default so a reset is visible.
      final dive = await repository.createDive(
        Dive(
          id: 'dive-1392',
          name: 'Original name',
          dateTime: DateTime.utc(2026, 5, 1, 10),
          maxDepth: 30.0,
          isPlanned: true,
          diveComputerModel: 'Shearwater Perdix 2',
          diveComputerSerial: 'SN-1392',
          diveComputerFirmware: '93',
          decoAlgorithm: 'buhlmann',
          decoConservatism: 2,
          gradientFactorLow: 40,
          gradientFactorHigh: 85,
          weatherCode: 61,
          importId: 'import-1392',
          surfaceInterval: const Duration(hours: 1, minutes: 30),
        ),
      );

      // Sanity: the repository round-trips all of these, so a later reset can
      // only come from the save path.
      final stored = (await repository.getDiveById(dive.id))!;
      expect(stored.isPlanned, isTrue);
      expect(stored.diveComputerModel, 'Shearwater Perdix 2');
      expect(stored.surfaceInterval, const Duration(hours: 1, minutes: 30));

      String? savedId;
      await pumpEditor(tester, dive.id, onSaved: (id) => savedId = id);

      // Change one field the form does own, which is the reproduction in the
      // issue and also guarantees the Save button is enabled. A FormRow.text
      // stays collapsed until tapped, so open it before typing.
      final nameRow = find
          .ancestor(of: find.text('Name'), matching: find.byType(FormRow))
          .first;
      await tester.ensureVisible(nameRow);
      await tester.pumpAndSettle();
      await tester.tap(nameRow);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: nameRow, matching: find.byType(TextField)),
        'Renamed',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(savedId, isNotNull, reason: 'save should complete');

      final reloaded = (await repository.getDiveById(dive.id))!;
      expect(reloaded.name, 'Renamed', reason: 'the edited field is applied');

      expect(reloaded.isPlanned, isTrue, reason: 'isPlanned reset');
      expect(
        reloaded.diveComputerModel,
        'Shearwater Perdix 2',
        reason: 'diveComputerModel reset',
      );
      expect(
        reloaded.diveComputerSerial,
        'SN-1392',
        reason: 'diveComputerSerial reset',
      );
      expect(
        reloaded.diveComputerFirmware,
        '93',
        reason: 'diveComputerFirmware reset',
      );
      expect(reloaded.decoAlgorithm, 'buhlmann', reason: 'decoAlgorithm reset');
      expect(reloaded.decoConservatism, 2, reason: 'decoConservatism reset');
      expect(reloaded.gradientFactorLow, 40, reason: 'gradientFactorLow reset');
      expect(
        reloaded.gradientFactorHigh,
        85,
        reason: 'gradientFactorHigh reset',
      );
      expect(reloaded.weatherCode, 61, reason: 'weatherCode reset');
      expect(reloaded.importId, 'import-1392', reason: 'importId reset');
      expect(
        reloaded.surfaceInterval,
        const Duration(hours: 1, minutes: 30),
        reason: 'surfaceInterval reset',
      );
    },
  );
}
