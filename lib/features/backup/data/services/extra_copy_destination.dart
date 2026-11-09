import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';

/// An account each backup is also copied to (issue #3782), as the backup
/// service is handed it: fixed when the service is built, so a change in
/// Settings during a backup cannot send part of it elsewhere.
class ExtraCopyDestination {
  const ExtraCopyDestination(this.accountId, this.provider);

  /// The roster row the copy goes to.
  final String accountId;

  /// Null when this device cannot reach the account (a row the roster no
  /// longer has, or no adapter for its kind): its copy is then missed.
  final CloudStorageProvider? provider;
}
