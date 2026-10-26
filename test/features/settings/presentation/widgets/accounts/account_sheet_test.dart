// Issue #3482 phase 2: one account sheet behind every picker: the accounts the
// diver has, then the kinds that can be added (spec section 7.4).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/features/shared_library/presentation/widgets/library_location_fields.dart';
import 'package:submersion/features/settings/presentation/widgets/accounts/account_sheet.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _t = DateTime.utc(2026);

AccountGroup _group(
  String id,
  AccountKind kind,
  String label, {
  AccountStatus status = AccountStatus.signedIn,
  AccountLocation? location,
}) => groupAccounts(
  rows: [
    ConnectedAccount(
      id: id,
      kind: kind,
      label: label,
      createdAt: _t,
      updatedAt: _t,
      location: location,
    ),
  ],
  statusById: {id: status},
  localLocationById: const {},
  usagesOf: (_) => const [],
).single;

final _drive = _group('gd', AccountKind.googledrive, 'Google Drive');
final _minio = _group(
  's3',
  AccountKind.s3,
  'dives @ minio.home',
  status: AccountStatus.needsSignIn,
  location: const S3AccountLocation(
    displayHost: 'minio.home',
    endpoint: 'https://minio.home',
    bucket: 'dives',
    region: 'us-east-1',
    prefix: 'submersion-sync/',
    pathStyle: true,
  ),
);

