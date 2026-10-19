import 'package:submersion/core/services/accounts/account_display_name.dart';
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

  /// The short name the diver gave the account (issue #3522), synced to
  /// every device; null until they choose one.
  final String? nickname;

  const ConnectedAccount({
    required this.id,
    required this.kind,
    required this.label,
    this.accountIdentifier,
    required this.createdAt,
    required this.updatedAt,
    this.nickname,
  });

  /// Keychain key for this account's credentials blob.
  String get credentialsKey => 'account_${id}_credentials';

  /// The name the account is shown under: the [nickname], else [label]
  /// with a well-known service's host replaced by its name.
  String get displayName =>
      accountDisplayName(label: label, nickname: nickname);

  ConnectedAccount copyWith({
    String? label,
    String? accountIdentifier,
    DateTime? updatedAt,
    String? nickname,
    bool clearNickname = false,
  }) {
    return ConnectedAccount(
      id: id,
      kind: kind,
      label: label ?? this.label,
      accountIdentifier: accountIdentifier ?? this.accountIdentifier,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nickname: clearNickname ? null : (nickname ?? this.nickname),
    );
  }
}
