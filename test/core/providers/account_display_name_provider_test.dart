import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/connected_accounts_repository.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';

import '../../helpers/test_database.dart';

/// accountDisplayNameProvider names one roster row by its short name and
/// follows a rename (issue #3522).
void main() {
  late ConnectedAccountsRepository accounts;

  setUp(() async {
    await setUpTestDatabase();
    accounts = ConnectedAccountsRepository();
  });

  tearDown(tearDownTestDatabase);

  test('reads the short name, then the nickname after a rename', () async {
    final a = await accounts.create(
      kind: AccountKind.s3,
      label: 'sync @ 149b84f66d5479265f3e4d4ad4740926.r2.cloudflarestorage.com',
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final sub = container.listen(accountDisplayNameProvider(a.id), (_, _) {});
    addTearDown(sub.close);

    expect(
      await container.read(accountDisplayNameProvider(a.id).future),
      'sync @ Cloudflare R2',
    );

    await accounts.setNickname(a.id, 'Dive sync');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      await container.read(accountDisplayNameProvider(a.id).future),
      'Dive sync',
    );
  });

  test('is null for an id the roster does not hold', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      await container.read(accountDisplayNameProvider('missing').future),
      isNull,
    );
  });
}
