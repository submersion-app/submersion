import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/core/platform/web/remember_credentials_provider.dart';
import 'package:submersion/core/platform/web_database_status.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/features/demo_mode/domain/demo_manifest.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_flow_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_account_step.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_navigation.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _t = DateTime.utc(2026);

AccountGroup _group(
  String id,
  AccountKind kind,
  String label, {
  AccountStatus status = AccountStatus.signedIn,
}) => groupAccounts(
  rows: [
    ConnectedAccount(
      id: id,
      kind: kind,
      label: label,
      createdAt: _t,
      updatedAt: _t,
    ),
  ],
  statusById: {id: status},
  localLocationById: const {},
  usagesOf: (_) => const [],
).single;

final _drive = _group('gd', AccountKind.googledrive, 'Google Drive');
final _dropbox = _group(
  'db',
  AccountKind.dropbox,
  'Dropbox',
  status: AccountStatus.needsSignIn,
);

class _RecordingRemember extends RememberCredentialsNotifier {
  @override
  bool build() => false;

  @override
  Future<void> set(bool value) async => state = value;
}

void main() {
  late SharedPreferences prefs;
  late ProviderContainer container;
  late List<String> calls;

  Future<void> pump(
    WidgetTester tester, {
    List<AccountGroup> groups = const [],
    String? Function(AccountGroup)? consequenceOf,
    SetUpHost host = SetUpHost.settingsPage,
    bool browser = false,
    VoidCallback? onNoLibrary,
    DemoPackage? demoPackage,
  }) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    calls = [];
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          if (browser) ...[
            deviceCapabilitiesProvider.overrideWithValue(
              DeviceCapabilities.web,
            ),
            // Natively the switch has nothing to move; this stand-in keeps
            // what the step sets so the wiring shows.
            rememberCredentialsProvider.overrideWith(_RecordingRemember.new),
            demoAvailabilityProvider.overrideWith((ref) async => demoPackage),
          ],
          accountGroupsProvider.overrideWith((ref) async => groups),
          offerableAccountKindsProvider.overrideWithValue(const [
            AccountKindOffer.icloud,
            AccountKindOffer.googleDrive,
            AccountKindOffer.dropbox,
            AccountKindOffer.ownServer,
          ]),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SetUpAccountStep(
              navigation: SetUpStepNavigation(
                onNext: () => calls.add('next'),
                onBack: () => calls.add('back'),
                onNotNow: () => calls.add('notNow'),
                onNoLibrary: onNoLibrary,
                host: host,
              ),
              consequenceOf: consequenceOf ?? (_) => null,
              onRestoreFile: () async => calls.add('restore'),
              onTryDemo: (package) => calls.add('demo ${package.size}'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(SetUpAccountStep)),
    );
  }

  testWidgets('asks where the data is kept, and says there is no server '
      'of its own', (tester) async {
    await pump(tester);

    expect(find.text('Where should Submersion keep your data?'), findsOne);
    expect(
      find.text(
        'Your dives are stored only in the account you choose. Submersion '
        'has no server of its own.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('offers each kind with what signing in to it takes', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Uses your Apple ID. Nothing to sign in to.'), findsOne);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign in with Dropbox'), findsOneWidget);
    expect(find.text('S3-compatible storage or a WebDAV server'), findsOne);
  });

  testWidgets('lists the accounts signed in here first', (tester) async {
    await pump(tester, groups: [_dropbox, _drive]);

    expect(
      tester.getTopLeft(find.text('Google Drive').first).dy,
      lessThan(tester.getTopLeft(find.text('Dropbox').first).dy),
    );
  });

  testWidgets('choosing an account holds it for the next steps and writes '
      'nothing', (tester) async {
    await pump(tester, groups: [_drive]);

    await tester.tap(find.text('Google Drive').first);
    await tester.pumpAndSettle();

    expect(container.read(setUpFlowProvider)?.key, _drive.key);
    expect(calls, ['next']);
    expect(container.read(selectedCloudProviderTypeProvider), isNull);
    expect(prefs.getKeys(), isEmpty);
  });

  testWidgets('a choice that would switch sync says so first', (tester) async {
    await pump(
      tester,
      groups: [_drive],
      consequenceOf: (choice) => 'Sync moves to ${choice.label}.',
    );

    await tester.tap(find.text('Google Drive').first);
    await tester.pumpAndSettle();
    expect(find.text('Sync moves to Google Drive.'), findsOneWidget);
    expect(calls, isEmpty);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(calls, ['next']);
    expect(container.read(setUpFlowProvider)?.key, _drive.key);
  });

  testWidgets('Next continues with the account already chosen', (tester) async {
    await pump(tester, groups: [_drive]);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
      reason: 'nothing chosen yet',
    );

    container.read(setUpFlowProvider.notifier).choose(_drive);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    expect(calls, ['next']);
  });

  testWidgets('Not now leaves the flow', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Not now'));
    expect(calls, ['back']);
  });

  testWidgets('a backup file restores instead', (tester) async {
    await pump(tester);
    await tester.tap(find.text('I have a backup file instead'));
    expect(calls, ['restore']);
  });

  group('in the first-run wizard', () {
    testWidgets('offers no backup file: the wizard has its own restore', (
      tester,
    ) async {
      await pump(tester, host: SetUpHost.firstRun);

      expect(find.text('I have a backup file instead'), findsNothing);
    });

    testWidgets('Back goes back, and Not now moves on', (tester) async {
      await pump(tester, host: SetUpHost.firstRun);

      await tester.tap(find.text('Back'));
      await tester.tap(find.text('Not now'));

      expect(calls, ['back', 'notNow']);
    });
  });

  testWidgets('the Setup assistant keeps the backup file link', (tester) async {
    await pump(tester, host: SetUpHost.assistant);

    expect(find.text('I have a backup file instead'), findsOneWidget);
  });

  testWidgets('a browser restores a backup file too (#4121)', (tester) async {
    await pump(tester, browser: true);

    await tester.tap(find.text('I have a backup file instead'));
    expect(calls, ['restore']);
    expect(find.text('Not now'), findsOneWidget);
  });

  group('in a browser (#4121)', () {
    testWidgets('offers the remember switch, wired to the provider', (
      tester,
    ) async {
      await pump(tester, browser: true);
      expect(find.text('Remember sign-in on this device'), findsOneWidget);
      final toggle = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(container.read(rememberCredentialsProvider), isTrue);
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    });

    testWidgets('with nothing kept after the tab, the switch does not promise '
        'the dives stay (#4187)', (tester) async {
      WebDatabaseStatusHolder.record(
        const WebDatabaseStatus(storage: WebDatabaseStorage.inMemory),
      );
      addTearDown(WebDatabaseStatusHolder.clear);
      await pump(tester, browser: true);
      final en = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(en.web_rememberOnThisDevice_subtitleInMemory),
        findsOneWidget,
      );
      expect(find.text(en.web_rememberOnThisDevice_subtitle), findsNothing);
    });

    testWidgets('natively there is no remember switch', (tester) async {
      await pump(tester);
      expect(find.text('Remember sign-in on this device'), findsNothing);
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('continue without a sync store stands where Not now was', (
      tester,
    ) async {
      await pump(
        tester,
        browser: true,
        host: SetUpHost.firstRun,
        onNoLibrary: () => calls.add('noLibrary'),
      );
      expect(find.text('Not now'), findsNothing);
      await tester.tap(find.text('Continue without a sync store'));
      expect(calls, ['noLibrary']);
    });

    testWidgets('first run offers the sample logbook the site ships', (
      tester,
    ) async {
      await pump(
        tester,
        browser: true,
        host: SetUpHost.firstRun,
        onNoLibrary: () => calls.add('noLibrary'),
        demoPackage: DemoPackage(
          schemaVersion: 327,
          url: Uri.parse('https://dive.example/demo/submersion_demo.db.gz'),
          sha256: 'a' * 64,
          size: 8075714,
          generatedAt: DateTime.utc(2026, 10, 30),
        ),
      );
      await tester.tap(find.text('Explore with sample data'));
      expect(calls, ['demo 8075714']);
    });

    testWidgets('a site without a sample logbook offers none', (tester) async {
      await pump(
        tester,
        browser: true,
        host: SetUpHost.firstRun,
        onNoLibrary: () => calls.add('noLibrary'),
      );
      expect(find.text('Explore with sample data'), findsNothing);
    });

    testWidgets('first run offers to restore a backup file', (tester) async {
      await pump(
        tester,
        browser: true,
        host: SetUpHost.firstRun,
        onNoLibrary: () => calls.add('noLibrary'),
      );
      expect(find.text('I have a backup file instead'), findsNothing);
      await tester.tap(find.text('Restore a backup file'));
      expect(calls, ['restore']);
    });
  });
}
