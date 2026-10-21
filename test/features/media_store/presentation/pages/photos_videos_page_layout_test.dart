// Issue #3482 phase 4: one Photos & videos page. Where copies are kept and
// what is true of them come first, chosen through the account sheet, then
// how uploads run, where photos come from, and Advanced (spec section 8.3).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/services/accounts/pending_setup_service.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/data/media_store_account_attach.dart';
import 'package:submersion/features/media_store/data/media_store_service.dart';
import 'package:submersion/features/media_store/domain/media_transfer_hold.dart';
import 'package:submersion/features/media_store/domain/media_transfer_summary.dart';
import 'package:submersion/features/media_store/presentation/pages/photos_videos_page.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_upload_progress_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _t = DateTime.utc(2026);

AccountGroup _group(String id, AccountKind kind, String label) => groupAccounts(
  rows: [
    ConnectedAccount(
      id: id,
      kind: kind,
      label: label,
      createdAt: _t,
      updatedAt: _t,
    ),
  ],
  statusById: {id: AccountStatus.signedIn},
  localLocationById: const {},
  usagesOf: (_) => const [],
).single;

final _dropbox = _group('db-row', AccountKind.dropbox, 'Dropbox');
final _drive = _group('gd-row', AccountKind.googledrive, 'Google Drive');

/// Records attaches and switches instead of reaching a store.
class _Attach extends Fake implements MediaStoreAccountAttach {
  final attached = <String>[];
  final storeAccountIds = <String?>[];
  final switched = <String>[];
  Object? failure;
  MediaStoreConnectResult? result;

  static const _result = MediaStoreConnectResult(
    storeId: 's1',
    createdNewStore: false,
  );

  @override
  Future<MediaStoreConnectResult> attach(
    AccountGroup group, {
    String? storeAccountId,
    String? storeId,
  }) async {
    attached.add(group.key);
    storeAccountIds.add(storeAccountId);
    if (failure case final f?) throw f;
    return result ?? _result;
  }

  @override
  Future<MediaStoreConnectResult> switchTo(AccountGroup group) async {
    switched.add(group.key);
    if (failure case final f?) throw f;
    return _result;
  }
}

PhotosCopies _copies({
  bool attached = true,
  AccountGroup? group,
  String? label,
  bool announced = true,
}) => (
  attached: attached,
  store: announced || attached
      ? (
          id: 's1',
          providerType: 'dropbox',
          displayHint: label ?? group?.label ?? 'Dropbox',
          lastSweepAt: null,
          accountId: group?.rows.first.id,
        )
      : null,
  group: group,
  label: label ?? group?.label,
);

