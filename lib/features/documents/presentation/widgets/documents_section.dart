import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The Documents card on an owner's detail page (dive, site, trip, gear,
/// course, certification, buddy, dive center): its documents and an "Add
/// document" that files the new one under this owner (issue #2613).
class DocumentsSection extends ConsumerWidget {
  final DocumentOwner owner;

  /// The certification page shows its card images itself.
  final bool excludeCards;

  const DocumentsSection({
    super.key,
    required this.owner,
    this.excludeCards = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final docs = ref.watch(documentsForOwnerProvider(owner));
    final tagsByDocument =
        ref.watch(tagsByItemProvider(TagScope.documents)).value ??
        const <String, List<Tag>>{};
    return Card(
      key: ValueKey('documents-section-${owner.kind.name}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.folder_copy_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.documents_section_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('documents-section-add'),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.documents_add),
                  onPressed: () => context.push(
                    Uri(
                      path: '/documents/new',
                      queryParameters: {
                        'ownerKind': owner.kind.storage,
                        'ownerId': ?owner.id,
                      },
                    ).toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            docs.when(
              data: (list) {
                final shown = [
                  for (final d in list)
                    if (!excludeCards ||
                        d.type != DocumentType.certificationCard)
                      d,
                ];
                if (shown.isEmpty) {
                  return Text(
                    l10n.documents_section_empty,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final d in shown)
                      DocumentTile(
                        key: ValueKey('document-${d.id}'),
                        document: d,
                        tags: tagsByDocument[d.id] ?? const [],
                        onTap: () => context.push('/documents/${d.id}'),
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                l10n.documents_error_load('$e'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
