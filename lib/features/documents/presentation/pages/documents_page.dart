import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_page.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_expiring_strip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Every document of the active diver (issue #2613): what needs attention
/// first, then grouped by what each is filed under.
class DocumentsPage extends ConsumerWidget {
  final DocumentType? initialType;
  final bool initialExpiringOnly;
  final bool initialPersonalOnly;

  const DocumentsPage({
    super.key,
    this.initialType,
    this.initialExpiringOnly = false,
    this.initialPersonalOnly = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final fab = FloatingActionButton.extended(
      onPressed: () {
        // Adding from a filtered list (the insurance chip's) starts the
        // new document as that type.
        final type = initialType;
        if (ResponsiveBreakpoints.isMasterDetail(context)) {
          final uri = GoRouterState.of(context).uri;
          context.go(
            uri
                .replace(
                  queryParameters: {...uri.queryParameters, 'mode': 'new'},
                )
                .toString(),
          );
        } else {
          context.push(
            type == null
                ? '/documents/new'
                : '/documents/new?type=${type.storage}',
          );
        }
      },
      tooltip: l10n.documents_add,
      icon: const Icon(Icons.note_add_outlined),
      label: Text(l10n.documents_add),
    );
    Widget list({
      required bool showAppBar,
      void Function(String?)? onSelected,
      String? selectedId,
    }) => DocumentsListContent(
      showAppBar: showAppBar,
      initialType: initialType,
      initialExpiringOnly: initialExpiringOnly,
      initialPersonalOnly: initialPersonalOnly,
      selectedId: selectedId,
      onOpen: (id) =>
          onSelected != null ? onSelected(id) : context.push('/documents/$id'),
      floatingActionButton: showAppBar ? fab : null,
    );
    if (!ResponsiveBreakpoints.isMasterDetail(context)) {
      return list(showAppBar: true);
    }
    return MasterDetailScaffold(
      sectionId: 'documents',
      masterBuilder: (context, onItemSelected, selectedId) => list(
        showAppBar: false,
        onSelected: onItemSelected,
        selectedId: selectedId,
      ),
      detailBuilder: (context, id) => DocumentDetailPage(
        documentId: id,
        embedded: true,
        onDeleted: () => context.go(GoRouterState.of(context).uri.path),
      ),
      summaryBuilder: (context) => Center(
        child: Icon(
          Icons.folder_copy_outlined,
          size: 96,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      editBuilder: (context, id, onSaved, onCancel) => DocumentEditPage(
        documentId: id,
        embedded: true,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
      createBuilder: (context, onSaved, onCancel) => DocumentEditPage(
        embedded: true,
        initialType: initialType,
        onSaved: onSaved,
        onCancel: onCancel,
      ),
      floatingActionButton: fab,
    );
  }
}

/// The list itself: search, type filter, the Needs attention strip, and the
/// documents grouped by owner kind.
class DocumentsListContent extends ConsumerStatefulWidget {
  final bool showAppBar;
  final DocumentType? initialType;
  final bool initialExpiringOnly;
  final bool initialPersonalOnly;
  final String? selectedId;
  final ValueChanged<String> onOpen;
  final Widget? floatingActionButton;

  const DocumentsListContent({
    super.key,
    required this.showAppBar,
    required this.onOpen,
    this.initialType,
    this.initialExpiringOnly = false,
    this.initialPersonalOnly = false,
    this.selectedId,
    this.floatingActionButton,
  });

  @override
  ConsumerState<DocumentsListContent> createState() =>
      _DocumentsListContentState();
}

class _DocumentsListContentState extends ConsumerState<DocumentsListContent> {
  late DocumentType? _type = widget.initialType;
  late bool _personalOnly = widget.initialPersonalOnly;
  late bool _expiringOnly = widget.initialExpiringOnly;

  @override
  void didUpdateWidget(DocumentsListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The master pane stays mounted across route changes on wide screens,
    // so a new filter from the route (the insurance chip) must land here.
    if (oldWidget.initialType != widget.initialType) {
      _type = widget.initialType;
    }
    if (oldWidget.initialPersonalOnly != widget.initialPersonalOnly) {
      _personalOnly = widget.initialPersonalOnly;
    }
    if (oldWidget.initialExpiringOnly != widget.initialExpiringOnly) {
      _expiringOnly = widget.initialExpiringOnly;
    }
  }

  String _query = '';

  bool _matches(DocumentListEntry e) {
    final d = e.document;
    if (_type != null && d.type != _type) return false;
    if (_personalOnly && !d.owner.isPersonal) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      d.title,
      d.issuer,
      d.referenceNumber,
      e.ownerLabel,
    ].any((v) => v != null && v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = ref.watch(allDocumentsProvider);
    final body = all.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l10n.documents_error_load('$e'))),
      data: (raw) {
        final catalog = ref.watch(certificationCatalogSyncProvider);
        final entries = [
          for (final e in raw)
            withCertificationOwnerTitle(e, l10n, catalog: catalog),
        ];
        final presentTypes = {for (final e in entries) e.document.type};
        final shown = entries.where(_matches).toList();
        final listed = _expiringOnly
            ? [
                for (final (e, _) in DocumentsExpiringStrip.due(
                  shown,
                  DateTime.now(),
                ))
                  e,
              ]
            : shown;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.documents_search_hint,
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
            // Shown whenever a filter is set, so a filter from the route can
            // always be cleared, even when only one type exists.
            if (presentTypes.length > 1 || _type != null)
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(l10n.documents_filter_all),
                        selected: _type == null,
                        onSelected: (_) => setState(() => _type = null),
                      ),
                      for (final t in DocumentType.values)
                        if (presentTypes.contains(t))
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text(documentTypeLabel(l10n, t)),
                              selected: _type == t,
                              onSelected: (_) => setState(() => _type = t),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            // Filters that came from the route (the profile hub, the home
            // chip) are shown, so the diver sees why the list is short and
            // can clear them.
            if (_personalOnly || _expiringOnly)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (_personalOnly)
                        InputChip(
                          key: const ValueKey('documents-filter-personal'),
                          label: Text(l10n.documents_owner_personal),
                          onDeleted: () =>
                              setState(() => _personalOnly = false),
                        ),
                      if (_expiringOnly)
                        InputChip(
                          key: const ValueKey('documents-filter-expiring'),
                          label: Text(l10n.documents_expiring_title),
                          onDeleted: () =>
                              setState(() => _expiringOnly = false),
                        ),
                    ],
                  ),
                ),
              ),
            if (!_expiringOnly)
              SliverToBoxAdapter(
                child: DocumentsExpiringStrip(
                  entries: shown,
                  onOpen: widget.onOpen,
                ),
              ),
            if (listed.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(l10n.documents_empty)),
              )
            else
              for (final kind in DocumentOwnerKind.values)
                ..._group(context, kind, [
                  for (final e in listed)
                    if (e.document.owner.kind == kind) e,
                ]),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        );
      },
    );
    if (!widget.showAppBar) return body;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documents_title)),
      floatingActionButton: widget.floatingActionButton,
      body: body,
    );
  }

  List<Widget> _group(
    BuildContext context,
    DocumentOwnerKind kind,
    List<DocumentListEntry> entries,
  ) {
    if (entries.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            documentOwnerKindLabel(context.l10n, kind),
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
      ),
      SliverList.builder(
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          return DocumentTile(
            document: e.document,
            ownerLabel: e.ownerLabel,
            selected: e.document.id == widget.selectedId,
            onTap: () => widget.onOpen(e.document.id),
          );
        },
      ),
    ];
  }
}
