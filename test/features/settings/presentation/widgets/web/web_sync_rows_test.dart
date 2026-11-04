import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/platform/web/remember_credentials_provider.dart';
import 'package:submersion/core/platform/web/web_forget_device_service.dart';
import 'package:submersion/core/platform/web_database_status.dart';
import 'package:submersion/features/demo_mode/data/demo_mode_gate.dart';
import 'package:submersion/features/settings/presentation/providers/web_forget_device_provider.dart';
import 'package:submersion/features/settings/presentation/widgets/web/web_sync_rows.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/global_test_defaults.dart';
import '../../../../../helpers/test_app.dart';

class _RecordingRemember extends RememberCredentialsNotifier {
  @override
  bool build() => false;

  @override
  Future<void> set(bool value) async => state = value;
}

/// The three rows a browser adds to the Sync page (issue #4121): which
/// storage the database landed in, the remember switch, and Forget this
/// device behind a confirmation.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  late int forgets;

  setUp(() => forgets = 0);
  tearDown(WebDatabaseStatusHolder.clear);

  Future<void> pump(
    WidgetTester tester, {
    WebDatabaseStatus? status,
    Future<void> Function()? forget,
  }) async {
    if (status != null) WebDatabaseStatusHolder.record(status);
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          deviceCapabilitiesProvider.overrideWithValue(DeviceCapabilities.web),
          rememberCredentialsProvider.overrideWith(_RecordingRemember.new),
          webForgetDeviceProvider.overrideWithValue(
            forget ?? () async => forgets++,
          ),
        ],
        child: const WebSyncRows(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('names file storage', (tester) async {
    await pump(
      tester,
      status: const WebDatabaseStatus(storage: WebDatabaseStorage.opfsLocks),
    );
    expect(find.text(en.web_storage_title), findsOneWidget);
    expect(find.text(en.web_storage_opfs), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsNothing);
  });

  testWidgets('names the slower browser database', (tester) async {
    await pump(
      tester,
      status: const WebDatabaseStatus(
        storage: WebDatabaseStorage.sharedIndexedDb,
      ),
    );
    expect(find.text(en.web_storage_indexedDb), findsOneWidget);
  });

  testWidgets('warns when nothing outlives the tab', (tester) async {
    await pump(
      tester,
      status: const WebDatabaseStatus(storage: WebDatabaseStorage.inMemory),
    );
    expect(find.text(en.web_storage_memoryWarning), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  testWidgets('the remember switch toggles the provider', (tester) async {
    await pump(tester);
    expect(find.text(en.web_rememberOnThisDevice_title), findsOneWidget);
    final toggle = find.byType(SwitchListTile);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
  });

  testWidgets('the remember switch says the dives stay (#4187)', (
    tester,
  ) async {
    await pump(
      tester,
      status: const WebDatabaseStatus(storage: WebDatabaseStorage.opfsLocks),
    );
    expect(find.text(en.web_rememberOnThisDevice_subtitle), findsOneWidget);
  });

  testWidgets('with nothing kept after the tab, the remember switch does not '
      'promise the dives stay (#4187)', (tester) async {
    await pump(
      tester,
      status: const WebDatabaseStatus(storage: WebDatabaseStorage.inMemory),
    );
    expect(
      find.text(en.web_rememberOnThisDevice_subtitleInMemory),
      findsOneWidget,
    );
    expect(find.text(en.web_rememberOnThisDevice_subtitle), findsNothing);
  });

  testWidgets('in demo mode Forget this device is unavailable (#4187)', (
    tester,
  ) async {
    DemoModeGate.instance.debugActive = true;
    addTearDown(applyGlobalTestDefaults);
    await pump(tester);
    final row = find.ancestor(
      of: find.text(en.web_forgetDevice_title),
      matching: find.byType(ListTile),
    );
    expect(tester.widget<ListTile>(row).enabled, isFalse);
    expect(find.text(en.demo_row_unavailable), findsOneWidget);
    await tester.tap(row, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text(en.web_forgetDevice_confirmBody), findsNothing);
    expect(forgets, 0);
  });

  testWidgets('Forget this device asks first', (tester) async {
    await pump(tester);
    await tester.tap(find.text(en.web_forgetDevice_title));
    await tester.pumpAndSettle();
    expect(find.text(en.web_forgetDevice_confirmBody), findsOneWidget);
    await tester.tap(find.text(en.common_action_cancel));
    await tester.pumpAndSettle();
    expect(forgets, 0);
    await tester.tap(find.text(en.web_forgetDevice_title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.web_forgetDevice_confirm));
    await tester.pumpAndSettle();
    expect(forgets, 1);
  });

  testWidgets('a database that will not go is reported', (tester) async {
    await pump(tester, forget: () async => throw StateError('still there'));
    await tester.tap(find.text(en.web_forgetDevice_title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.web_forgetDevice_confirm));
    await tester.pumpAndSettle();
    expect(find.text(en.web_forgetDevice_failed), findsOneWidget);
  });

  testWidgets('sign-in details that will not go are reported as such', (
    tester,
  ) async {
    await pump(
      tester,
      forget: () async =>
          throw const WebForgetIncompleteException(['clear secure storage']),
    );
    await tester.tap(find.text(en.web_forgetDevice_title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.web_forgetDevice_confirm));
    await tester.pumpAndSettle();
    expect(find.text(en.web_forgetDevice_incomplete), findsOneWidget);
    expect(find.text(en.web_forgetDevice_failed), findsNothing);
  });
}
