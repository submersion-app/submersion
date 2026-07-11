import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/repositories/connector_accounts_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ConnectorAccountsRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = ConnectorAccountsRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('create then getByType round-trips all fields', () async {
    final created = await repository.create(
      connectorType: 'lightroom',
      displayName: 'Eric G',
      credentialsRef: 'lightroom_auth',
      accountIdentifier: 'cat123',
    );
    expect(created.id, isNotEmpty);

    final loaded = await repository.getByType('lightroom');
    expect(loaded, isNotNull);
    expect(loaded!.id, created.id);
    expect(loaded.connectorType, 'lightroom');
    expect(loaded.displayName, 'Eric G');
    expect(loaded.credentialsRef, 'lightroom_auth');
    expect(loaded.accountIdentifier, 'cat123');
    expect(loaded.lastUsedAt, isNull);
  });

  test('getByType returns null when absent', () async {
    expect(await repository.getByType('lightroom'), isNull);
  });

  test('getByType picks the newest of two accounts of the same type', () async {
    await repository.create(
      connectorType: 'lightroom',
      displayName: 'Old',
      credentialsRef: 'ref',
      addedAt: DateTime.utc(2026, 1, 1),
    );
    await repository.create(
      connectorType: 'lightroom',
      displayName: 'New',
      credentialsRef: 'ref',
      addedAt: DateTime.utc(2026, 6, 1),
    );
    final loaded = await repository.getByType('lightroom');
    expect(loaded!.displayName, 'New');
  });

  test('touchLastUsed sets lastUsedAt', () async {
    final created = await repository.create(
      connectorType: 'lightroom',
      displayName: 'Eric',
      credentialsRef: 'ref',
    );
    await repository.touchLastUsed(created.id);
    final loaded = await repository.getByType('lightroom');
    expect(loaded!.lastUsedAt, isNotNull);
  });

  test('updateDisplay changes labels only', () async {
    final created = await repository.create(
      connectorType: 'lightroom',
      displayName: 'Before',
      credentialsRef: 'ref',
    );
    await repository.updateDisplay(
      created.id,
      displayName: 'After',
      accountIdentifier: 'cat9',
    );
    final loaded = await repository.getByType('lightroom');
    expect(loaded!.displayName, 'After');
    expect(loaded.accountIdentifier, 'cat9');
    expect(loaded.credentialsRef, 'ref');
  });

  test('delete removes the account', () async {
    final created = await repository.create(
      connectorType: 'lightroom',
      displayName: 'Eric',
      credentialsRef: 'ref',
    );
    await repository.delete(created.id);
    expect(await repository.getByType('lightroom'), isNull);
  });
}
