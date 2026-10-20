import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/accounts/account_identity.dart';
import 'package:submersion/core/services/cloud_storage/cloud_provider_instances.dart';
import 'package:submersion/core/services/cloud_storage/git/git_config.dart';
import 'package:submersion/core/services/cloud_storage/git/git_reset_records.dart';
import 'package:submersion/core/services/cloud_storage/git_storage_provider.dart';

/// The Git provider singleton, for the settings page (load, save, test).
final gitStorageProviderInstanceProvider = Provider<GitStorageProvider>(
  (ref) => gitProviderInstance,
);

/// The stored Git sync configuration, or null when unset. Invalidate after
/// saving or removing it.
final gitConfigProvider = FutureProvider<GitConfig?>((ref) async {
  return ref.watch(gitStorageProviderInstanceProvider).loadConfig();
});

/// History reset outcomes for every repository and branch in this process.
final gitResetRecordsProvider = Provider<GitResetRecords>(
  (ref) => GitStorageProvider.resetRecords,
);

/// The history reset status of one repository and branch (its
/// [gitNaturalKey]), updated as resets happen or are refused, so the Cloud
/// sync page shows them without being reopened.
final gitResetStatusProvider = NotifierProvider.autoDispose
    .family<GitResetStatusNotifier, GitResetStatus, String>(
      GitResetStatusNotifier.new,
    );

class GitResetStatusNotifier extends Notifier<GitResetStatus> {
  GitResetStatusNotifier(this.endpoint);

  /// The repository and branch, as [gitNaturalKey] gives it.
  final String endpoint;

  @override
  GitResetStatus build() {
    final records = ref.watch(gitResetRecordsProvider);
    final changes = records.changes
        .where((key) => key == endpoint)
        .listen((_) => state = records.statusFor(endpoint));
    ref.onDispose(changes.cancel);
    return records.statusFor(endpoint);
  }
}
