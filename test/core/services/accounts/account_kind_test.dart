import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';

void main() {
  group('AccountKind.divelogs', () {
    test('has no cloud provider type (connector kind)', () {
      expect(AccountKind.divelogs.cloudProviderType, isNull);
    });

    test('round-trips through name for DB persistence', () {
      expect(
        AccountKind.values.byName(AccountKind.divelogs.name),
        AccountKind.divelogs,
      );
    });
  });
}
