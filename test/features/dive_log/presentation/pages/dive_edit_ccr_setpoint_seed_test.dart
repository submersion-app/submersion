import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Switching a dive to CCR prefills the setpoints from the diver's own CCR
/// ppO2 limits (issue #2368). The prefill must reach the saved row, not only
/// the panel: a dive saved without touching the CCR panel keeps the values
/// the panel showed.
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
    required AppSettings settings,
    void Function(String)? onSaved,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
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

  testWidgets('switching a dive to CCR saves the diver own setpoints', (
    tester,
  ) async {
    final dive = await repository.createDive(
      Dive(id: 'dive-2368', dateTime: DateTime.utc(2026, 5, 1, 10)),
    );

    String? savedId;
    await pumpEditor(
      tester,
      dive.id,
      settings: const AppSettings().copyWith(
        ccrSetpointLow: 0.6,
        ccrSetpointHigh: 1.2,
      ),
      onSaved: (id) => savedId = id,
    );

    // Gas & Gear starts collapsed on a sparse dive; its header is a toggle,
    // so open it only when the mode selector is not already showing.
    final ccr = find.text('CCR');
    if (ccr.evaluate().isEmpty) {
      final gasGear = find.textContaining('Gas & Gear');
      await tester.ensureVisible(gasGear.first);
      await tester.pumpAndSettle();
      await tester.tap(gasGear.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(ccr.first);
    await tester.pumpAndSettle();
    await tester.tap(ccr.first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(savedId, isNotNull, reason: 'save should complete');

    final reloaded = (await repository.getDiveById(dive.id))!;
    expect(reloaded.diveMode, DiveMode.ccr);
    expect(reloaded.setpointLow, 0.6);
    expect(reloaded.setpointHigh, 1.2);
  });
}
