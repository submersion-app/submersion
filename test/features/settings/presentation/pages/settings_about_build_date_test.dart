import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/build_date_label.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #4365: Settings > About shows the day the build was made, under the
/// version and in the About dialog, so a tester whose phone updated overnight
/// can tell when their build changed.
void main() {
  late SharedPreferences prefs;
  late Directory tempDir;
  late LogFileService logFileService;
  late String? previousLocale;

  // The date is formatted by intl, which reads the process-global
  // Intl.defaultLocale rather than MaterialApp.locale. Pin it to English for
  // the month names asserted here, and restore it so no other file in the
  // same isolate inherits it. Pinning it needs the symbols loaded first.
  setUpAll(() => initializeDateFormatting('en'));

  setUp(() async {
    previousLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en';
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('about_build_date_');
    logFileService = LogFileService(logDirectory: p.join(tempDir.path, 'logs'));
    await logFileService.initialize();
  });

  tearDown(() {
    Intl.defaultLocale = previousLocale;
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpAbout(
    WidgetTester tester, {
    required DateTime? buildDate,
    DateFormatPreference dateFormat = DateFormatPreference.dMMMYYYY,
  }) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          logFileServiceProvider.overrideWithValue(logFileService),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(AppSettings(dateFormat: dateFormat)),
          ),
          packageInfoProvider.overrideWith(
            (ref) async => PackageInfo(
              appName: 'Submersion',
              packageName: 'app.submersion',
              version: '1.8.5',
              buildNumber: '412',
            ),
          ),
          buildDateProvider.overrideWithValue(buildDate),
          // The Updates card's checker starts a 5 second timer the test
          // would leave pending; the build date does not depend on it.
          deviceCapabilitiesProvider.overrideWithValue(
            currentDeviceCapabilities().copyWith(autoUpdate: false),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsSectionDetailPage(sectionId: 'about'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the build date under the version', (tester) async {
    await pumpAbout(tester, buildDate: DateTime(2026, 11, 9));

    expect(find.text('Version 1.8.5.412'), findsOneWidget);
    expect(find.text('Built 9 Nov 2026'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Built 9 Nov 2026')).dy,
      greaterThan(tester.getTopLeft(find.text('Version 1.8.5.412')).dy),
    );
  });

  testWidgets('follows the diver date format', (tester) async {
    await pumpAbout(
      tester,
      buildDate: DateTime(2026, 11, 9),
      dateFormat: DateFormatPreference.mmmDYYYY,
    );

    expect(find.text('Built Nov 9, 2026'), findsOneWidget);
  });

  testWidgets('a build without a date shows no date line', (tester) async {
    await pumpAbout(tester, buildDate: null);

    expect(find.text('Version 1.8.5.412'), findsOneWidget);
    expect(find.textContaining('Built'), findsNothing);
  });

  testWidgets('the About dialog shows the build date', (tester) async {
    await pumpAbout(tester, buildDate: DateTime(2026, 11, 9));

    await tester.tap(find.text('About Submersion'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AboutDialog);
    expect(dialog, findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('Built 9 Nov 2026')),
      findsOneWidget,
    );
  });

  testWidgets('the licenses page from the tile shows the build date', (
    tester,
  ) async {
    await pumpAbout(tester, buildDate: DateTime(2026, 11, 9));

    await tester.tap(find.text('Open Source Licenses'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.text('Built 9 Nov 2026'), findsOneWidget);
  });

  testWidgets('the licenses page has no date line without a date', (
    tester,
  ) async {
    await pumpAbout(tester, buildDate: null);

    await tester.tap(find.text('Open Source Licenses'));
    await tester.pumpAndSettle();

    expect(find.byType(LicensePage), findsOneWidget);
    expect(find.textContaining('Built'), findsNothing);
  });

  testWidgets('the About dialog has no date line without a date', (
    tester,
  ) async {
    await pumpAbout(tester, buildDate: null);

    await tester.tap(find.text('About Submersion'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AboutDialog),
        matching: find.textContaining('Built'),
      ),
      findsNothing,
    );
  });
}
