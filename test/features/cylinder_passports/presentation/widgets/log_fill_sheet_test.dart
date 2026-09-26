import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  group('parseDecimal', () {
    test('accepts a decimal comma', () {
      expect(parseDecimal('11,1'), 11.1);
      expect(parseDecimal('32'), 32);
      expect(parseDecimal(' 32.5 '), 32.5);
    });

    test('reads grouping, so 3,000 psi is three thousand', () {
      expect(parseDecimal('3,000'), 3000);
    });

    test('rejects non-finite values', () {
      expect(parseDecimal('NaN'), isNull);
      expect(parseDecimal('Infinity'), isNull);
    });

    test('rejects letters and blanks', () {
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal(''), isNull);
    });
  });

  Future<void> pump(
    WidgetTester tester, {
    CylinderFillRepository? repository,
    AppSettings? settings,
  }) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: settings == null
          ? null
          : MockSettingsNotifier(settings),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          if (repository != null)
            cylinderFillRepositoryProvider.overrideWithValue(repository),
        ],
        child: const LogFillSheet(passportId: 'pp-1', equipmentId: 'eq-1'),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows every field with the diver units', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    expect(find.text(l10n.passport_logFill_o2), findsOneWidget);
    expect(find.text(l10n.passport_logFill_he), findsOneWidget);
    expect(find.text(l10n.passport_logFill_pressure), findsOneWidget);
    expect(find.text(l10n.passport_logFill_temperature), findsOneWidget);
    expect(find.text(l10n.passport_logFill_station), findsOneWidget);
    expect(find.text(l10n.passport_logFill_analyzer), findsOneWidget);
    expect(find.text(l10n.forms_save), findsOneWidget);
  });

  testWidgets('refuses a mix over 100 percent', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.enterText(find.byKey(const Key('logFill_o2')), '60');
    await tester.enterText(find.byKey(const Key('logFill_he')), '50');
    await tester.ensureVisible(find.text(l10n.forms_save));
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_invalidMix), findsOneWidget);
  });

  testWidgets('refuses letters in a number field', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.enterText(find.byKey(const Key('logFill_pressure')), 'abc');
    await tester.ensureVisible(find.text(l10n.forms_save));
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_invalidNumber), findsOneWidget);
  });

  testWidgets('refuses an O2 of zero', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.enterText(find.byKey(const Key('logFill_o2')), '0');
    await tester.ensureVisible(find.text(l10n.forms_save));
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_invalidMix), findsOneWidget);
  });

  testWidgets('a failed save says so and leaves the sheet usable', (
    tester,
  ) async {
    await pump(tester, repository: _ThrowingFillRepository());
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.ensureVisible(find.text(l10n.forms_save));
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_saveFailed), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, l10n.forms_save),
    );
    expect(save.onPressed, isNotNull);
  });
  testWidgets('saves in metric from imperial input and closes', (tester) async {
    final repo = _CapturingFillRepository();
    await pump(
      tester,
      repository: repo,
      settings: const AppSettings(
        pressureUnit: PressureUnit.psi,
        temperatureUnit: TemperatureUnit.fahrenheit,
      ),
    );
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.enterText(find.byKey(const Key('logFill_o2')), '32');
    await tester.enterText(find.byKey(const Key('logFill_pressure')), '3,000');
    await tester.enterText(find.byKey(const Key('logFill_temperature')), '68');
    await tester.enterText(
      find.widgetWithText(TextField, l10n.passport_logFill_station),
      'Blue Water Fills',
    );
    await tester.ensureVisible(find.text(l10n.forms_save));
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();

    final saved = repo.created.single;
    expect(saved.passportId, 'pp-1');
    expect(saved.equipmentId, 'eq-1');
    expect(saved.o2Percent, 32);
    expect(saved.pressureBar, closeTo(206.84, 0.01));
    expect(saved.temperatureC, closeTo(20, 1e-9));
    expect(saved.stationName, 'Blue Water Fills');
    expect(saved.source, FillSource.manual);
    expect(find.byType(LogFillSheet), findsNothing);
  });

  testWidgets('the date opens the shared picker', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.tap(find.text(l10n.passport_logFill_date));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsNothing);
  });
  testWidgets('the time of the fill can be set', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.tap(find.text(l10n.passport_logFill_time));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  testWidgets('the last analyzer is remembered and stations are suggested', (
    tester,
  ) async {
    await pump(tester, repository: _HistoryFillRepository());
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    expect(find.text('Analox'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, l10n.passport_logFill_station),
      'Re',
    );
    await tester.pumpAndSettle();
    expect(find.text('Reef Air'), findsOneWidget);
  });
}

class _CapturingFillRepository extends CylinderFillRepository {
  final created = <CylinderFill>[];

  @override
  Future<CylinderFill> create(CylinderFill fill) async {
    created.add(fill);
    return fill;
  }
}

class _HistoryFillRepository extends CylinderFillRepository {
  @override
  Future<List<String>> recentStationNames({int limit = 8}) async => [
    'Reef Air',
    'Blue Water',
  ];

  @override
  Future<List<String>> recentAnalyzers({int limit = 8}) async => ['Analox'];
}

class _ThrowingFillRepository extends CylinderFillRepository {
  @override
  Future<CylinderFill> create(CylinderFill fill) async =>
      throw StateError('disk full');
}
