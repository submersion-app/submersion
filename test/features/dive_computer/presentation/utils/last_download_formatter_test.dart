import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_computer/presentation/utils/last_download_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The formatter replaced a domain getter that could not localize (#152), so
/// these assert the localized wording per branch rather than just that a
/// string comes back.
void main() {
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  /// Renders the formatter's output for [lastDownload] under [locale].
  Future<String> render(
    WidgetTester tester,
    DateTime? lastDownload, {
    Locale locale = const Locale('en'),
    AppSettings settings = const AppSettings(),
  }) async {
    late String output;
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            output = formatLastDownload(
              context,
              lastDownload,
              units: UnitFormatter(settings),
            );
            return Text(output);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    return output;
  }

  testWidgets('a computer never downloaded from reads "Never"', (tester) async {
    expect(await render(tester, null), 'Never');
  });

  testWidgets('minutes and hours use their own labels', (tester) async {
    final now = DateTime.now();
    expect(
      await render(tester, now.subtract(const Duration(minutes: 5))),
      '5 min ago',
    );
    expect(
      await render(tester, now.subtract(const Duration(hours: 3))),
      '3 hours ago',
    );
  });

  testWidgets('the singular hour is not "1 hours ago"', (tester) async {
    final now = DateTime.now();
    expect(
      await render(tester, now.subtract(const Duration(hours: 1, minutes: 5))),
      '1 hour ago',
    );
  });

  testWidgets('yesterday and the day range have their own labels', (
    tester,
  ) async {
    final now = DateTime.now();
    expect(
      await render(tester, now.subtract(const Duration(days: 1, hours: 2))),
      'Yesterday',
    );
    expect(
      await render(tester, now.subtract(const Duration(days: 3))),
      '3 days ago',
    );
  });

  testWidgets('downloads older than a week fall back to a full date', (
    tester,
  ) async {
    final old = DateTime(2026, 1, 15);
    expect(await render(tester, old), 'Jan 15, 2026');
  });

  testWidgets('the fallback date honours the diver\'s date preference', (
    tester,
  ) async {
    final old = DateTime(2026, 1, 15);
    expect(
      await render(
        tester,
        old,
        settings: const AppSettings(dateFormat: DateFormatPreference.ddmmyyyy),
      ),
      '15/01/2026',
    );
  });

  testWidgets('a future timestamp does not render a negative duration', (
    tester,
  ) async {
    // Dive-computer or host clock skew: the diff would otherwise be
    // negative and print "-1 hours ago".
    final future = DateTime.now().add(const Duration(hours: 2));
    expect(await render(tester, future), '0 min ago');
  });

  testWidgets('the labels are localized, not hardcoded English', (
    tester,
  ) async {
    final now = DateTime.now();
    expect(await render(tester, null, locale: const Locale('de')), 'Nie');
    expect(
      await render(
        tester,
        now.subtract(const Duration(days: 1, hours: 2)),
        locale: const Locale('de'),
      ),
      'Gestern',
    );
    expect(
      await render(
        tester,
        now.subtract(const Duration(hours: 1, minutes: 5)),
        locale: const Locale('de'),
      ),
      'vor 1 Stunde',
    );
  });
}
