import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_location.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// v293 connected_accounts.location (issue #3482) travels with the roster
/// row, so a second device can sign in to an account another device added by
/// typing only the secret.
void main() {
  late SyncDataSerializer serializer;
  late ConnectedAccountsRepository repo;

  const location = WebDavAccountLocation(
    serverUrl: 'https://cloud.example.com/dav',
    username: 'eric',
    folder: 'Submersion',
  );

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    repo = ConnectedAccountsRepository();
  });

  tearDown(tearDownTestDatabase);

  test('an account\'s location travels with it', () async {
    final a = await repo.create(kind: AccountKind.webdav, label: 'eric @ x');
    await repo.setLocation(a.id, location);

    final fetched = (await serializer.fetchRecord('connectedAccounts', a.id))!;
    expect(fetched['location'], isA<String>());

    await serializer.deleteRecord('connectedAccounts', a.id);
    await serializer.upsertRecord('connectedAccounts', fetched);

    final restored = (await repo.getById(a.id))!.location;
    expect(restored, isA<WebDavAccountLocation>());
    expect(restored!.serverKey, location.serverKey);
  });

  test('a row from a peer that predates the column keeps the local '
      'location', () async {
    final a = await repo.create(kind: AccountKind.webdav, label: 'eric @ x');
    await repo.setLocation(a.id, location);
    final fetched = (await serializer.fetchRecord('connectedAccounts', a.id))!;
    final fromOlderPeer = {...fetched, 'label': 'Renamed'}..remove('location');

    await serializer.upsertRecord('connectedAccounts', fromOlderPeer);

    final account = (await repo.getById(a.id))!;
    expect(account.label, 'Renamed');
    expect(account.location, isA<WebDavAccountLocation>());
  });
}