void main() {
  Future<Future<AccountGroup?> Function()> pumpSheet(
    WidgetTester tester, {
    List<AccountGroup> groups = const [],
    List<AccountKindOffer> offers = const [
      AccountKindOffer.icloud,
      AccountKindOffer.googleDrive,
      AccountKindOffer.dropbox,
      AccountKindOffer.ownServer,
    ],
    Set<AccountKind>? allowedKinds,
    String? Function(AccountGroup)? consequenceOf,
  }) async {
    AccountGroup? result;
    var done = false;
    await tester.binding.setSurfaceSize(const Size(500, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accountGroupsProvider.overrideWith((ref) async => groups),
          accountGroupsOfKindsProvider(
            libraryKindsKey,
          ).overrideWith((ref) async => groups),
          offerableAccountKindsProvider.overrideWithValue(offers),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showAccountSheet(
                    context,
                    allowedKinds: allowedKinds,
                    consequenceOf: consequenceOf,
                  );
                  done = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    return () async {
      expect(done, isTrue, reason: 'the sheet is still open');
      return result;
    };
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pump();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('lists accounts, then the kinds that can be added, in order', (
    tester,
  ) async {
    await pumpSheet(tester, groups: [_minio]);
    await open(tester);

    expect(find.text('Your accounts'), findsOneWidget);
    expect(find.text('dives @ minio.home'), findsOneWidget);
    expect(find.text('Add an account'), findsOneWidget);
    final offers = ['iCloud', 'Google Drive', 'Dropbox', 'My own server'];
    final ys = [for (final o in offers) tester.getTopLeft(find.text(o)).dy];
    expect(ys, [...ys]..sort());
    expect(
      tester.getTopLeft(find.text('Your accounts')).dy,
      lessThan(tester.getTopLeft(find.text('Add an account')).dy),
    );
  });

  testWidgets('an existing Google account is not offered again', (
    tester,
  ) async {
    await pumpSheet(tester, groups: [_drive]);
    await open(tester);
    // Listed once, as the diver's account, not again under Add.
    expect(find.text('Google Drive'), findsOneWidget);
  });

  testWidgets('a Git repository can be added again, like an own server', (
    tester,
  ) async {
    final git = _group('git', AccountKind.git, 'you/dive-log @ github.com');
    await pumpSheet(
      tester,
      groups: [git],
      offers: const [AccountKindOffer.ownServer, AccountKindOffer.git],
    );
    await open(tester);
    expect(find.text('you/dive-log @ github.com'), findsOneWidget);
    // Still offered: a second repository or branch is another account.
    expect(find.text('Git'), findsOneWidget);
    expect(find.text('Any Git host'), findsOneWidget);
  });

  testWidgets('a picker for own servers only does not offer Git', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      offers: const [AccountKindOffer.ownServer, AccountKindOffer.git],
      allowedKinds: const {AccountKind.s3, AccountKind.webdav},
    );
    await open(tester);
    expect(find.text('My own server'), findsOneWidget);
    expect(find.text('Git'), findsNothing);
  });

  testWidgets('restricted to S3 and WebDAV only own servers show', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      groups: [_drive, _minio],
      allowedKinds: const {AccountKind.s3, AccountKind.webdav},
    );
    await open(tester);
    expect(find.text('Google Drive'), findsNothing);
    expect(find.text('iCloud'), findsNothing);
    expect(find.text('Dropbox'), findsNothing);
    expect(find.text('dives @ minio.home'), findsOneWidget);
    expect(find.text('My own server'), findsOneWidget);
  });

  testWidgets('a signed-out account says so and signs in first', (
    tester,
  ) async {
    await pumpSheet(tester, groups: [_minio]);
    await open(tester);
    expect(find.text('Sign in to use it here'), findsOneWidget);

    await tester.tap(find.text('dives @ minio.home'));
    await tester.pumpAndSettle();

    // The own server form opens to take the secret.
    expect(find.text('Sign in to dives @ minio.home'), findsOneWidget);
  });

  testWidgets('a signed-in account returns at once', (tester) async {
    final result = await pumpSheet(tester, groups: [_drive]);
    await open(tester);
    await tester.tap(find.text('Google Drive'));
    await tester.pumpAndSettle();
    expect((await result())!.key, _drive.key);
  });

  testWidgets('a consequence shows first, and Cancel returns nothing', (
    tester,
  ) async {
    final result = await pumpSheet(
      tester,
      groups: [_drive],
      consequenceOf: (_) => 'Sync moves to this account.',
    );
    await open(tester);
    await tester.tap(find.text('Google Drive'));
    await tester.pumpAndSettle();

    expect(find.text('Sync moves to this account.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result(), isNull);
  });

  testWidgets('Continue after a consequence returns the account', (
    tester,
  ) async {
    final result = await pumpSheet(
      tester,
      groups: [_drive],
      consequenceOf: (_) => 'Sync moves to this account.',
    );
    await open(tester);
    await tester.tap(find.text('Google Drive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect((await result())!.key, _drive.key);
  });

  testWidgets('iCloud is not offered where it cannot sign in', (tester) async {
    await pumpSheet(
      tester,
      offers: const [AccountKindOffer.googleDrive, AccountKindOffer.ownServer],
    );
    await open(tester);
    expect(find.text('iCloud'), findsNothing);
  });

  testWidgets('an account unavailable here is listed but disabled', (
    tester,
  ) async {
    final icloud = _group(
      'ic',
      AccountKind.icloud,
      'iCloud',
      status: AccountStatus.unavailable,
    );
    await pumpSheet(tester, groups: [icloud], offers: const []);
    await open(tester);
    expect(find.text('Unavailable on this device'), findsOneWidget);
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('iCloud'), matching: find.byType(ListTile)),
    );
    expect(tile.enabled, isFalse);
  });

  group('with a none choice', () {
    Future<Future<AccountSheetChoice?> Function()> pumpNone(
      WidgetTester tester, {
      bool noneSelected = false,
    }) async {
      AccountSheetChoice? result;
      var done = false;
      await tester.binding.setSurfaceSize(const Size(500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountGroupsProvider.overrideWith((ref) async => [_drive]),
            offerableAccountKindsProvider.overrideWithValue(const [
              AccountKindOffer.dropbox,
            ]),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    result = await showAccountOrNoneSheet(
                      context,
                      noneLabel: 'Nowhere else',
                      noneSelected: noneSelected,
                    );
                    done = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      return () async {
        expect(done, isTrue, reason: 'the sheet is still open');
        return result;
      };
    }

    testWidgets('the none choice sits first and returns ChoseNone', (
      tester,
    ) async {
      final result = await pumpNone(tester);
      await open(tester);

      expect(
        tester.getTopLeft(find.text('Nowhere else')).dy,
        lessThan(tester.getTopLeft(find.text('Google Drive')).dy),
      );
      await tester.tap(find.text('Nowhere else'));
      await tester.pumpAndSettle();
      expect(await result(), isA<ChoseNone>());
    });

    testWidgets('an account returns ChoseAccount', (tester) async {
      final result = await pumpNone(tester);
      await open(tester);

      await tester.tap(find.text('Google Drive'));
      await tester.pumpAndSettle();
      final choice = await result();
      expect(choice, isA<ChoseAccount>());
      expect((choice as ChoseAccount).group.key, _drive.key);
    });

    testWidgets('the none choice shows as selected', (tester) async {
      await pumpNone(tester, noneSelected: true);
      await open(tester);

      final tile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Nowhere else'),
          matching: find.byType(ListTile),
        ),
      );
      expect(tile.selected, isTrue);
    });

    testWidgets('backing out returns nothing', (tester) async {
      final result = await pumpNone(tester);
      await open(tester);

      await tester.tapAt(const Offset(250, 20));
      await tester.pumpAndSettle();
      expect(await result(), isNull);
    });
  });
}
