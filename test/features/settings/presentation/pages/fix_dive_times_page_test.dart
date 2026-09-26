import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/pages/fix_dive_times_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late String? previousLocale;

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
    await setUpTestDatabase();
  });

  tearDown(() async {
    Intl.defaultLocale = previousLocale;
    await tearDownTestDatabase();
  });

  Future<void> pumpPage(WidgetTester tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides.cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FixDiveTimesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder offsetField() => find.widgetWithText(TextField, 'Hours (e.g. +7, -5)');

  testWidgets('a fractional offset says so instead of becoming a different '
      'whole number (#1900 review)', (tester) async {
    await pumpPage(tester);

    await tester.enterText(offsetField(), '2.5');
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(offsetField()).controller!.text,
      '2.5',
      reason: 'a digits-only filter turned "2.5" into 2',
    );
    expect(find.text('Enter a whole number'), findsOneWidget);
  });

  testWidgets('a whole offset, negative included, shows no error', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.enterText(offsetField(), '-5');
    await tester.pumpAndSettle();

    expect(find.text('Enter a whole number'), findsNothing);
  });
}
