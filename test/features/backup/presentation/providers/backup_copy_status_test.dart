import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/accounts/account_group.dart';
import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';

void main() {
  final at = DateTime.utc(2026);
  ConnectedAccount row(String id) => ConnectedAccount(
    id: id,
    kind: AccountKind.s3,
    label: id,
    createdAt: at,
    updatedAt: at,
  );

  // The group reads as its worst row: a folder only a library uses is signed
  // out here, while the copy's own row is fine.
  final copyRow = row('copy');
  final group = AccountGroup(
    key: 's3',
    kind: AccountKind.s3,
    label: 'S3',
    address: '',
    rows: [copyRow, row('library')],
    status: AccountStatus.needsSignIn,
    usages: const [],
    usagesKnown: true,
    locations: const {},
    roles: const {},
    usageRoles: const {'copy': AccountRole.sync},
    rowStatuses: const {
      'copy': AccountStatus.signedIn,
      'library': AccountStatus.needsSignIn,
    },
  );

  test('a pinned copy reads its own row, not the group', () {
    expect(
      backupCopyStatusOf(CopyToAccount(group, copyRow)),
      AccountStatus.signedIn,
    );
  });

  test('a copy that follows sync reads the sync row, not the group', () {
    expect(backupCopyStatusOf(CopyFollowsSync(group)), AccountStatus.signedIn);
  });

  test('no copy has no status', () {
    expect(backupCopyStatusOf(const NoCopy()), isNull);
    expect(backupCopyStatusOf(const CopyFollowsSync(null)), isNull);
  });
}
