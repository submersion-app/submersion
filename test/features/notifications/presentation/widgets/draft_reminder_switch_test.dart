import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/features/notifications/presentation/providers/draft_reminder_settings_provider.dart';
import 'package:submersion/features/notifications/presentation/widgets/draft_reminder_switch.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

/// The device's "remind me about draft dives" switch (issue #637): off by
/// default, kept in this device's preferences.
void main() {
  testWidgets('off by default; turning it on saves it on this device', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const DraftReminderSwitch(),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(
      SwitchListTile,
      'Remind me about draft dives',
    );
    expect(tester.widget<SwitchListTile>(tile).value, isFalse);

    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(tester.widget<SwitchListTile>(tile).value, isTrue);
    expect(prefs.getBool(SettingsKeys.draftDownloadReminder), isTrue);
  });

  test('the setting reads what this device saved', () async {
    SharedPreferences.setMockInitialValues({
      SettingsKeys.draftDownloadReminder: true,
    });
    final prefs = await SharedPreferences.getInstance();

    expect(DraftReminderSettingNotifier(prefs).state, isTrue);
  });
}
