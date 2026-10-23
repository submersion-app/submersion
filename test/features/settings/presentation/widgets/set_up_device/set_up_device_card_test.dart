import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_device_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

SetUpProgress _progress({
  bool accountHere = false,
  bool syncEstablished = false,
  bool photosSkipped = false,
  bool everything = false,
  bool hidden = false,
}) => setUpProgress(
  SetUpInputs(
    accountHere: accountHere || everything,
    syncEstablished: syncEstablished || everything,
    customFolder: false,
    backupsAuto: everything,
    backupOffDevice: everything,
    photosAttached: everything,
    photosSkipped: photosSkipped,
    hidden: hidden,
  ),
);

const _signIn = PendingSetupItem(
  kind: SetupItemKind.accountSignIn,
  key: 'account_a1',
  label: 'eric@example.com',
  accountKind: AccountKind.googledrive,
  accountId: 'a1',
  route: '/settings/cloud-sync',
  pausesSyncOrBackups: true,
);

const _attach = PendingSetupItem(
  kind: SetupItemKind.mediaStoreAttach,
  key: 'store_s1',
  label: 'Dropbox',
  route: '/settings/photos-media',
);

void main() {
  late SharedPreferences prefs;
  late List<SetUpStep> opened;
  late List<PendingSetupItem> signedIn;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    opened = [];
    signedIn = [];
  });

  Future<void> pump(
    WidgetTester tester, {
    required SetUpProgress? progress,
    List<PendingSetupItem> items = const [],
    bool compact = false,
  }) async {
    // A phone: the title's device word follows the screen.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          setUpProgressProvider.overrideWithValue(progress),
          pendingSetupItemsProvider.overrideWith((ref) async => items),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SetUpDeviceCard(
                compact: compact,
                onOpenStep: opened.add,
                onSignIn: (context, item) async => signedIn.add(item),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the full card', () {
    testWidgets('names the device and lists the four steps', (tester) async {
      await pump(tester, progress: _progress());

      expect(find.text('Set up this phone'), findsOneWidget);
      expect(find.text('0 of 4'), findsOneWidget);
      expect(find.text('Choose where your data is kept'), findsOneWidget);
      expect(find.text('Keep dives on every device'), findsOneWidget);
      expect(find.text('Back up automatically'), findsOneWidget);
      expect(find.text('Share photo copies (optional)'), findsOneWidget);
    });

    testWidgets('reads "Finish setting up" once a step is done, and '
        'Continue opens the next step', (tester) async {
      await pump(tester, progress: _progress(accountHere: true));

      expect(find.text('Finish setting up this phone'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Choose where your data is kept.*Done')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('Keep dives on every device.*Next')),
        findsOneWidget,
      );

      await tester.tap(find.text('Continue'));
      expect(opened, [SetUpStep.sync]);
    });

    testWidgets('marks a skipped photo step', (tester) async {
      await pump(tester, progress: _progress(photosSkipped: true));
      expect(
        find.bySemanticsLabel(RegExp('Share photo copies.*Skipped')),
        findsOneWidget,
      );
    });

    testWidgets('Hide this card hides it on this device', (tester) async {
      await pump(tester, progress: _progress());

      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide this card'));
      await tester.pumpAndSettle();

      expect(prefs.getBool(SetUpCardPrefs.hiddenKey), isTrue);
    });
  });

  group('the compact card', () {
    testWidgets('shows the title, the count and Continue only', (tester) async {
      await pump(tester, progress: _progress(accountHere: true), compact: true);

      expect(find.text('Finish setting up this phone'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text('Choose where your data is kept'), findsNothing);
      expect(find.byTooltip('Show menu'), findsNothing);

      await tester.tap(find.text('Continue'));
      expect(opened, [SetUpStep.sync]);
    });
  });

  group('items that need the diver later', () {
    testWidgets('a hidden card still shows a sign-in, and Sign in signs '
        'in', (tester) async {
      await pump(tester, progress: _progress(hidden: true), items: [_signIn]);

      expect(find.text('Set up this phone'), findsNothing);
      expect(
        find.text(
          'Sign in to eric@example.com again. Sync and backups are paused '
          'until you do.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Sign in'));
      expect(signedIn.single.key, 'account_a1');
    });

    testWidgets('an account sync and backups do not use gets the short '
        'line', (tester) async {
      const library = PendingSetupItem(
        kind: SetupItemKind.accountSignIn,
        key: 'account_l1',
        label: 'Club server',
        accountKind: AccountKind.s3,
        accountId: 'l1',
        route: '/settings/connected-accounts/l1',
      );
      await pump(tester, progress: _progress(hidden: true), items: [library]);
      expect(find.text('Sign in to Club server again.'), findsOneWidget);
    });

    testWidgets('the account\'s uses decide the line, not the page that '
        'signs it in', (tester) async {
      const photosAndBackup = PendingSetupItem(
        kind: SetupItemKind.accountSignIn,
        key: 'account_m1',
        label: 'Media server',
        accountKind: AccountKind.s3,
        accountId: 'm1',
        route: '/settings/photos-media',
        pausesSyncOrBackups: true,
      );
      await pump(
        tester,
        progress: _progress(hidden: true),
        items: [photosAndBackup],
      );
      expect(
        find.text(
          'Sign in to Media server again. Sync and backups are paused until '
          'you do.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('dismissing an item records it for this device', (
      tester,
    ) async {
      await pump(tester, progress: _progress(hidden: true), items: [_signIn]);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();

      expect(prefs.getBool('setup_item_dismissed_account_a1'), isTrue);
    });

    testWidgets('a dismissed item is not shown', (tester) async {
      const dismissed = PendingSetupItem(
        kind: SetupItemKind.accountSignIn,
        key: 'account_a1',
        label: 'eric@example.com',
        accountId: 'a1',
        route: '/settings/cloud-sync',
        dismissed: true,
      );
      await pump(tester, progress: _progress(hidden: true), items: [dismissed]);
      expect(find.textContaining('eric@example.com'), findsNothing);
    });

    testWidgets('the attach item waits while the photo step is still '
        'outstanding', (tester) async {
      await pump(tester, progress: _progress(), items: [_attach]);
      expect(
        find.text('Your other devices keep photo copies in Dropbox.'),
        findsNothing,
      );
    });

    testWidgets('the attach item shows once photos were skipped, and Set up '
        'opens the photo step', (tester) async {
      await pump(
        tester,
        progress: _progress(photosSkipped: true),
        items: [_attach],
      );
      expect(
        find.text('Your other devices keep photo copies in Dropbox.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Set up'));
      expect(opened, [SetUpStep.photos]);
    });
  });

  testWidgets('renders nothing with no steps to show and no items', (
    tester,
  ) async {
    await pump(tester, progress: _progress(everything: true));
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('renders nothing while the progress is loading', (tester) async {
    await pump(tester, progress: null, items: [_signIn]);
    expect(find.byType(Card), findsNothing);
  });
}
