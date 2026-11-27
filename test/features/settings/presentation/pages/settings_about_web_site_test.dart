import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/auto_update/domain/hosted_web_site.dart';
import 'package:submersion/features/auto_update/presentation/providers/hosted_web_site_provider.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/build_date_label.dart';
import 'package:submersion/features/settings/presentation/widgets/submersion_about_dialog.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/recording_url_launcher.dart';

/// Issue #4481: Submersion's stable and beta web sites point at each other
/// from Settings > About, and the beta site's version reads "(Beta)". Any
/// other page (a self-hosted copy, a native build) shows neither.
void main() {
  late SharedPreferences prefs;
  late Directory tempDir;
  late LogFileService logFileService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    tempDir = Directory.systemTemp.createTempSync('about_web_site_');
    logFileService = LogFileService(logDirectory: p.join(tempDir.path, 'logs'));
    await logFileService.initialize();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpAbout(WidgetTester tester, HostedWebSite site) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          logFileServiceProvider.overrideWithValue(logFileService),
          settingsProvider.overrideWith(
            (ref) => MockSettingsNotifier(const AppSettings()),
          ),
          packageInfoProvider.overrideWith(
            (ref) async => PackageInfo(
              appName: 'Submersion',
              packageName: 'app.submersion',
              version: '1.8.5',
              buildNumber: '412',
            ),
          ),
          buildDateProvider.overrideWithValue(null),
          // A browser has no updater; the Updates card's 5 second check
          // timer would also be left pending.
          deviceCapabilitiesProvider.overrideWithValue(
            currentDeviceCapabilities().copyWith(autoUpdate: false),
          ),
          hostedWebSiteProvider.overrideWithValue(site),
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

  Finder inDialog(Finder finder) =>
      find.descendant(of: find.byType(SubmersionAboutDialog), matching: finder);

  testWidgets('the stable site offers the beta site', (tester) async {
    final launcher = useRecordingUrlLauncher();
    await pumpAbout(tester, HostedWebSite.stable);

    expect(find.text('Try the beta web app'), findsOneWidget);
    expect(find.textContaining('beta.web.submersion.app'), findsOneWidget);
    expect(find.text('Use the stable web app'), findsNothing);
    expect(find.text('Version 1.8.5.412'), findsOneWidget);

    await tester.tap(find.text('Try the beta web app'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['https://beta.web.submersion.app']);
    expect(launcher.windowNames, ['_blank']);
  });

  testWidgets('the beta site offers the stable site and badges its version', (
    tester,
  ) async {
    final launcher = useRecordingUrlLauncher();
    await pumpAbout(tester, HostedWebSite.beta);

    expect(find.text('Use the stable web app'), findsOneWidget);
    expect(find.text('Try the beta web app'), findsNothing);
    expect(find.text('Version 1.8.5.412 (Beta)'), findsOneWidget);

    await tester.tap(find.text('Use the stable web app'));
    await tester.pumpAndSettle();
    expect(launcher.launched, ['https://web.submersion.app']);
    expect(launcher.windowNames, ['_blank']);

    await tester.tap(find.text('About Submersion'));
    await tester.pumpAndSettle();
    expect(inDialog(find.text('Version 1.8.5.412 (Beta)')), findsOneWidget);
  });

  testWidgets('any other page shows neither row and no badge', (tester) async {
    await pumpAbout(tester, HostedWebSite.none);

    expect(find.text('Try the beta web app'), findsNothing);
    expect(find.text('Use the stable web app'), findsNothing);
    expect(find.text('Version 1.8.5.412'), findsOneWidget);
    expect(find.textContaining('(Beta)'), findsNothing);
  });
}
