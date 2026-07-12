import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/connector_account.dart';

void main() {
  ConnectorAccount account({
    String id = 'a1',
    String displayName = 'Eric',
    String? accountIdentifier = 'cat1',
    DateTime? lastUsedAt,
  }) => ConnectorAccount(
    id: id,
    connectorType: 'lightroom',
    displayName: displayName,
    credentialsRef: 'lightroom_auth',
    accountIdentifier: accountIdentifier,
    baseUrl: null,
    addedAt: DateTime.utc(2026, 7, 1),
    lastUsedAt: lastUsedAt,
  );

  test('value equality covers every field', () {
    expect(account(), account());
    expect(account(), isNot(account(id: 'a2')));
    expect(account(), isNot(account(displayName: 'Other')));
    expect(account(), isNot(account(accountIdentifier: null)));
    expect(account(), isNot(account(lastUsedAt: DateTime.utc(2026, 7, 2))));
  });

  test('hashCode agrees with equality', () {
    expect(account().hashCode, account().hashCode);
  });
}
