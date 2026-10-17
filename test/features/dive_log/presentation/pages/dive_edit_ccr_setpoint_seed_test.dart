import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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

/// Settings that are still loading from the database: [settingsLoaded] waits
/// until the test completes [loaded], as the real notifier does until the
/// diver's row lands.
class _LoadingSettingsNotifier extends MockSettingsNotifier {
  final loaded = Completer<void>();

  @override
  Future<void> get settingsLoaded => loaded.future;
}

/// Switching a dive to CCR prefills the setpoints from the diver's own CCR
/// ppO2 limits (issue #2368). The prefill must reach the saved row, not only
/// the panel: a dive saved without touching the CCR panel keeps the values
/// the panel showed.
void main() {
  late DiveRepository repository;
  late String? previousLocale;

  setUp(() async {
    // The setpoint hints are formatted with the Intl locale, which
    // MaterialApp's locale does not set; pin it so '0.6' is deterministic.
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    String diveId, {
    AppSettings? settings,
    MockSettingsNotifier? settingsNotifier,
    void Function(String)? onSaved,
  }) async {
    tester.view.physicalSize = const Size(950, 8000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final overrides = await getBaseOverrides(
      settingsNotifier: settingsNotifier ?? MockSettingsNotifier(settings),
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

  // Gas & Gear starts collapsed on a sparse dive; its header is a toggle,
  // so open it only when the mode selector is not already showing.
  Future<void> openGasGear(WidgetTester tester) async {
    if (find.text('CCR').evaluate().isEmpty) {
      final gasGear = find.textContaining('Gas & Gear');
      await tester.ensureVisible(gasGear.first);
      await tester.pumpAndSettle();
      await tester.tap(gasGear.first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }
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

    await openGasGear(tester);
    final ccr = find.text('CCR');
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

  group('a CCR dive with no recorded setpoints (#2802)', () {
    Finder setpointField(String label) => find.descendant(
      of: find.widgetWithText(TextFormField, label),
      matching: find.byType(TextField),
    );

    testWidgets('shows the diver setpoints once settings load', (tester) async {
      final dive = await repository.createDive(
        Dive(
          id: 'dive-2802-hydrate',
          dateTime: DateTime.utc(2026, 5, 1, 10),
          diveMode: DiveMode.ccr,
        ),
      );

      // The page opens while settings still hold their defaults.
      final settings = MockSettingsNotifier();
      await pumpEditor(tester, dive.id, settingsNotifier: settings);
      await openGasGear(tester);

      await settings.setCcrPpO2Limits(
        setpointLow: 0.6,
        setpointHigh: 1.2,
        diluentModPpO2: 1.4,
      );
      await tester.pumpAndSettle();

      final low = tester.widget<TextField>(setpointField('Low (Desc/Asc)'));
      final high = tester.widget<TextField>(setpointField('High (Bottom)'));
      expect(low.decoration!.hintText, '0.6');
      expect(high.decoration!.hintText, '1.2');
      expect(
        low.controller!.text,
        isEmpty,
        reason: 'nothing is recorded, so nothing is shown as a value',
      );
      expect(high.controller!.text, isEmpty);
    });

    testWidgets('saving after editing the panel records no setpoints', (
      tester,
    ) async {
      final dive = await repository.createDive(
        Dive(
          id: 'dive-2802-save',
          dateTime: DateTime.utc(2026, 5, 1, 10),
          diveMode: DiveMode.ccr,
        ),
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
      await openGasGear(tester);

      final type = find.widgetWithText(TextFormField, 'Type');
      await tester.ensureVisible(type);
      await tester.pumpAndSettle();
      await tester.enterText(type, 'Sofnolime');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(savedId, isNotNull, reason: 'save should complete');

      final reloaded = (await repository.getDiveById(dive.id))!;
      expect(reloaded.scrubber?.type, 'Sofnolime');
      expect(reloaded.setpointLow, isNull);
      expect(reloaded.setpointHigh, isNull);
    });
  });

  testWidgets('switching to CCR before settings load seeds the loaded values', (
    tester,
  ) async {
    final dive = await repository.createDive(
      Dive(id: 'dive-2802-switch', dateTime: DateTime.utc(2026, 5, 1, 10)),
    );

    String? savedId;
    final settings = _LoadingSettingsNotifier();
    await pumpEditor(
      tester,
      dive.id,
      settingsNotifier: settings,
      onSaved: (id) => savedId = id,
    );

    // The diver picks CCR while settings still hold their defaults...
    await openGasGear(tester);
    final ccr = find.text('CCR');
    await tester.ensureVisible(ccr.first);
    await tester.pumpAndSettle();
    await tester.tap(ccr.first);
    await tester.pumpAndSettle();

    // ...then their own setpoints load.
    await settings.setCcrPpO2Limits(
      setpointLow: 0.6,
      setpointHigh: 1.2,
      diluentModPpO2: 1.4,
    );
    settings.loaded.complete();
    await tester.pumpAndSettle();

    final low = tester.widget<TextField>(
      find.descendant(
        of: find.widgetWithText(TextFormField, 'Low (Desc/Asc)'),
        matching: find.byType(TextField),
      ),
    );
    expect(
      low.controller!.text,
      '0.6',
      reason: 'the panel shows the seeded value, not the defaults',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(savedId, isNotNull, reason: 'save should complete');

    final reloaded = (await repository.getDiveById(dive.id))!;
    expect(reloaded.setpointLow, 0.6);
    expect(reloaded.setpointHigh, 1.2);
  });
}
