import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_page.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

/// The Documents card on an owner's detail page (dive, site, trip, gear,
/// course, certification, buddy, dive center): its documents and an "Add
/// document" that files the new one under this owner (issue #2613).
/// [T] is the record type of a page that edits in place (a dive, a site):
/// its sitting holds attach and remove, and its scope makes the card read
/// only. Other owners leave it unset.
class DocumentsSection<T> extends ConsumerWidget {
  final DocumentOwner owner;

  /// The certification page shows its card images itself.
  final bool excludeCards;

  /// The open Documents card's sitting on the record (issue #4527): Add
  /// creates a Personal document at once and holds joining it to the record;
  /// Remove holds detaching. On a page that offers editing and with no
  /// sitting given, the card reads only.
  final EditSession<T>? editing;

  const DocumentsSection({
    super.key,
    required this.owner,
    this.excludeCards = false,
    this.editing,
  });

  /// A new document, filed as Personal until the sitting is saved.
  Future<void> _addInSitting(
    BuildContext context,
    EditSession<T> session,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (pageContext) => Consumer(
          builder: (pageContext, ref, _) => DocumentEditPage(
            ownerFixed: true,
            onSaved: (id) async {
              final navigator = Navigator.of(pageContext);
              final saved = await ref
                  .read(documentRepositoryProvider)
                  .getById(id);
              if (saved != null) attachDocument(session, saved);
              navigator.pop();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final stored = ref.watch(documentsForOwnerProvider(owner));
    final scope = RecordEditScope.maybeOf<T>(context);
    final editing = this.editing;
    final session = editing ?? scope?.session;
    // Read only on the dive page outside the open card. Every other owner's
    // page (a site, trip, buddy, course, certification, dive centre or gear
    // item) has no dive lock, and Add there files a document at once, so
    // that path stays (issue #4673).
    final readOnly = scope != null && editing == null;
    final docs = session == null
        ? stored
        : stored.whenData((list) => documentsInSitting(session, list));
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
            // The title at the start and Add at the far edge while both fit
            // on a line. When they do not (a narrow phone at a large text
            // size, a long translation), Add takes the next line: in a Row
            // it kept its width and squeezed the title to nothing.
            SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_copy_outlined,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.documents_section_title,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Read only, it keeps its room, so the card does not
                      // change size when the dive is unlocked. Flexible, so
                      // a long label on a narrow phone still fits.
                      Flexible(
                        child: Visibility(
                          visible: !readOnly,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: TextButton.icon(
                            key: const ValueKey('documents-section-add'),
                            icon: const Icon(Icons.add),
                            label: Text(l10n.documents_add),
                            onPressed: readOnly
                                ? null
                                : editing != null
                                ? () => _addInSitting(context, editing)
                                : () => context.push(
                                    Uri(
                                      path: '/documents/new',
                                      queryParameters: {
                                        'ownerKind': owner.kind.storage,
                                        'ownerId': ?owner.id,
                                      },
                                    ).toString(),
                                  ),
                          ),
                        ),
                      ),
                      // Its pencil, while the dive is unlocked.
                      RecordCardPencil(cardTitle: l10n.documents_section_title),
                    ],
                  ),
                ],
              ),
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
                      Row(
                        children: [
                          Expanded(
                            child: DocumentTile(
                              key: ValueKey('document-${d.id}'),
                              document: d,
                              tags: tagsByDocument[d.id] ?? const [],
                              onTap: () => context.push('/documents/${d.id}'),
                            ),
                          ),
                          if (editing != null)
                            IconButton(
                              key: ValueKey('document-remove-${d.id}'),
                              icon: const Icon(Icons.link_off),
                              tooltip: l10n.common_action_remove,
                              onPressed: () => detachDocument(editing, d.id),
                            ),
                        ],
                      ),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              // The open card offers to read again, as every card of a
              // sitting does (issue #4527).
              error: (e, _) => editing != null
                  ? SittingLoadFailed(
                      onRetry: () =>
                          ref.invalidate(documentsForOwnerProvider(owner)),
                    )
                  : Text(
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
