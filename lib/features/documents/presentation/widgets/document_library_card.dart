import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/providers/document_library_providers.dart';
import 'package:submersion/features/shared_library/presentation/providers/shared_library_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// On a document filed on a shared site library's site (issue #4713): the
/// switch that shares it with the library, for editors and owners, or the
/// line saying it is shared, for readers; and who last edited a shared one.
/// Nothing for a document elsewhere, or for a reader's own document.
class DocumentLibraryCard extends ConsumerWidget {
  const DocumentLibraryCard({
    super.key,
    required this.document,
    required this.onUnshared,
    this.enabled = true,
  });

  final Document document;

  /// Called with the private copy's id once the document stopped being
  /// shared: the page shows that copy instead.
  final void Function(String copyId) onUnshared;

  /// False while the page's sitting is open: sharing waits for it.
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final siteId = document.owner.id;
    if (document.owner.kind != DocumentOwnerKind.site || siteId == null) {
      return const SizedBox.shrink();
    }
    final view = ref.watch(siteLibraryViewProvider(siteId)).value;
    if (view == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final attribution = document.isShared
        ? _attribution(context, ref, view.libraryId)
        : null;
    if (!view.canEdit) {
      if (!document.isShared) return const SizedBox.shrink();
      return Card(
        child: ListTile(
          leading: const Icon(Icons.groups_outlined),
          title: Text(l10n.documents_libraryShare_sharedWith(view.libraryName)),
          subtitle: attribution == null ? null : Text(attribution),
        ),
      );
    }
    return Card(
      child: SwitchListTile(
        key: const ValueKey('document-library-share-switch'),
        secondary: const Icon(Icons.groups_outlined),
        title: Text(l10n.documents_libraryShare_switch(view.libraryName)),
        subtitle: Text(attribution ?? l10n.documents_libraryShare_hint),
        value: document.isShared,
        onChanged: enabled
            ? (on) => on ? _share(ref, view) : _unshare(context, ref, view)
            : null,
      ),
    );
  }

  /// "Last edited by NAME, DATE" from the newest clock, or null.
  String? _attribution(BuildContext context, WidgetRef ref, String libraryId) {
    final state = ref.watch(documentLibraryStateProvider(document.id)).value;
    final memberId = state?.lastEditorMemberId;
    final at = state?.lastEditedAtMs;
    if (memberId == null || at == null) return null;
    final names =
        ref.watch(libraryMemberNamesProvider(libraryId)).value ??
        const <String, String>{};
    final name =
        names[memberId] ??
        (memberId.length > 8 ? memberId.substring(0, 8) : memberId);
    // In the diver's own date format (issue #1512).
    final date = ref
        .watch(unitFormatterProvider)
        .formatDate(DateTime.fromMillisecondsSinceEpoch(at));
    return context.l10n.documents_libraryShare_lastEdited(name, date);
  }

  Future<void> _share(WidgetRef ref, DocumentLibraryView view) async {
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    await ref
        .read(libraryDocumentStamperProvider)
        .share(document.id, libraryId: view.libraryId, actingDiverId: diverId);
  }

  Future<void> _unshare(
    BuildContext context,
    WidgetRef ref,
    DocumentLibraryView view,
  ) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.documents_libraryShare_unshareTitle(view.libraryName)),
        content: Text(l10n.documents_libraryShare_unshareBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.documents_libraryShare_unshareConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;
    final copyId = await ref
        .read(libraryDocumentStamperProvider)
        .unshare(document.id, actingDiverId: diverId);
    onUnshared(copyId);
  }
}
