/// Integration test for the bottom-nav customization flow.
///
/// Drives the full user path: bottom nav -> More -> Settings -> Appearance ->
/// Navigation bar, performs a reorder, returns to the bottom nav, and verifies
/// the result. A second test verifies that Reset to defaults restores the
/// original ordering.
///
/// Run with:
/// ```bash
/// flutter test integration_test/nav_customization_test.dart -d macos
/// ```
library;

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/app.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/log_file_service.dart';
import 'package:submersion/features/settings/presentation/providers/debug_log_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import 'helpers/screenshot_test_data.dart';

/// Pumps a fixed number of frames to let layout and async navigation complete
/// without waiting for every animation to stop — matches the pattern used in
/// screenshots_test.dart to avoid hangs from repeating animations.
Future<void> _settle(WidgetTester tester, {int frames = 20}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Forces a narrow phone-sized viewport so the app renders the bottom
/// NavigationBar (mobile layout) instead of the wide-screen NavigationRail.
///
/// The threshold in `MainScaffold` is 800 logical px; we pick 400 x 800 with
/// devicePixelRatio 1.0 so the logical size is clearly below that.
void _forcePhoneLayout(WidgetTester tester) {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Boots the app with an in-memory database pre-seeded with a diver so the
/// welcome/onboarding redirect is skipped and we land on `/dashboard`.
Future<void> _bootApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  final testDb = AppDatabase(NativeDatabase.memory());
  DatabaseService.instance.setTestDatabase(testDb);

  // Use a temp directory for the LogFileService. The Settings page watches
  // debugModeNotifierProvider which in turn watches logFileServiceProvider,
  // so the provider must be overridden with an initialized service even
  // though this test never exercises logging.
  final tempLogDir = Directory.systemTemp.createTempSync('submersion_itest_');
  final logFileService = LogFileService(logDirectory: tempLogDir.path);
  await logFileService.initialize();

  addTearDown(() async {
    await testDb.close();
    DatabaseService.instance.resetForTesting();
    if (tempLogDir.existsSync()) {
      tempLogDir.deleteSync(recursive: true);
    }
  });

  // Seed a diver so `hasAnyDiversProvider` returns true and the router lets us
  // reach `/dashboard` directly instead of redirecting to `/welcome`.
  await ScreenshotTestDataSeeder(testDb).seedAll();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        logFileServiceProvider.overrideWithValue(logFileService),
      ],
      child: const SubmersionApp(),
    ),
  );

  // Let the router redirect, providers load, and the first frame settle.
  await _settle(tester, frames: 40);
}

/// Drives from the dashboard/bottom nav to the Navigation bar customization
/// page: More -> Settings -> Appearance -> Navigation bar.
Future<void> _openNavCustomization(WidgetTester tester) async {
  // Bottom nav -> More.
  await tester.tap(find.widgetWithText(NavigationDestination, 'More'));
  await _settle(tester);

  // More bottom sheet -> Settings (overflow list uses ListTile).
  await tester.tap(find.widgetWithText(ListTile, 'Settings').first);
  await _settle(tester);

  // Settings page -> Appearance.
  await tester.tap(find.widgetWithText(ListTile, 'Appearance').first);
  await _settle(tester);

  // Appearance page -> Navigation bar.
  await tester.tap(find.widgetWithText(ListTile, 'Navigation bar').first);
  await _settle(tester);
}

/// Taps the back button repeatedly until we land on a page that shows the
/// primary bottom NavigationBar again. We cap the hops to avoid an infinite
/// loop in case the UI state diverges.
Future<void> _popToBottomNav(WidgetTester tester) async {
  for (int i = 0; i < 6; i++) {
    if (find.byType(NavigationBar).evaluate().isNotEmpty) return;
    final back = find.byTooltip('Back');
    if (back.evaluate().isEmpty) break;
    await tester.tap(back.first);
    await _settle(tester);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('customizing nav order updates the bottom bar', (tester) async {
    _forcePhoneLayout(tester);
    await _bootApp(tester);

    await _openNavCustomization(tester);

    // Default primary middle slots: [Dives, Sites, Trips]. Equipment is the
    // first overflow entry (flat index 4 in the reorderable list). Tapping
    // move-up once promotes it across the divider to primary.
    final moveEquipmentUp = find.byTooltip('Move Equipment up');
    expect(
      moveEquipmentUp,
      findsOneWidget,
      reason: 'Move-up button for Equipment should be present in the list',
    );
    await tester.tap(moveEquipmentUp);
    await _settle(tester);

    await _popToBottomNav(tester);

    // Equipment should now appear in the bottom nav, displacing Trips.
    expect(
      find.widgetWithText(NavigationDestination, 'Equipment'),
      findsOneWidget,
      reason: 'Equipment should be promoted into the primary bottom nav',
    );
    expect(
      find.widgetWithText(NavigationDestination, 'Trips'),
      findsNothing,
      reason: 'Trips should be demoted out of the primary bottom nav',
    );
  });

  testWidgets('reset to defaults restores original order', (tester) async {
    _forcePhoneLayout(tester);
    await _bootApp(tester);

    // First customize so Reset has something to undo.
    await _openNavCustomization(tester);
    await tester.tap(find.byTooltip('Move Equipment up'));
    await _settle(tester);

    // Reset to defaults.
    final resetBtn = find.widgetWithText(TextButton, 'Reset to defaults');
    expect(resetBtn, findsOneWidget);
    await tester.tap(resetBtn);
    await _settle(tester);

    await _popToBottomNav(tester);

    // Default labels should all be present in the bottom nav.
    for (final label in const ['Home', 'Dives', 'Sites', 'Trips', 'More']) {
      expect(
        find.widgetWithText(NavigationDestination, label),
        findsOneWidget,
        reason: '"$label" should be restored in the default bottom nav order',
      );
    }
  });
}
