import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/change_log/presentation/widgets/change_log_history_menu_item.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_details_panel.dart';
import 'package:submersion/features/documents/presentation/widgets/document_page_viewer.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/data/services/document_edit_save_service.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/features/documents/presentation/editing/document_card_ids.dart';
import 'package:submersion/features/documents/presentation/editing/document_details_card_editor.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_cards.dart';
import 'package:submersion/features/documents/presentation/editing/document_new_sitting.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/documents/presentation/providers/document_record_provider.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_routes.dart';
import 'package:submersion/shared/widgets/record_editing/add_strip.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_pencil.dart';
import 'package:submersion/shared/widgets/record_editing/record_creating.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_open_unlocked.dart';
import 'package:submersion/shared/widgets/record_editing/record_operation_gate.dart';

part 'document_detail_page_creating.dart';
part 'document_detail_page_editing.dart';

/// One document: its pages, its details and what it is filed under. It
/// opens locked and edits in place (issue #4527): its details and pages are
/// held in one sitting and written by one Save.
class DocumentDetailPage extends ConsumerStatefulWidget {
  final String documentId;

  /// True inside the master-detail pane on wide screens.
  final bool embedded;
  final VoidCallback? onDeleted;

  /// Opens unlocked, as the old edit addresses ask (`?mode=edit`).
  final bool openUnlocked;

  /// Told once when the sitting it opened unlocked ends, so a pane opened
  /// for editing returns to view mode.
  final VoidCallback? onSittingEnded;

  /// A new document (issue #4527, phase 3, plan 11): the page opened
  /// unlocked on a document not yet created, with what [request] brings.
  final NewDocumentRequest? newDocument;

  /// The pane's own: given the new document's id once created.
  final void Function(String documentId)? onCreated;

  /// The pane's own: told when a new document's page leaves uncreated.
  final VoidCallback? onCreateCancelled;

  const DocumentDetailPage({
    super.key,
    required this.documentId,
    this.embedded = false,
    this.onDeleted,
    this.openUnlocked = false,
    this.onSittingEnded,
  }) : newDocument = null,
       onCreated = null,
       onCreateCancelled = null;

  /// A new document's page.
  const DocumentDetailPage.newDocument({
    super.key,
    NewDocumentRequest request = const NewDocumentRequest(),
    this.embedded = false,
    this.onCreated,
    this.onCreateCancelled,
  }) : newDocument = request,
       documentId = '',
       onDeleted = null,
       openUnlocked = false,
       onSittingEnded = null;

