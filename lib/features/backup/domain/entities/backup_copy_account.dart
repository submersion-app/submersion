import 'package:equatable/equatable.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';

/// A roster row a backup is also copied to (issue #3782), beside the main
/// copy. The kind travels with the id so the scheduled backup, which has no
/// account registry, can still build the account's provider.
class BackupCopyAccount extends Equatable {
  const BackupCopyAccount({required this.accountId, required this.kind});

  final String accountId;
  final AccountKind kind;

  Map<String, dynamic> toJson() => {'id': accountId, 'kind': kind.name};

  /// Null for anything that is not a well-formed entry, including a kind
  /// this build does not know: such a row cannot be copied to here.
  static BackupCopyAccount? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final kind = AccountKind.values.asNameMap()[json['kind']];
    if (id is! String || id.isEmpty || kind == null) return null;
    return BackupCopyAccount(accountId: id, kind: kind);
  }

  @override
  List<Object?> get props => [accountId, kind];
}
