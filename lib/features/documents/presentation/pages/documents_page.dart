import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/documents/presentation/helpers/document_export_flow.dart';
import 'package:submersion/features/documents/presentation/pages/document_detail_page.dart';
import 'package:submersion/features/documents/presentation/pages/document_edit_page.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tag_filter_row.dart';
import 'package:submersion/features/documents/presentation/widgets/document_tile.dart';
import 'package:submersion/features/documents/presentation/widgets/documents_expiring_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/pane_header_bar.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';
import 'package:submersion/shared/widgets/section_title_toggle.dart';

/// Every document of the active diver (issue #2613): what needs attention
/// first, then grouped by what each is filed under.
class DocumentsPage extends ConsumerWidget {
  final DocumentType? initialType;
  final bool initialExpiringOnly;
  final bool initialPersonalOnly;

  /// Shows only the documents carrying this tag (a detail page's tag chip).
  final String? initialTagId;

  /// The header's title in every layout: the Media screen's Photos/Videos
  /// and Documents switch (#3631).
  final SectionHeaderTitle headerTitle;

  const DocumentsPage({
    super.key,
    this.initialType,
    this.initialExpiringOnly = false,
    this.initialPersonalOnly = false,
    this.initialTagId,
    required this.headerTitle,
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
      initialTagId: initialTagId,
      selectedId: selectedId,
      onOpen: (id) =>
          onSelected != null ? onSelected(id) : context.push('/documents/$id'),
      floatingActionButton: showAppBar ? fab : null,
      headerTitle: headerTitle,
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
  final String? initialTagId;
  final String? selectedId;
  final ValueChanged<String> onOpen;
  final Widget? floatingActionButton;
  final SectionHeaderTitle headerTitle;

  const DocumentsListContent({
    super.key,
    required this.showAppBar,
    required this.onOpen,
    this.initialType,
    this.initialExpiringOnly = false,
    this.initialPersonalOnly = false,
    this.initialTagId,
    this.selectedId,
    this.floatingActionButton,
    required this.headerTitle,
  });

  @override
  ConsumerState<DocumentsListContent> createState() =>
      _DocumentsListContentState();
}

class _DocumentsListContentState extends ConsumerState<DocumentsListContent> {
  late DocumentType? _type = widget.initialType;
  late bool _personalOnly = widget.initialPersonalOnly;
  late bool _expiringOnly = widget.initialExpiringOnly;

  /// Tags the list is filtered to, any of them matching (issue #1970).
  late Set<String> _tagIds = {?widget.initialTagId};

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
    if (oldWidget.initialTagId != widget.initialTagId) {
      _tagIds = {?widget.initialTagId};
    }
  }

  String _query = '';

  bool _matches(
    DocumentListEntry e,
    UnitFormatter units,
    Map<String, List<Tag>> tagsByDocument,
    Set<String> tagIds,
  ) {
    final d = e.document;
    if (_type != null && d.type != _type) return false;
    if (_personalOnly && !d.owner.isPersonal) return false;
    final tags = tagsByDocument[d.id] ?? const <Tag>[];
    if (tagIds.isNotEmpty && !tags.any((t) => tagIds.contains(t.id))) {
      return false;
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      d.title,
      d.issuer,
      d.referenceNumber,
      e.ownerText(units),
      for (final t in tags) t.name,
    ].any((v) => v != null && v.toLowerCase().contains(q));
  }

  /// Every tag one of [entries] carries, by name, plus any still selected,
  /// so a filter on a tag that has since gone stays clearable. Read from the
  /// listed documents, not every link: those include other divers'.
  List<Tag> _filterTags(
    List<DocumentListEntry> entries,
    Map<String, List<Tag>> tagsByDocument,
    List<Tag> allTags,
  ) {
    final byId = <String, Tag>{
      for (final e in entries)
        for (final t in tagsByDocument[e.document.id] ?? const <Tag>[]) t.id: t,
      for (final t in allTags)
        if (_tagIds.contains(t.id)) t.id: t,
    };
    return sortedByText(byId.values, (t) => t.name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final all = ref.watch(allDocumentsProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final tagsByDocument =
        ref.watch(tagsByItemProvider(TagScope.documents)).value ??
        const <String, List<Tag>>{};
    final allTagsValue = ref.watch(tagsProvider).value;
    final allTags = allTagsValue ?? const <Tag>[];
    // A selected tag that no longer exists (deleted, merged, or a stale
    // link) could not be shown as a chip to clear, so it stops filtering.
    final activeTagIds = allTagsValue == null
        ? _tagIds
        : {
            for (final t in allTags)
              if (_tagIds.contains(t.id)) t.id,
          };
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
        final shown = entries
            .where((e) => _matches(e, units, tagsByDocument, activeTagIds))
            .toList();
        final filterTags = _filterTags(entries, tagsByDocument, allTags);
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
            if (filterTags.isNotEmpty)
              SliverToBoxAdapter(
                child: DocumentTagFilterRow(
                  tags: filterTags,
                  selectedIds: _tagIds,
                  onChanged: (ids) => setState(() => _tagIds = ids),
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
                ..._group(context, kind, units, tagsByDocument, [
                  for (final e in listed)
                    if (e.document.owner.kind == kind) e,
                ]),
            const SliverToBoxAdapter(child: SizedBox(height: 88)),
          ],
        );
      },
    );
    if (!widget.showAppBar) {
      return Column(
        children: [
          _compactHeader(context),
          Expanded(child: body),
        ],
      );
    }
    final headerTitle = widget.headerTitle;
    return Scaffold(
      appBar: headerTitle.pinAppBar(
        AppBar(
          titleSpacing: SectionTitleToggle.appBarTitleSpacing,
          title: headerTitle.build(context, SectionHeaderSlot.appBar, null),
          toolbarHeight: headerTitle.appBarHeight(context, null),
          // The switch takes the whole title row, so the menu sits on a row
          // under it, as Training's lists' icons do.
          bottom: sectionHeaderActionsRow([_menu(context)]),
        ),
      ),
      floatingActionButton: widget.floatingActionButton,
      body: body,
    );
  }

  Widget _menu(BuildContext context, {double? iconSize}) =>
      PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: iconSize),
        onSelected: (_) => exportAllDocuments(context, ref),
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'export',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.archive_outlined),
              title: Text(context.l10n.documents_export_action),
            ),
          ),
        ],
      );

  /// The master pane's title row on wide screens, where the list has no app
  /// bar of its own.
  Widget _compactHeader(BuildContext context) => PaneHeaderBar(
    title: widget.headerTitle.build(context, SectionHeaderSlot.pane, null),
    titleWidth: widget.headerTitle.paneTitleWidth?.call(context),
    actions: [_menu(context, iconSize: 20)],
  );

  List<Widget> _group(
    BuildContext context,
    DocumentOwnerKind kind,
    UnitFormatter units,
    Map<String, List<Tag>> tagsByDocument,
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
            ownerLabel: e.ownerText(units),
            selected: e.document.id == widget.selectedId,
            tags: tagsByDocument[e.document.id] ?? const [],
            onTap: () => widget.onOpen(e.document.id),
          );
        },
      ),
    ];
  }
}
