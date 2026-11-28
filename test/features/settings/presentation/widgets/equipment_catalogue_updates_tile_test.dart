import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/equipment_catalogue_updates_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(WidgetTester tester, {bool browser = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (browser)
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: EquipmentCatalogueUpdatesTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults on and is saved per device', (tester) async {
    await pump(tester);
    expect(find.text('Download equipment catalogue updates'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(prefs.getBool(SettingsKeys.equipmentCatalogueUpdates), isFalse);
  });

  testWidgets('hidden in a browser, which never downloads it', (tester) async {
    await pump(tester, browser: true);
    expect(find.byType(SwitchListTile), findsNothing);
  });
}
