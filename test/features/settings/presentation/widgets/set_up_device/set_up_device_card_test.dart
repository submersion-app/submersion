import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_usage_service.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/settings/data/set_up_card_prefs.dart';
import 'package:submersion/features/settings/domain/setup/set_up_progress.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/pending_setup_items_provider.dart';
import 'package:submersion/features/settings/presentation/providers/set_up_progress_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/providers/sync_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_device_card.dart';
import 'package:submersion/features/settings/presentation/widgets/set_up_device/set_up_step_marks.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../set_up_progress_fixture.dart';

PendingSetupItem _signInItem({
  String id = 'a1',
  AccountKind kind = AccountKind.dropbox,
  Set<AccountUsageKind> usages = const {AccountUsageKind.databaseSync},
  String route = '/settings/cloud-sync',
  String label = 'eric@example.com',
}) => PendingSetupItem(
  kind: SetupItemKind.accountSignIn,
  key: 'account_$id',
  label: label,
  accountKind: kind,
  accountId: id,
  usages: usages,
  route: route,
);

const _attach = PendingSetupItem(
  kind: SetupItemKind.mediaStoreAttach,
  key: 'store_s1',
  label: 'Dropbox',
  route: '/settings/photos-media',
);

const _reconnect = PendingSetupItem(
  kind: SetupItemKind.mediaStoreReconnect,
  key: 'store_marker_s1',
  label: 'Dropbox',
  route: '/settings/photos-media',
);

