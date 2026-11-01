import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/table_editor/domain/paste_planner.dart';
import 'package:submersion/features/table_editor/domain/table_editor_entity.dart';
import 'package:submersion/features/table_editor/presentation/providers/table_editor_providers.dart';
import 'package:submersion/features/table_editor/presentation/table_editor_paste.dart';
import 'package:submersion/features/table_editor/presentation/table_editor_save_flow.dart';
import 'package:submersion/features/table_editor/presentation/widgets/table_editor_tabs.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';

/// Settings, Data tools, Table editor (#3422): a spreadsheet per entity
/// where cells are typed into or pasted, kept as drafts, and saved all at
/// once as one undoable operation. Desktop and tablet widths only.
class TableEditorPage extends ConsumerStatefulWidget {
  const TableEditorPage({super.key});

  @override
  ConsumerState<TableEditorPage> createState() => _TableEditorPageState();
}

class _TableEditorPageState extends ConsumerState<TableEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: TableEditorTab.values.length,
    vsync: this,
  );
  final _lastPaste = <TableEditorTab, PastePlan<EntityField>>{};

  TableEditorTab get _tab => TableEditorTab.values[_tabs.index];

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  bool _hasDrafts(TableEditorTab tab) =>
      !ref.read(tableEditorDraftsProvider(tab)).isEmpty;

  /// The same dialog the edit forms show; true means discard.
  Future<bool> _confirmDiscard() async {
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.forms_discard_title),
        content: Text(l10n.forms_discard_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.forms_discard_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.forms_discard_discard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _handlePop(bool didPop) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    if (await _confirmDiscard() && mounted) {
      ref.read(tableEditorDraftsProvider(_tab).notifier).clear();
      navigator.pop();
    }
  }

  /// The active tab's entity, rows and columns, erased of their types so
  /// the toolbar can act on whichever tab is open.
  _TabHandle? _handle() => switch (_tab) {
    TableEditorTab.dives => _handleFor<Dive, DiveField>(
      TableEditorTab.dives,
      ref.watch(tableEditorDiveEntityProvider).value,
      ref.watch(tableEditorDivesProvider).value,
      tableEditorDiveConfigProvider,
      route: (id) => '/dives/$id',
      refresh: () {
        ref.read(diveListNotifierProvider.notifier).refresh();
        ref.invalidate(tableEditorWeightsProvider);
      },
      hiddenKeys: () {
        final all = ref.read(diveListNotifierProvider).value ?? const [];
        final shown = ref.read(tableEditorDivesProvider).value ?? const [];
        final shownIds = {for (final d in shown) d.id};
        return {
          for (final d in all)
            if (!shownIds.contains(d.id) && d.diveNumber != null)
              '${d.diveNumber}',
        };
      },
    ),
    TableEditorTab.sites => _handleFor<SiteWithCount, SiteField>(
      TableEditorTab.sites,
      ref.watch(tableEditorSiteEntityProvider).value,
      ref.watch(tableEditorSitesProvider).value,
      tableEditorSiteConfigProvider,
      route: (id) => '/sites/$id',
      refresh: () {
        ref.invalidate(sitesWithCountsProvider);
        ref.invalidate(sitesProvider);
      },
      hiddenKeys: () {
        final all = ref.read(sitesWithCountsProvider).value ?? const [];
        final shown = ref.read(tableEditorSitesProvider).value ?? const [];
        final shownIds = {for (final s in shown) s.site.id};
        return {
          for (final s in all)
            if (!shownIds.contains(s.site.id)) s.site.name,
        };
      },
    ),
    TableEditorTab.centers => _handleFor<DiveCenterRow, DiveCenterField>(
      TableEditorTab.centers,
      ref.watch(tableEditorCenterEntityProvider),
      ref.watch(tableEditorCentersProvider).value,
      tableEditorCenterConfigProvider,
      route: (id) => '/dive-centers/$id',
      refresh: () => ref.invalidate(diveCenterListNotifierProvider),
      hiddenKeys: () {
        final all = ref.read(diveCenterListNotifierProvider).value ?? const [];
        final shown = ref.read(tableEditorCentersProvider).value ?? const [];
        final shownIds = {for (final c in shown) c.center.id};
        return {
          for (final c in all)
            if (!shownIds.contains(c.id)) c.name,
        };
      },
    ),
  };

  _TabHandle? _handleFor<T, F extends EntityField>(
    TableEditorTab tab,
    TableEditorEntity<T, F>? entity,
    List<T>? rows,
    StateNotifierProvider<
      EntityTableConfigNotifier<F>,
      EntityTableViewConfig<F>
    >
    configProvider, {
    required String Function(String id) route,
    required VoidCallback refresh,
    required Set<String> Function() hiddenKeys,
  }) {
    if (entity == null || rows == null) return null;
    return _TabHandle(
      route: route,
      saveAll: ({bool confirm = true}) => TableEditorSaveFlow.saveAll<T, F>(
        context,
        ref,
        tab: tab,
        entity: entity,
        rows: rows,
        refresh: refresh,
        lastPaste: _lastPaste[tab] as PastePlan<F>?,
        confirm: confirm,
      ),
      paste: () async {
        final drafts = ref.read(tableEditorDraftsProvider(tab));
        final selected = drafts.editing ?? drafts.selected;
        if (selected == null) return;
        final text = await readClipboardText();
        if (text == null || !mounted) return;
        final l10n = context.l10n;
        final visible = [
          for (final c in ref.read(configProvider).columns) c.field,
        ];
        final plan = planClipboardPaste<T, F>(
          text: text,
          entity: entity,
          rows: rows,
          visibleColumns: visible,
          selected: selected,
          l10n: l10n,
          hiddenKeys: hiddenKeys(),
        );
        final notifier = ref.read(tableEditorDraftsProvider(tab).notifier);
        notifier.setEditing(null);
        applyPastePlan<T, F>(
          plan: plan,
          entity: entity,
          rowsById: {for (final r in rows) entity.idOf(r): r},
          units: ref.read(unitFormatterProvider),
          l10n: l10n,
          notifier: notifier,
          existing: drafts,
        );
        setState(() => _lastPaste[tab] = plan);
      },
    );
  }

  Future<void> _openRecord(String id) async {
    final handle = _handle();
    if (handle == null) return;
    if (_hasDrafts(_tab)) {
      final l10n = context.l10n;
      final choice = await showDialog<_OpenChoice>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.forms_discard_title),
          content: Text(l10n.forms_discard_body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_OpenChoice.stay),
              child: Text(l10n.tableEditor_open_stay),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(_OpenChoice.discard),
              child: Text(l10n.tableEditor_open_discardAndOpen),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_OpenChoice.save),
              child: Text(l10n.tableEditor_open_saveAndOpen),
            ),
          ],
        ),
      );
      if (!mounted) return;
      switch (choice) {
        case null || _OpenChoice.stay:
          return;
        case _OpenChoice.discard:
          ref.read(tableEditorDraftsProvider(_tab).notifier).clear();
        case _OpenChoice.save:
          if (!await handle.saveAll(confirm: false) || !mounted) return;
      }
    }
    if (mounted) context.push(handle.route(id));
  }

  Future<void> _onTabTap(int index) async {
    if (index == _tabs.index || !_hasDrafts(_tab)) return;
    _tabs.index = _tabs.previousIndex;
    if (await _confirmDiscard() && mounted) {
      ref.read(tableEditorDraftsProvider(_tab).notifier).clear();
      _tabs.animateTo(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!ResponsiveBreakpoints.isDesktop(context)) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tableEditor_title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.tableEditor_needsWiderScreen,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final drafts = ref.watch(tableEditorDraftsProvider(_tab));
    final handle = _handle();
    final diveFilter = ref.watch(tableEditorDiveFilterProvider);
    final canPaste =
        handle != null && (drafts.editing ?? drafts.selected) != null;
    return PopScope(
      canPop: drafts.isEmpty,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () {
            if (canPaste) handle.paste();
          },
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () {
            if (canPaste) handle.paste();
          },
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(l10n.tableEditor_title),
            actions: [
              if (!drafts.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(l10n.tableEditor_draftCount(drafts.count)),
                  ),
                ),
              if (_tab == TableEditorTab.dives && diveFilter.hasActiveFilters)
                TextButton(
                  onPressed: () =>
                      ref.read(tableEditorDiveFilterProvider.notifier).state =
                          const DiveFilterState(),
                  child: Text(l10n.tableEditor_clearFilters),
                ),
              IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: l10n.tableEditor_paste,
                onPressed: canPaste ? handle.paste : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: FilledButton(
                  onPressed: handle != null && drafts.saveable.isNotEmpty
                      ? () => handle.saveAll()
                      : null,
                  child: Text(l10n.tableEditor_saveAll),
                ),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              onTap: _onTabTap,
              tabs: [
                Tab(text: l10n.tableEditor_tab_dives),
                Tab(text: l10n.tableEditor_tab_sites),
                Tab(text: l10n.tableEditor_tab_centers),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              DiveEditorTab(onOpenRecord: _openRecord),
              SiteEditorTab(onOpenRecord: _openRecord),
              CenterEditorTab(onOpenRecord: _openRecord),
            ],
          ),
        ),
      ),
    );
  }
}

enum _OpenChoice { stay, discard, save }

/// What the toolbar can do with the open tab, whatever its entity type.
class _TabHandle {
  final String Function(String id) route;
  final Future<bool> Function({bool confirm}) saveAll;
  final Future<void> Function() paste;

  const _TabHandle({
    required this.route,
    required this.saveAll,
    required this.paste,
  });
}
