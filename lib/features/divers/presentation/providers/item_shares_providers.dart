import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/data/repositories/item_shares_repository.dart';

/// Who each trip and dive site is shared with (issue #2151).
final itemSharesRepositoryProvider = Provider<ItemSharesRepository>(
  (ref) => ItemSharesRepository(),
);

/// The trips or sites shared with at least one profile by name, for the
/// lists' shared badge. Refreshes when a share row changes.
final itemIdsWithSharesProvider =
    FutureProvider.family<Set<String>, SharedItemKind>((ref, kind) async {
      final repository = ref.watch(itemSharesRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.itemIdsWithShares(kind);
    });

/// Who one trip or site is shared with. Refreshes when a share row, a trip
/// or a site changes, including by sync.
final itemSharingProvider =
    FutureProvider.family<ItemSharing, ({SharedItemKind kind, String id})>((
      ref,
      item,
    ) async {
      final repository = ref.watch(itemSharesRepositoryProvider);
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.sharingOf(item.kind, item.id);
    });
