import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/firmware/presentation/widgets/firmware_settings_switches.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// The firmware switches in the notification settings (issue #5104): on by
/// default and kept on this device.
void main() {
  const checks = 'Check for firmware updates';
  const notices = 'Firmware update notifications';

  Future<SharedPreferences> pump(
    WidgetTester tester, [
    Map<String, Object> values = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(values);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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

  testWidgets('the saved values come back', (tester) async {
    await pump(tester, {SettingsKeys.firmwareNotificationsEnabled: false});
    expect(valueOf(tester, checks), isTrue);
    expect(valueOf(tester, notices), isFalse);
  });
}
