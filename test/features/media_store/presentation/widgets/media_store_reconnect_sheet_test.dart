import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media_store/domain/media_store_reconnect_situation.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_reconnect_provider.dart';
import 'package:submersion/features/media_store/presentation/providers/photos_copies_provider.dart';
import 'package:submersion/features/media_store/presentation/widgets/media_store_reconnect_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/fake_media_store_reconnect.dart';

Widget _host(
  FakeMediaStoreReconnect fake, {
  bool openPhotosPage = true,
  bool runtimeFails = false,
}) => ProviderScope(
  overrides: [
    mediaStoreReconnectProvider.overrideWithValue(fake),
    mediaStoreRuntimeProvider.overrideWith(
      (ref) async => runtimeFails ? throw StateError('no runtime') : null,
    ),
    photosCopiesProvider.overrideWith(
      (ref) async =>
          (attached: true, store: null, group: null, label: 'Dropbox'),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => showMediaStoreReconnectSheet(
            context,
            account: 'Dropbox',
            openPhotosPage: openPhotosPage,
          ),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

Future<FakeMediaStoreReconnect> _open(
  WidgetTester tester,
  List<MediaStoreReconnectSituation> situations, {
  bool openPhotosPage = true,
  bool runtimeFails = false,
}) async {
  final fake = FakeMediaStoreReconnect(situations);
  await tester.pumpWidget(
    _host(fake, openPhotosPage: openPhotosPage, runtimeFails: runtimeFails),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('another store the library knows offers joining it', (
    tester,
  ) async {
    final fake = await _open(tester, const [
      ReconnectOtherStore(storeId: 'store-b', knownToLibrary: true),
    ]);

    expect(
      find.text('Dropbox now holds copies set up by another of your devices.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Photos already there stay. Anything missing uploads again from '
        'this device.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reconnect-rebuild')), findsNothing);
    expect(find.byKey(const Key('reconnect-held-only')), findsNothing);

    await tester.tap(find.byKey(const Key('reconnect-adopt')));
    await tester.pumpAndSettle();

    expect(fake.reconnectCalls, 1);
    expect(find.byKey(const Key('reconnect-adopt')), findsNothing);
    expect(find.text('Now using the copies in Dropbox'), findsOneWidget);
  });

  testWidgets('a store the library has no record of warns before adopting', (
    tester,
  ) async {
    await _open(tester, const [
      ReconnectOtherStore(storeId: 'store-x', knownToLibrary: false),
    ]);

    expect(
      find.text('Dropbox now holds copies this logbook has no record of.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Choose this only if Dropbox is meant for this'),
      findsOneWidget,
    );
  });

  testWidgets('no marker offers starting the copies again, never adopting', (
    tester,
  ) async {
    final fake = await _open(tester, const [ReconnectNoMarker()]);
    fake.createsNewStore = true;

    expect(find.byKey(const Key('reconnect-adopt')), findsNothing);
    expect(
      find.text('The copies in Dropbox were removed or reset.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('reconnect-rebuild')));
    await tester.pumpAndSettle();

    expect(fake.reconnectCalls, 1);
    expect(find.text('New copies started in Dropbox'), findsOneWidget);
  });

  testWidgets('says what only the cloud holds', (tester) async {
    await _open(tester, const [ReconnectNoMarker(heldOnlyInCloud: 5)]);

    expect(
      find.text(
        '5 photos and videos are kept only in the cloud. They open again '
        'only if the account still holds them.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a marker that matches again needs no choice', (tester) async {
    await _open(tester, const [ReconnectResolved()]);

    expect(
      find.text(
        'The copies in Dropbox match this device again. Uploads resume.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('reconnect-detach')), findsNothing);

    await tester.tap(find.byKey(const Key('reconnect-close')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reconnect-close')), findsNothing);
  });

  testWidgets('an unreadable store shows the error and checks again', (
    tester,
  ) async {
    final fake = await _open(tester, const [
      ReconnectUnreadable('network down'),
      ReconnectOtherStore(storeId: 'store-b', knownToLibrary: true),
    ]);

    expect(find.text('Could not check Dropbox.'), findsOneWidget);
    expect(find.text('network down'), findsOneWidget);
    expect(find.byKey(const Key('reconnect-adopt')), findsNothing);

    final gate = fake.inspectGate = Completer<void>();
    await tester.tap(find.byKey(const Key('reconnect-retry')));
    await tester.pump();

    // Checking again, not the stale answer with its Try again.
    expect(find.byKey(const Key('reconnect-checking')), findsOneWidget);
    expect(find.byKey(const Key('reconnect-retry')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();

    expect(fake.inspectCalls, 2);
    expect(find.byKey(const Key('reconnect-adopt')), findsOneWidget);
  });

  testWidgets('no usable account offers choosing it again, not adopting', (
    tester,
  ) async {
    await _open(tester, const [ReconnectNeedsAccount()]);

    expect(find.byKey(const Key('reconnect-choose-account')), findsOneWidget);
    expect(find.byKey(const Key('reconnect-adopt')), findsNothing);
    expect(find.byKey(const Key('reconnect-rebuild')), findsNothing);
    expect(find.byKey(const Key('reconnect-detach')), findsOneWidget);
  });

  testWidgets('choosing the account again closes, then hands back', (
    tester,
  ) async {
    var chosen = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mediaStoreReconnectProvider.overrideWithValue(
            FakeMediaStoreReconnect(const [ReconnectNeedsAccount()]),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => MediaStoreReconnectSheet(
                    account: 'Dropbox',
                    onChooseAccount: () => chosen++,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This device can no longer open the account the copies were in.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('reconnect-choose-account')));
    await tester.pumpAndSettle();

    expect(chosen, 1);
    expect(find.byKey(const Key('reconnect-choose-account')), findsNothing);
  });

  testWidgets('stopping keeps nothing attached and closes', (tester) async {
    final fake = await _open(tester, const [ReconnectNoMarker()]);

    await tester.tap(find.byKey(const Key('reconnect-detach')));
    await tester.pumpAndSettle();

    expect(fake.detachCalls, 1);
    expect(find.byKey(const Key('reconnect-detach')), findsNothing);
  });

  // Code review: a sheet dragged away while the attach runs must not pop
  // the page beneath it when the attach finishes.
  testWidgets('a sheet closed mid-reconnect leaves the page beneath', (
    tester,
  ) async {
    final fake = await _open(tester, const [
      ReconnectOtherStore(storeId: 'store-b', knownToLibrary: true),
    ]);
    final gate = fake.gate = Completer<void>();

    await tester.tap(find.byKey(const Key('reconnect-adopt')));
    await tester.pump();
    // Tapping the barrier closes the sheet, as a drag would.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    gate.complete();
    await tester.pumpAndSettle();

    expect(fake.reconnectCalls, 1);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a refused detach says why and keeps the choices', (
    tester,
  ) async {
    final fake = await _open(tester, const [ReconnectNoMarker()]);
    fake.detachFailure = StateError('keychain locked');

    await tester.tap(find.byKey(const Key('reconnect-detach')));
    await tester.pumpAndSettle();

    expect(find.text('Bad state: keychain locked'), findsOneWidget);
    expect(find.byKey(const Key('reconnect-detach')), findsOneWidget);
  });

  // The queue is woken after a match; a runtime that cannot be built is
  // logged, not thrown into the zone.
  testWidgets('a match whose runtime cannot be built still reads whole', (
    tester,
  ) async {
    await _open(tester, const [ReconnectResolved()], runtimeFails: true);

    expect(find.byKey(const Key('reconnect-close')), findsOneWidget);
  });

  // From Photos & videos itself, choosing the account again just closes:
  // the diver is already where the account is chosen.
  testWidgets('choosing the account again from its own page only closes', (
    tester,
  ) async {
    await _open(tester, const [
      ReconnectNeedsAccount(heldOnlyInCloud: 2),
    ], openPhotosPage: false);

    expect(find.byKey(const Key('reconnect-held-only')), findsOneWidget);
    await tester.tap(find.byKey(const Key('reconnect-choose-account')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reconnect-choose-account')), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('a refused reconnect says why and keeps the choices', (
    tester,
  ) async {
    final fake = await _open(tester, const [
      ReconnectOtherStore(storeId: 'store-b', knownToLibrary: true),
    ]);
    fake.reconnectFailure = const MediaStoreException(
      'Dropbox said no',
      kind: MediaStoreErrorKind.auth,
    );

    await tester.tap(find.byKey(const Key('reconnect-adopt')));
    await tester.pumpAndSettle();

    expect(find.text('Dropbox said no'), findsOneWidget);
    final adopt = tester.widget<ListTile>(
      find.byKey(const Key('reconnect-adopt')),
    );
    expect(adopt.enabled, isTrue);
  });
}
