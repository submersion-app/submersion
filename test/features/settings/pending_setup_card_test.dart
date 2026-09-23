import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/account_provider_registry.dart';
import 'package:submersion/core/services/accounts/connected_account.dart'
    as domain;
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/pending_setup_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../helpers/test_database.dart';

class _NeedsSignInAdapter extends AccountProviderAdapter {
  @override
  AccountKind get kind => AccountKind.s3;

  @override
  Future<AccountStatus> status(domain.ConnectedAccount account) async =>
      AccountStatus.needsSignIn;

  @override
  Future<void> disconnect(domain.ConnectedAccount account) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => tearDownTestDatabase());

  Widget app() => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      accountProviderRegistryProvider.overrideWithValue(
        AccountProviderRegistry([_NeedsSignInAdapter()]),
      ),
    ],
    child: const MaterialApp(
      // Pinned: the assertions match English strings.
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PendingSetupCard()),
    ),
  );

  testWidgets('renders nothing when there is nothing to set up', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Finish setting up this device'), findsNothing);
  });

  testWidgets('shows the store attach item and dismisses it', (tester) async {
    await tester.runAsync(
      () => MediaStoresRepository().upsertActive(
        storeId: 'store-1',
        providerType: 's3',
        displayHint: 'dive-media @ minio',
      ),
    );

    await tester.pumpWidget(app());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(find.text('Finish setting up this device'), findsOneWidget);
    expect(
      find.text('Connect media storage (dive-media @ minio)'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();

    expect(find.text('Finish setting up this device'), findsNothing);
    expect(prefs.getBool('setup_item_dismissed_store_store-1'), isTrue);
  });

  // The card follows every local write while it is showing, not only the
  // first after it opened (issue #2304): each write fires the sync event
  // bus, and each must reach the card.
  testWidgets('follows every change while it is showing', (tester) async {
    Future<void> announce(String storeId, String hint) async {
      await tester.runAsync(
        () => MediaStoresRepository().upsertActive(
          storeId: storeId,
          providerType: 's3',
          displayHint: hint,
        ),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      await tester.pump();
    }

    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Finish setting up this device'), findsNothing);

    await announce('store-1', 'first @ minio');
    expect(find.text('Connect media storage (first @ minio)'), findsOneWidget);

    // The same store re-announced under a new hint: a second write that
    // fires the bus, with no two descriptors tying on their timestamps.
    await announce('store-1', 'second @ minio');
    expect(find.text('Connect media storage (second @ minio)'), findsOneWidget);
    expect(find.text('Connect media storage (first @ minio)'), findsNothing);
  });

  // The preflight remembered a store that no longer carries this device's
  // marker (media sync program spec 7.1).
  testWidgets('shows the reconnect item for a remembered marker mismatch', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await MediaStoresRepository().upsertActive(
        storeId: 'store-1',
        providerType: 's3',
        displayHint: 'dive-media @ minio',
      );
      final attach = MediaStoreAttachState(prefs: prefs);
      await attach.setAttached('store-1', providerType: CloudProviderType.s3);
      await attach.setMarkerMismatch(true);
    });

    await tester.pumpWidget(app());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();

    expect(
      find.text('Reconnect media storage (dive-media @ minio)'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.sync_problem_outlined), findsOneWidget);
  });

  // The preflight finds the mismatch while Settings may already be open. The
  // card must pick it up then, and drop it when a reconnect clears it,
  // without waiting for the screen to be reopened.
  testWidgets('a mismatch found while the card is showing appears, and a '
      'reconnect clears it', (tester) async {
    final attach = MediaStoreAttachState(prefs: prefs);
    await tester.runAsync(() async {
      await MediaStoresRepository().upsertActive(
        storeId: 'store-1',
        providerType: 's3',
        displayHint: 'dive-media @ minio',
      );
      await attach.setAttached('store-1', providerType: CloudProviderType.s3);
    });
    await tester.pumpWidget(app());
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.byIcon(Icons.sync_problem_outlined), findsNothing);

    await tester.runAsync(() => attach.setMarkerMismatch(true));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Reconnect media storage (dive-media @ minio)'),
      findsOneWidget,
    );

    await tester.runAsync(
      () => attach.setAttached('store-1', providerType: CloudProviderType.s3),
    );
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.sync_problem_outlined), findsNothing);
  });
}