void main() {
  late SharedPreferences prefs;
  late _Attach attach;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    attach = _Attach();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required PhotosCopies copies,
    bool? reachable = true,
    ({int copied, int total})? progress = (copied: 7, total: 10),
    MediaTransferSummary summary = const MediaTransferSummary(),
    List<PendingSetupItem> items = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          photosCopiesProvider.overrideWith((ref) async => copies),
          photosStoreReachableProvider.overrideWithValue(reachable),
          mediaUploadProgressProvider.overrideWith((ref) async => progress!),
          mediaTransferSummaryProvider.overrideWith(
            (ref) => Stream.value(summary),
          ),
          mediaStoreRuntimeProvider.overrideWith((ref) async => null),
          pendingSetupItemsProvider.overrideWith((ref) async => items),
          accountGroupsProvider.overrideWith((ref) async => [_dropbox, _drive]),
          offerableAccountKindsProvider.overrideWithValue(const []),
          mediaStoreAccountAttachProvider.overrideWithValue(attach),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PhotosVideosPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double y(WidgetTester tester, Finder f) => tester.getTopLeft(f).dy;

  testWidgets('copies, status, uploads, sources, then Advanced', (
    tester,
  ) async {
    await pumpPage(tester, copies: _copies(group: _dropbox));

    final order = [
      find.text('Copies in the cloud'),
      find.text('Copies in Dropbox'),
      find.text('7 of 10 copied'),
      find.text('Upload new photos automatically'),
      find.text('Uploads'),
      find.text('Where photos come from'),
      find.text('Photo library and files'),
      find.text('Advanced'),
      find.text('Upload quality'),
      find.text('Upload everything already attached'),
      find.text('Verify the copies'),
      find.text('Show source badges on thumbnails'),
      find.text('Stop keeping copies on this device'),
    ];
    for (final f in order) {
      expect(f, findsOneWidget, reason: '$f');
    }
    final ys = [for (final f in order) y(tester, f)];
    expect(ys, [...ys]..sort());
    // Kept until phase 6's card replaces it.
    expect(find.byIcon(Icons.checklist_outlined), findsOneWidget);
  });

  group('the Using row', () {
    testWidgets('nothing set up offers Set up, and no copy controls', (
      tester,
    ) async {
      await pumpPage(
        tester,
        copies: _copies(attached: false, announced: false),
      );
      expect(find.text('Not set up'), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);
      expect(find.text('Upload new photos automatically'), findsNothing);
      expect(find.text('Stop keeping copies on this device'), findsNothing);
      // The report still shows: a device with no copies may be asking why.
      expect(find.byKey(const Key('media-export-report')), findsOneWidget);
    });

    testWidgets('a store this device has not joined says finish setting up', (
      tester,
    ) async {
      await pumpPage(tester, copies: _copies(attached: false, group: _dropbox));
      expect(find.text('Copies in Dropbox'), findsOneWidget);
      expect(find.text('Set up'), findsOneWidget);
      expect(find.text('Finish setting up this device'), findsOneWidget);
    });

    testWidgets('a store with no recorded account shows its hint', (
      tester,
    ) async {
      await pumpPage(tester, copies: _copies(label: 'media @ minio'));
      expect(find.text('Copies in media @ minio'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);
    });

    testWidgets('an attached device with no account name still offers '
        'Change', (tester) async {
      await pumpPage(
        tester,
        copies: (attached: true, store: null, group: null, label: null),
      );
      expect(find.text('Not set up'), findsNothing);
      expect(find.text('Change'), findsOneWidget);
    });
  });

  group('choosing where copies go', () {
    Finder inSheet(String text) => find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(text),
    );

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('photos-using-change')));
      await tester.pumpAndSettle();
    }

    // Choosing the account in use again is how a marker mismatch or an
    // unreachable store is recovered, so it attaches again.
    testWidgets('the account in use attaches again', (tester) async {
      await pumpPage(tester, copies: _copies(group: _dropbox));
      await open(tester);

      await tester.tap(inSheet('Dropbox'));
      await tester.pumpAndSettle();

      expect(attach.attached, [_dropbox.key]);
      expect(attach.storeAccountIds, ['db-row']);
      expect(attach.switched, isEmpty);
    });

    testWidgets('Set up joins the copies in the account they record', (
      tester,
    ) async {
      await pumpPage(tester, copies: _copies(attached: false, group: _dropbox));
      await open(tester);

      await tester.tap(inSheet('Dropbox'));
      await tester.pumpAndSettle();

      expect(find.text('Continue'), findsNothing);
      expect(attach.attached, [_dropbox.key]);
      expect(attach.storeAccountIds, ['db-row']);
    });

    testWidgets('Set up in another account than the library copies explains '
        'first', (tester) async {
      await pumpPage(tester, copies: _copies(attached: false, group: _dropbox));
      await open(tester);

      await tester.tap(inSheet('Google Drive'));
      await tester.pumpAndSettle();
      expect(find.textContaining('starts separate copies'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(attach.attached, [_drive.key]);
    });

    testWidgets('a store with no recorded account names it once', (
      tester,
    ) async {
      await pumpPage(tester, copies: _copies(label: 'Dropbox'));
      await open(tester);

      await tester.tap(inSheet('Dropbox'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('starts or joins copies in Dropbox'),
        findsOneWidget,
      );
      expect(find.textContaining('stops using the copies in'), findsNothing);
    });

    testWidgets('another account explains first, then switches', (
      tester,
    ) async {
      await pumpPage(tester, copies: _copies(group: _dropbox));
      await open(tester);

      await tester.tap(inSheet('Google Drive'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('stops using the copies in Dropbox'),
        findsOneWidget,
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(attach.switched, [_drive.key]);
      expect(find.text('Copies set up in Google Drive'), findsOneWidget);
    });

    testWidgets('Set up attaches through the chosen account', (tester) async {
      await pumpPage(
        tester,
        copies: _copies(attached: false, announced: false),
      );
      await open(tester);

      await tester.tap(inSheet('Dropbox'));
      await tester.pumpAndSettle();

      expect(attach.attached, [_dropbox.key]);
    });

    // Two logins of one kind share a roster row, so the row cannot promise
    // the copies are there: an account that held none says a second set
    // was started rather than claim the join.
    testWidgets('joining an account that held no copies says so', (
      tester,
    ) async {
      attach.result = const MediaStoreConnectResult(
        storeId: 'minted',
        createdNewStore: true,
      );
      await pumpPage(tester, copies: _copies(attached: false, group: _dropbox));
      await open(tester);

      await tester.tap(inSheet('Dropbox'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'No copies were found in Dropbox, so this device started separate '
          'copies there.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('an account with no keys here asks to sign in', (tester) async {
      attach.failure = const MediaStoreAccountUnusable(
        'Dropbox is not signed in on this device',
      );
      await pumpPage(
        tester,
        copies: _copies(attached: false, announced: false),
      );
      await open(tester);

      await tester.tap(inSheet('Dropbox'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in to Dropbox'), findsOneWidget);
    });

    testWidgets('a failed attach says why', (tester) async {
      attach.failure = const MediaStoreException(
        'Dropbox is not signed in',
        kind: MediaStoreErrorKind.auth,
      );
      await pumpPage(
        tester,
        copies: _copies(attached: false, announced: false),
      );
      await open(tester);

      await tester.tap(inSheet('Dropbox'));
      await tester.pumpAndSettle();

      expect(find.text('Dropbox is not signed in'), findsOneWidget);
    });
  });

  group('the status line', () {
    Future<void> pumpStatus(
      WidgetTester tester, {
      bool? reachable = true,
      MediaTransferSummary summary = const MediaTransferSummary(),
      List<PendingSetupItem> items = const [],
    }) => pumpPage(
      tester,
      copies: _copies(group: _dropbox),
      reachable: reachable,
      summary: summary,
      items: items,
    );

    MediaTransferSummary held(MediaTransferHoldKind kind) =>
        MediaTransferSummary(queued: 1, hold: MediaTransferHold(kind, 'x'));

    const reconnectItem = PendingSetupItem(
      kind: SetupItemKind.mediaStoreReconnect,
      key: 'store_marker_s1',
      label: 'Dropbox',
      route: '/settings/photos-media',
    );

    testWidgets('checking', (tester) async {
      await pumpStatus(tester, reachable: null);
      expect(find.text('Checking…'), findsOneWidget);
    });

    testWidgets('unreachable with no account name still reads whole', (
      tester,
    ) async {
      await pumpPage(
        tester,
        copies: (attached: true, store: null, group: null, label: null),
        reachable: false,
      );
      expect(
        find.text('Uploads paused: the account could not be checked'),
        findsOneWidget,
      );
    });

    testWidgets('unreachable names the account', (tester) async {
      await pumpStatus(tester, reachable: false);
      expect(find.text('Could not reach Dropbox'), findsOneWidget);
    });

    // The preflight that finds a mismatch also yields the reconnect item,
    // so the two always arrive together.
    testWidgets('a marker mismatch asks to choose the account again', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        summary: held(MediaTransferHoldKind.markerMismatch),
        items: const [reconnectItem],
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('photos-status')),
          matching: find.text('Uploads paused: choose the account again'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('detached says so', (tester) async {
      await pumpStatus(tester, summary: held(MediaTransferHoldKind.detached));
      expect(
        find.text(
          'Uploads paused: this device is not connected to these copies',
        ),
        findsOneWidget,
      );
    });

    testWidgets('offline waits for a connection', (tester) async {
      await pumpStatus(tester, summary: held(MediaTransferHoldKind.offline));
      expect(find.text('Waiting for a connection'), findsOneWidget);
    });

    testWidgets('parked rows wait to retry', (tester) async {
      await pumpStatus(tester, summary: const MediaTransferSummary(waiting: 3));
      expect(find.text('3 waiting to retry'), findsOneWidget);
    });

    testWidgets('moving rows show the copied count and how many move', (
      tester,
    ) async {
      await pumpStatus(
        tester,
        summary: const MediaTransferSummary(transferring: 1, queued: 2),
      );
      expect(find.text('7 of 10 copied, 3 uploading'), findsOneWidget);
    });

    testWidgets('a pending reconnect asks to choose the account again', (
      tester,
    ) async {
      await pumpStatus(tester, items: const [reconnectItem]);
      expect(
        find.descendant(
          of: find.byKey(const Key('photos-status')),
          matching: find.text('Uploads paused: choose the account again'),
        ),
        findsOneWidget,
      );
      // The pending setup card above still offers the reconnect itself.
      expect(
        find.descendant(
          of: find.byKey(const Key('photos-status')),
          matching: find.text('Finish setting up this device'),
        ),
        findsNothing,
      );
    });

    // A library that announces another store raises an attach item, but
    // this device is attached and uploading, and says so without alarm.
    testWidgets('attached, an attach item for another store does not mask '
        'uploads', (tester) async {
      await pumpStatus(
        tester,
        summary: const MediaTransferSummary(transferring: 1, queued: 2),
        items: const [
          PendingSetupItem(
            kind: SetupItemKind.mediaStoreAttach,
            key: 'store_s2',
            label: 'Google Drive',
            route: '/settings/photos-media',
          ),
        ],
      );
      final line = find.byKey(const Key('photos-status'));
      expect(
        find.descendant(
          of: line,
          matching: find.text('7 of 10 copied, 3 uploading'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: line, matching: find.byIcon(Icons.error_outline)),
        findsNothing,
      );
    });
  });
}