  @override
  ConsumerState<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends ConsumerState<DocumentDetailPage>
    with
        RecordEditHost<DocumentDetailPage, DocumentRecord>,
        RecordOpenUnlocked<DocumentDetailPage, DocumentRecord>,
        _DocumentDetailPageEditing,
        RecordCreating<DocumentDetailPage, DocumentRecord>,
        _DocumentDetailPageCreating {
  @override
  void dispose() {
    disposeEditing();
    super.dispose();
  }

  /// Wide enough for a readable page beside the details column.
  static const double _sideBySideWidth = 840;
  static const double _sideColumnWidth = 360;

  bool _redirected = false;

  /// A full page moving into the list's pane leaves the unlock to the pane.
  @override
  bool get handsUnlockElsewhere => _redirected;

  @override
  Widget build(BuildContext context) {
    if (isCreating) return newRecordWaiting(context) ?? _buildNewDocument();
    final l10n = context.l10n;
    // A full page reached directly (a deep link, the home chip) belongs in
    // the list's detail pane on a wide screen. One pushed from an owner
    // page's Documents section stays a page, so Back returns to the owner.
    if (!widget.embedded &&
        !_redirected &&
        ResponsiveBreakpoints.isMasterDetail(context) &&
        !context.canPop()) {
      _redirected = true;
      // Asked to open unlocked and not yet: the pane opens it unlocked.
      final unlock = widget.openUnlocked && !hasOpenedUnlocked;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go(
            documentPaneLocation(widget.documentId, openUnlocked: unlock),
          );
        }
      });
    }
    final entry = ref.watch(documentEntryProvider(widget.documentId));
    final units = ref.watch(unitFormatterProvider);
    followStored(documentRecordProvider(widget.documentId));
    final recordAsync = ref.watch(documentRecordProvider(widget.documentId));
    final record = recordAsync.value;
    return entry.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      // Embedded, these placeholder bars belong to a detail pane, not a page:
      // a pushed list underneath must not give them a back arrow (#3292).
      error: (e, _) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: !widget.embedded),
        body: Center(child: Text(l10n.documents_error_load('$e'))),
      ),
      data: (stored) {
        if (stored == null) {
          return Scaffold(
            appBar: AppBar(automaticallyImplyLeading: !widget.embedded),
            body: Center(child: Text(l10n.documents_empty)),
          );
        }
        final named = withCertificationOwnerTitle(
          stored,
          l10n,
          catalog: ref.watch(certificationCatalogSyncProvider),
        );
        if (record == null) {
          // The page edits the record: until it is read there is nothing to
          // show, and a read that failed or found nothing says so.
          final error = recordAsync.error;
          return Scaffold(
            appBar: AppBar(automaticallyImplyLeading: !widget.embedded),
            body: Center(
              child: error != null
                  ? Text(l10n.documents_error_load('$error'))
                  : recordAsync.hasValue
                  ? Text(l10n.documents_empty)
                  : const CircularProgressIndicator(),
            ),
          );
        }
        openUnlockedOnce(record);
        final shown = shownRecord(record);
        final doc = shown.document;
        // The entry with the sitting's document, so the details and the
        // panel show what the diver is editing.
        // The stored owner's name, while the sitting keeps that owner: a new
        // owner reads as its kind until saved and read back.
        final sameOwner = doc.owner == named.document.owner;
        final entry = DocumentListEntry(
          doc,
          sameOwner ? named.ownerLabel : null,
          named.pageCount,
          ownerDate: sameOwner ? named.ownerDate : null,
          certification: sameOwner ? named.certification : null,
        );
        return editScaffold(
          record: record,
          shown: shown,
          lockedBar: _bar(entry, doc, shown),
          unlockedActions: [_menu(doc)],
          // The sitting's pages, which may hold pages not yet saved.
          content: _body(
            entry,
            doc,
            entry.ownerText(units),
            AsyncData(shown.pages),
          ),
        );
      },
    );
  }

  /// A new document's page on its seed: the sitting's document, its
  /// details and pages, with no menu, as nothing acts on a document not
  /// yet created.
  Widget _buildNewDocument() {
    final seed = newRecordSeed!;
    final shown = shownRecord(seed);
    final doc = shown.document;
    final entry = DocumentListEntry(doc, null, shown.pages.length);
    return editScaffold(
      record: seed,
      shown: shown,
      // Never shown: a new document's page leaves once its sitting ends.
      lockedBar: AppBar(title: Text(newRecordTitle(context))),
      content: _body(
        entry,
        doc,
        entry.ownerText(ref.watch(unitFormatterProvider)),
        AsyncData(shown.pages),
      ),
    );
  }

  /// The page's top bar while locked: its title, the lock and the menu.
  PreferredSizeWidget _bar(
    DocumentListEntry entry,
    Document doc,
    DocumentRecord shown,
  ) {
    final l10n = context.l10n;
    return AppBar(
      automaticallyImplyLeading: !widget.embedded,
      title: Text(
        documentDisplayTitle(l10n, doc, ownerLabel: entry.ownerLabel),
      ),
      actions: [lockButton(shown), _menu(doc)],
    );
  }

  /// The menu: History, and Delete behind the overflow, as on the other
  /// detail pages, not one tap away beside Edit (#3384).
  Widget _menu(Document doc) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'delete') _requestDelete(doc);
      },
      itemBuilder: (context) {
        final error = Theme.of(context).colorScheme.error;
        return [
          changeLogHistoryMenuItem(
            context,
            rootTable: 'documents',
            rootId: doc.id,
          ),
          ..._documentRecordCaption(),
          PopupMenuItem(
            value: 'delete',
            enabled: _documentOperationsAvailable,
            child: Row(
              children: [
                Icon(Icons.delete, color: error),
                const SizedBox(width: 8),
                Text(l10n.common_action_delete, style: TextStyle(color: error)),
              ],
            ),
          ),
        ];
      },
    );
  }

  /// The page's pages and details, laid out for the window's width.
  Widget _body(
    DocumentListEntry entry,
    Document doc,
    String? owner,
    AsyncValue<List<DocumentPage>> pages,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Nothing to show but the details (an insurance kept as its
        // numbers alone): show them, not an empty viewer over a folded
        // panel.
        if (pages.value?.isEmpty ?? false) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Brought in from the strip: its editor, above the details.
              if (_pagesShownWhileEmpty)
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: _framedPages(),
                  ),
                ),
              // A readable line length on a wide window.
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: _detailsCard(doc, owner),
                ),
              ),
            ],
          );
        }
        final pageViewer = pages.when(
          data: (list) => DocumentPageViewer(pages: list),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
        );
        // While unlocked the Pages card's header sits above the pages, its
        // editor in its place once open; locked, the pages are as ever.
        final viewer = isSittingOpen
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _framedPages(),
                  Expanded(child: pageViewer),
                ],
              )
            : pageViewer;
        if (constraints.maxWidth >= _sideBySideWidth) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: viewer),
              SizedBox(
                width: _sideColumnWidth,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _detailsCard(doc, owner),
                ),
              ),
            ],
          );
        }
        // The pages own every vertical drag here: inside a scrolling list
        // a PDF could neither fill the screen nor scroll.
        return Column(
          children: [
            Expanded(child: viewer),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: constraints.maxHeight / 2),
              child: DocumentDetailsPanel(
                entry: entry,
                forceOpen: isSittingOpen,
                frame: _framedDetails,
                pencil: _detailsPencil(),
                tags: _heldTags(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The details as a card, framed as the Details card where the page
  /// edits in place.
  Widget _detailsCard(Document doc, String? owner) {
    final card = DocumentDetailsCard(
      document: doc,
      ownerLabel: owner,
      pencil: _detailsPencil(),
      tags: _heldTags(),
    );
    return _framedDetails(card);
  }

  /// Deletes [doc] after asking, and leaves the page. Answers whether it
  /// deleted.
  @override
  Future<bool> _delete(Document doc) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.documents_delete_title),
        content: Text(l10n.documents_delete_content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    await ref.read(documentMutationsProvider).delete(doc.id);
    messenger.showSnackBar(SnackBar(content: Text(l10n.documents_deleted)));
    if (!mounted) return true;
    if (widget.onDeleted != null) {
      widget.onDeleted!();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/documents');
    }
    return true;
  }
}
