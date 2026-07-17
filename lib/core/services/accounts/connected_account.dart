import 'package:submersion/core/services/accounts/account_kind.dart';

/// A linked credentialed endpoint (secret-free). Accounts are instances,
/// not singletons: two S3 endpoints are two accounts. Secrets live in the
/// keychain under [credentialsKey], never in this object or the database.
class ConnectedAccount {
  final String id;
  final AccountKind kind;
  final String label;
  final String? accountIdentifier;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Diver this account is bound to (connector kinds with per-diver data,
  /// e.g. divelogs.de). Null for library-wide kinds. Fixed at creation.
  final String? diverId;

  const ConnectedAccount({
    required this.id,
    required this.kind,
    required this.label,
    this.accountIdentifier,
    required this.createdAt,
    required this.updatedAt,
    this.diverId,
  });

  /// Keychain key for this account's credentials blob.
  String get credentialsKey => 'account_${id}_credentials';

  ConnectedAccount copyWith({
    String? label,
    String? accountIdentifier,
    DateTime? updatedAt,
  }) {
    return ConnectedAccount(
      id: id,
      kind: kind,
      label: label ?? this.label,
      accountIdentifier: accountIdentifier ?? this.accountIdentifier,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      diverId: diverId,
    );
  }
}
