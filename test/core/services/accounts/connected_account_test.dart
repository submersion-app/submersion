import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';

void main() {
  group('AccountKind', () {
    test('maps 1:1 with CloudProviderType and back', () {
      for (final type in CloudProviderType.values) {
        final kind = AccountKind.fromCloudProviderType(type);
        expect(kind.cloudProviderType, type);
      }
    });

    test('adobeLightroom has no cloud provider type', () {
      expect(AccountKind.adobeLightroom.cloudProviderType, isNull);
    });
  });

  group('ConnectedAccount', () {
    final account = ConnectedAccount(
      id: 'abc-123',
      kind: AccountKind.s3,
      label: 'My MinIO',
      accountIdentifier: 'dive-media @ minio.local',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(2000, isUtc: true),
    );

    test('credentialsKey embeds the account id', () {
      expect(account.credentialsKey, 'account_abc-123_credentials');
    });

    test('copyWith replaces only the given fields', () {
      final renamed = account.copyWith(label: 'Renamed');
      expect(renamed.label, 'Renamed');
      expect(renamed.id, account.id);
      expect(renamed.kind, AccountKind.s3);
      expect(renamed.accountIdentifier, account.accountIdentifier);
    });
  });
}
