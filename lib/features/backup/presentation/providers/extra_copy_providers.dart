import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/backup/data/services/extra_copy_destination.dart';
import 'package:submersion/features/backup/presentation/providers/backup_copy_providers.dart';
import 'package:submersion/features/backup/presentation/providers/backup_providers.dart';

/// The accounts each backup is also copied to (issue #3782), with the
/// provider each copy goes through. Built while the copy is off as well:
/// nothing is sent then, but old copies are still deleted with their
/// records, as the main copy's are. A row this device cannot reach (gone
/// from the roster, still being looked up, or of a kind with no adapter)
/// comes with no provider, so its copy is missed rather than sent anywhere
/// else.
final extraCopyDestinationsProvider = Provider<List<ExtraCopyDestination>>((
  ref,
) {
  // Watched as a key: the settings hand out a new list on every change,
  // and rebuilding the backup service for each would be wasted work.
  final key = ref.watch(
    backupSettingsProvider.select(
      (s) => [
        for (final a in s.extraCopyAccounts) '${a.kind.name}:${a.accountId}',
      ].join(','),
    ),
  );
  if (key.isEmpty) return const [];
  return [
    for (final account in ref.read(backupSettingsProvider).extraCopyAccounts)
      ExtraCopyDestination(
        account.accountId,
        watchAccountCopyProvider(ref, account.accountId, account.kind),
      ),
  ];
});