AccountGroup _groupHolding(String rowId, AccountKind kind) => AccountGroup(
  key: '${kind.name}|$rowId',
  kind: kind,
  label: kind.name,
  rows: [
    ConnectedAccount(
      id: rowId,
      kind: kind,
      label: kind.name,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ],
  status: AccountStatus.needsSignIn,
  usages: const [],
  locations: const {},
  roles: const {},
  usagesKnown: true,
  address: kind.name,
  usageRoles: const {},
  rowStatuses: {rowId: AccountStatus.needsSignIn},
);

void main() {
  late SharedPreferences prefs;
  late List<String> opened;
  late List<AccountGroup> signedIn;
  late int runtimeBuilds;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    opened = [];
    signedIn = [];
    runtimeBuilds = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    required SetUpProgress? progress,
    List<PendingSetupItem> items = const [],
    bool compact = false,
    Locale locale = const Locale('en'),
    List<AccountGroup> groups = const [],
    Future<List<AccountGroup>> Function(Ref ref)? groupsBuild,
    bool googleDriveAvailable = true,
    bool signInSucceeds = true,
  }) async {
    // A phone: the title's device word follows the device.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.display.devicePixelRatio = 1;
    tester.view.display.size = const Size(390, 844);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          setUpProgressProvider.overrideWithValue(progress),
          pendingSetupItemsProvider.overrideWith((ref) async => items),
          accountGroupsOfKindsProvider.overrideWith(
            (ref, kinds) => groupsBuild?.call(ref) ?? Future.value(groups),
          ),
          googleDriveAvailableProvider.overrideWith(
            (ref) async => googleDriveAvailable,
          ),
          mediaStoreRuntimeProvider.overrideWith((ref) async {
            runtimeBuilds++;
            return null;
          }),
        ],
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SetUpDeviceCard(
                compact: compact,
                onOpen: opened.add,
                signInAccount: (context, ref, group) async {
                  signedIn.add(group);
                  return signInSucceeds;
                },
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
      await pump(tester, progress: setUpProgressOf());

      expect(find.text('Set up this phone'), findsOneWidget);
      expect(find.text('0 of 4'), findsOneWidget);
      expect(find.text('Choose where your data is kept'), findsOneWidget);
      expect(find.text('Keep dives on every device'), findsOneWidget);
      expect(find.text('Back up automatically'), findsOneWidget);
      expect(find.text('Share photo copies (optional)'), findsOneWidget);
    });

    testWidgets('reads "Finish setting up" once a step is done, and '
        'Continue opens the next step', (tester) async {
      await pump(tester, progress: setUpProgressOf(accountHere: true));

      expect(find.text('Finish setting up this phone'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      expect(opened, ['/settings/setup?step=sync']);
    });

    // Issue #3482 review: the step's screen-reader label is one translatable
    // string, not words joined in code.
    testWidgets('each step reads its name and mark through one string', (
      tester,
    ) async {
      await pump(tester, progress: setUpProgressOf(accountHere: true));

      expect(
        find.bySemanticsLabel('Choose where your data is kept: Done'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Keep dives on every device: Next'),
        findsOneWidget,
      );
    });

    testWidgets('marks a skipped photo step', (tester) async {
      await pump(tester, progress: setUpProgressOf(photosSkipped: true));
      expect(
        find.bySemanticsLabel('Share photo copies (optional): Skipped'),
        findsOneWidget,
      );
    });

    testWidgets('Hide this card hides it on this device', (tester) async {
      await pump(tester, progress: setUpProgressOf());

      await tester.tap(find.byTooltip('Show menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide this card'));
      await tester.pumpAndSettle();

      expect(prefs.getBool(SetUpCardPrefs.hiddenKey), isTrue);
    });

    // Issue #3482 review: Arabic and Hebrew mirror the card; the title and
    // the step marks start at the same inset from the card's start edge.
    testWidgets('in a right-to-left locale the title lines up with the '
        'marks', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(accountHere: true),
        locale: const Locale('he'),
      );

      final titleRight = tester
          .getTopRight(find.text('סיום ההגדרה של הטלפון הזה'))
          .dx;
      final marksRight = tester.getTopRight(find.byType(SetUpStepMarks)).dx;
      expect(titleRight, marksRight);
    });
  });

  group('the compact card', () {
    testWidgets('shows the title, the count and Continue only', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(accountHere: true),
        compact: true,
      );

      expect(find.text('Finish setting up this phone'), findsOneWidget);
      expect(find.text('1 of 4'), findsOneWidget);
      expect(find.text('Choose where your data is kept'), findsNothing);
      expect(find.byTooltip('Show menu'), findsNothing);

      await tester.tap(find.text('Continue'));
      expect(opened, ['/settings/setup?step=sync']);
    });

    // Issue #3482 review: the compact card draws no steps, so it cannot rely
    // on the photo step to mention the copies the library keeps.
    testWidgets('lists the announced store even while photos is '
        'outstanding', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(accountHere: true),
        compact: true,
        items: [_attach],
      );
      expect(
        find.text('Your other devices keep photo copies in Dropbox.'),
        findsOneWidget,
      );
    });
  });

  group('items that need the diver later', () {
    testWidgets('the line says which feature pauses', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [
          _signInItem(id: 's', label: 'Sync acct'),
          _signInItem(
            id: 'b',
            label: 'Copy acct',
            usages: {AccountUsageKind.backupCopy},
            route: '/settings/backup',
          ),
          _signInItem(
            id: 'sb',
            label: 'Both acct',
            usages: {
              AccountUsageKind.databaseSync,
              AccountUsageKind.backupCopy,
            },
          ),
          _signInItem(
            id: 'l',
            label: 'Club server',
            kind: AccountKind.s3,
            usages: {AccountUsageKind.sharedLibrary},
            route: '/settings/connected-accounts/l',
          ),
        ],
      );

      expect(
        find.text('Sign in to Sync acct again. Sync is paused until you do.'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Sign in to Copy acct again. Backups are paused until you do.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Sign in to Both acct again. Sync and backups are paused until you '
          'do.',
        ),
        findsOneWidget,
      );
      expect(find.text('Sign in to Club server again.'), findsOneWidget);
    });

    testWidgets('Sign in signs in to the account that holds the row', (
      tester,
    ) async {
      final group = _groupHolding('a1', AccountKind.dropbox);
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [_signInItem()],
        groups: [group],
      );

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(signedIn.single.key, group.key);
      expect(opened, isEmpty);
    });

    // Issue #3482 review: nothing on the card's pages watches the account
    // groups; read without a listener, the provider was disposed mid-build
    // and the tap did nothing.
    testWidgets('Sign in keeps the account lookup alive while it reads', (
      tester,
    ) async {
      final group = _groupHolding('a1', AccountKind.dropbox);
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [_signInItem()],
        groupsBuild: (ref) async {
          await Future<void>.delayed(const Duration(milliseconds: 5));
          // Throws on a disposed Ref, as the real lookup's watches do.
          ref.watch(sharedPreferencesProvider);
          return [group];
        },
      );

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(signedIn.single.key, group.key);
    });

    testWidgets('a failed account lookup opens the page that resolves the '
        'item', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [_signInItem()],
        groupsBuild: (ref) async => throw StateError('keychain'),
      );

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(signedIn, isEmpty);
      expect(opened, ['/settings/cloud-sync']);
    });

    testWidgets('a connector item opens its page', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [
          _signInItem(
            kind: AccountKind.adobeLightroom,
            usages: {AccountUsageKind.lightroom},
            route: '/settings/lightroom',
          ),
        ],
      );

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(signedIn, isEmpty);
      expect(opened, ['/settings/lightroom']);
    });

    // Issue #3482 review: a build without the service's client offers no
    // sign-in that would fail at once; the account page says why.
    testWidgets('a build that cannot sign in to the service opens the page '
        'instead', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [_signInItem(kind: AccountKind.googledrive)],
        groups: [_groupHolding('a1', AccountKind.googledrive)],
        googleDriveAvailable: false,
      );

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(signedIn, isEmpty);
      expect(opened, ['/settings/cloud-sync']);
    });

    // Issue #3482 review: the photo copies' store and runtime were built
    // without the account's keys; a sign-in must rebuild them.
    testWidgets('signing in to the photo copies\' account rebuilds their '
        'runtime', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [
          _signInItem(
            usages: {AccountUsageKind.mediaStorage},
            route: '/settings/photos-media',
          ),
        ],
        groups: [_groupHolding('a1', AccountKind.dropbox)],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SetUpDeviceCard)),
      );
      await container.read(mediaStoreRuntimeProvider.future);
      expect(runtimeBuilds, 1);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await container.read(mediaStoreRuntimeProvider.future);

      expect(runtimeBuilds, 2);
    });

    testWidgets('a cancelled sign-in leaves the runtime alone', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [
          _signInItem(
            usages: {AccountUsageKind.mediaStorage},
            route: '/settings/photos-media',
          ),
        ],
        groups: [_groupHolding('a1', AccountKind.dropbox)],
        signInSucceeds: false,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SetUpDeviceCard)),
      );
      await container.read(mediaStoreRuntimeProvider.future);

      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      await container.read(mediaStoreRuntimeProvider.future);

      expect(runtimeBuilds, 1);
    });

    testWidgets('Reconnect opens the item\'s page through the host', (
      tester,
    ) async {
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [_reconnect],
      );

      await tester.tap(find.text('Reconnect'));
      expect(opened, ['/settings/photos-media']);
    });

    testWidgets('dismissing an item records it for this device', (
      tester,
    ) async {
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [_signInItem()],
      );

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
      await pump(
        tester,
        progress: setUpProgressOf(hidden: true),
        items: [dismissed],
      );
      expect(find.textContaining('eric@example.com'), findsNothing);
    });

    testWidgets('the full card leaves the attach item to the photo step '
        'while it is outstanding', (tester) async {
      await pump(tester, progress: setUpProgressOf(), items: [_attach]);
      expect(
        find.text('Your other devices keep photo copies in Dropbox.'),
        findsNothing,
      );
    });

    testWidgets('the attach item shows once photos were skipped, and Set up '
        'opens the photo step', (tester) async {
      await pump(
        tester,
        progress: setUpProgressOf(photosSkipped: true),
        items: [_attach],
      );
      expect(
        find.text('Your other devices keep photo copies in Dropbox.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Set up Photos & videos'), findsOneWidget);
      await tester.tap(find.text('Set up'));
      expect(opened, ['/settings/setup?step=photos']);
    });
  });

  testWidgets('renders nothing with no steps to show and no items', (
    tester,
  ) async {
    await pump(tester, progress: setUpProgressOf(everything: true));
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('renders nothing while the progress is loading', (tester) async {
    await pump(tester, progress: null, items: [_signInItem()]);
    expect(find.byType(Card), findsNothing);
  });
}
