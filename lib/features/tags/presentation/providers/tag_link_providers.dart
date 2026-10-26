import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// The tag links of one scope (issue #1970): media and documents.
final tagLinkRepositoryProvider = Provider.family<TagLinkRepository, TagScope>(
  (ref, scope) => TagLinkRepository(scope),
);

/// One item's tags in [scope], by name. Refreshes on any link or tag change,
/// including one a sync or an import applies without a notifier.
final tagsForItemProvider =
    FutureProvider.family<List<Tag>, ({TagScope scope, String itemId})>((
      ref,
      key,
    ) async {
      final repository = ref.watch(tagLinkRepositoryProvider(key.scope));
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getTagsFor(key.itemId);
    });

/// Every tagged item's tags in [scope], in one query, for list tiles and
/// tag filters. An item with no tags has no entry.
final tagsByItemProvider =
    FutureProvider.family<Map<String, List<Tag>>, TagScope>((ref, scope) async {
      final repository = ref.watch(tagLinkRepositoryProvider(scope));
      ref.invalidateSelfWhen(repository.watchChanges());
      return repository.getTagsByItem();
    });
