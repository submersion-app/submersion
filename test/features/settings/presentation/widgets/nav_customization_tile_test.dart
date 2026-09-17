import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/nav_customization_tile.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../support/fake_app_settings_repository.dart';

/// Stub settings notifier, so the accent-icon lookups this tile makes do not
/// reach for the database.
class _StubSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _StubSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpTile(
  WidgetTester tester, {
  required double width,
  required FakeAppSettingsRepository repo,
}) async {
  tester.view.physicalSize = Size(width, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(repo),
        settingsProvider.overrideWith((ref) => _StubSettingsNotifier()),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: NavCustomizationTile()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('NavCustomizationTile', () {
    // The phone and rail orders are set to different values here on purpose:
    // settings_page_test.dart's narrow-width test uses the default order for
    // both surfaces, so it cannot tell which branch actually built the
    // preview -- the phone and rail defaults happen to start with the same
    // three destinations. Diverging them here is what makes each test below
    // an unambiguous proof of which branch ran.
    testWidgets('below the 800px breakpoint, previews the phone order', (
      tester,
    ) async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'buddies', 'statistics']
        ..navRailIds = ['gps-log', 'planning', 'transfer'];

      await _pumpTile(tester, width: 500, repo: repo);

      expect(find.text('Equipment · Buddies · Statistics'), findsOneWidget);
    });

    testWidgets('at or above the 800px breakpoint, previews the rail order', (
      tester,
    ) async {
      final repo = FakeAppSettingsRepository()
        ..navPrimaryIds = ['equipment', 'buddies', 'statistics']
        ..navRailIds = ['gps-log', 'planning', 'transfer'];

      await _pumpTile(tester, width: 900, repo: repo);

      expect(find.text('GPS Log · Planning · Transfer'), findsOneWidget);
    });
  });
}
