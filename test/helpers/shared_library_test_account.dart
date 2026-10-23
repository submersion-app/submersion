import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';

/// An S3 account for any id, for a membership service whose transports
/// ignore the account (the fake cloud is reached through the folder alone).
/// A library's missing account is an error since issue #3563, so these tests
/// name the stand-in the service used to make up itself.
Future<ConnectedAccount?> anyTestAccount(String id) async => ConnectedAccount(
  id: id,
  kind: AccountKind.s3,
  label: '',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
