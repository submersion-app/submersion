import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    test('rejects letters and blanks', () {
      expect(parseDecimal('abc'), isNull);
      expect(parseDecimal(''), isNull);
    });
  });

  Future<void> pump(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
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
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_invalidMix), findsOneWidget);
  });

  testWidgets('refuses letters in a number field', (tester) async {
    await pump(tester);
    final l10n = AppLocalizations.of(tester.element(find.byType(LogFillSheet)));
    await tester.enterText(find.byKey(const Key('logFill_pressure')), 'abc');
    await tester.tap(find.text(l10n.forms_save));
    await tester.pumpAndSettle();
    expect(find.text(l10n.passport_logFill_invalidNumber), findsOneWidget);
  });
}
