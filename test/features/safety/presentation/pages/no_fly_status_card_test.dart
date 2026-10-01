import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/safety/domain/services/no_fly_service.dart';
import 'package:submersion/features/safety/presentation/pages/no_fly_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  // The card formats the deadline with intl, which resolves against
  // Intl.defaultLocale, a process global another test in the same isolate may
  // have changed. Pin it to English for the digit assertions and restore it.
  late String? previousLocale;

  setUpAll(() => initializeDateFormatting('en'));

  setUp(() {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
  });

  tearDown(() => Intl.defaultLocale = previousLocale);

  Future<void> pumpCard(WidgetTester tester, NoFlyStatus? status) {
    final settings = MockSettingsNotifier();
    settings.setTimeFormat(TimeFormat.twentyFourHour);
    return tester.pumpWidget(
      ProviderScope(
        overrides: [settingsProvider.overrideWith((ref) => settings)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: NoFlyStatusCard(status: status)),
        ),
      ),
    );
  }

  NoFlyStatus statusUntil(DateTime until) => NoFlyStatus(
    until: until,
    category: NoFlyCategory.single,
    interval: const Duration(hours: 12),
  );

  testWidgets('shows no restriction without a status', (tester) async {
    await pumpCard(tester, null);
    expect(find.text('No flying restriction'), findsOneWidget);
  });

  // [NoFlyStatus.until] from noFlyStatusProvider is a true UTC instant.
  testWidgets('counts down to the deadline', (tester) async {
    final until = DateTime.now().toUtc().add(
      const Duration(hours: 5, minutes: 30),
    );
    await pumpCard(tester, statusUntil(until));
    expect(find.textContaining('No-fly: 5h '), findsOneWidget);
  });

  testWidgets('prints the deadline in local time', (tester) async {
    final now = DateTime.now();
    // Two days ahead keeps the restriction active whatever the time of day.
    final until = DateTime(now.year, now.month, now.day + 2, 9, 30).toUtc();
    await pumpCard(tester, statusUntil(until));
    expect(find.textContaining('09:30'), findsOneWidget);
  });

  testWidgets('an elapsed snapshot reads as clear', (tester) async {
    final until = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
    await pumpCard(tester, statusUntil(until));
    expect(find.text('No flying restriction'), findsOneWidget);
  });
}
