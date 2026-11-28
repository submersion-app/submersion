import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_settings_providers.dart';
import 'package:submersion/features/firmware/presentation/widgets/firmware_settings_switches.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The firmware switches in the notification settings (issue #5104): on by
/// default and kept on this device.
void main() {
  const checks = 'Check for firmware updates';
  const notices = 'Firmware update notifications';

  Future<SharedPreferences> pump(
    WidgetTester tester, [
    Map<String, Object> values = const {},
    bool notificationsSupported = true,
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          firmwareNotificationsSupportedProvider.overrideWithValue(
            notificationsSupported,
          ),
        ],
        child: const SingleChildScrollView(child: FirmwareSettingsSwitches()),
      ),
    );
    await tester.pumpAndSettle();
    return prefs;
  }

  bool valueOf(WidgetTester tester, String title) => tester
      .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, title))
      .value;

  testWidgets('both are on by default', (tester) async {
    await pump(tester);
    expect(valueOf(tester, checks), isTrue);
    expect(valueOf(tester, notices), isTrue);
    expect(
      find.text(
        'Reads the public firmware list once a day. Nothing about '
        'you is sent.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('turning checks off hides the notification switch', (
    tester,
  ) async {
    final prefs = await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, checks));
    await tester.pumpAndSettle();

    expect(prefs.getBool(SettingsKeys.firmwareChecksEnabled), isFalse);
    expect(find.text(notices), findsNothing);
  });

  testWidgets('a device that shows no notifications offers no switch', (
    tester,
  ) async {
    await pump(tester, const {}, false);
    expect(find.text(checks), findsOneWidget);
    expect(find.text(notices), findsNothing);
  });

  testWidgets('the saved values come back', (tester) async {
    await pump(tester, {SettingsKeys.firmwareNotificationsEnabled: false});
    expect(valueOf(tester, checks), isTrue);
    expect(valueOf(tester, notices), isFalse);
  });
  // The switches stay reachable with service reminders off: they govern a
  // network read and notices of their own.
  testWidgets('the notification settings show them with reminders off', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: (await getBaseOverrides(
          settingsNotifier: MockSettingsNotifier(
            const AppSettings(notificationsEnabled: false),
          ),
        )).cast(),
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsSectionDetailPage(sectionId: 'notifications'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(checks), findsOneWidget);
  });
  testWidgets('turning notifications off saves it', (tester) async {
    final prefs = await pump(tester);
    await tester.tap(find.widgetWithText(SwitchListTile, notices));
    await tester.pumpAndSettle();
    expect(prefs.getBool(SettingsKeys.firmwareNotificationsEnabled), isFalse);
  });
}
