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
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';
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
  final _focus = FocusNode(debugLabel: 'table editor');

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
    _focus.dispose();
    super.dispose();
  }

  bool _hasDrafts(TableEditorTab tab) =>
      !ref.read(tableEditorDraftsProvider(tab)).isEmpty;

  void _clearDrafts(TableEditorTab tab) =>
      ref.read(tableEditorDraftsProvider(tab).notifier).clear();

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
    if (didPop) {
      for (final tab in TableEditorTab.values) {
        _clearDrafts(tab);
      }
      return;
    }
    final navigator = Navigator.of(context);
    if (await _confirmDiscard() && mounted) {
      for (final tab in TableEditorTab.values) {
        _clearDrafts(tab);
      }
      navigator.pop();
    }
  }

  /// The tab bar has already moved to [index] when this runs, so the tab
  /// being left is the previous one. With drafts there, go back and ask.
  Future<void> _onTabTap(int index) async {
    final from = _tabs.previousIndex;
    if (index == from || !_hasDrafts(TableEditorTab.values[from])) return;
    _tabs.index = from;
    if (await _confirmDiscard() && mounted) {
      _clearDrafts(TableEditorTab.values[from]);
      _tabs.animateTo(index);
    }
  }

  void _openChangeLog() => context.push('/settings/change-log');

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
        openChangeLog: _openChangeLog,
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
        final config = ref.read(configProvider);
        final visible = [for (final c in config.columns) c.field];
        // The block lands in the order on screen.
        final shown = sortTableEntities(
          rows,
          entity.adapter,
          config,
          ref.read(unitFormatterProvider),
        );
        final plan = planClipboardPaste<T, F>(
          text: text,
          entity: entity,
          rows: shown,
          visibleColumns: visible,
          selected: selected,
          l10n: l10n,
          hiddenKeys: hiddenKeys(),
        );
        final notifier = ref.read(tableEditorDraftsProvider(tab).notifier);
        notifier.setEditing(null);
        final extra = applyPastePlan<T, F>(
          plan: plan,
          entity: entity,
          rowsById: {for (final r in rows) entity.idOf(r): r},
          units: ref.read(unitFormatterProvider),
          l10n: l10n,
          notifier: notifier,
          existing: ref.read(tableEditorDraftsProvider(tab)),
        );
        setState(
          () => _lastPaste[tab] = PastePlan<F>(
            matching: plan.matching,
            hadHeader: plan.hadHeader,
            cells: plan.cells,
            skipped: [...plan.skipped, ...extra],
          ),
        );
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
          _clearDrafts(_tab);
        case _OpenChoice.save:
          if (!await handle.saveAll(confirm: false) || !mounted) return;
      }
    }
    if (mounted) context.push(handle.route(id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Watched before the width gate, so narrowing the window (a tablet
    // turned to portrait) keeps every tab's drafts alive.
    final drafts = ref.watch(tableEditorDraftsProvider(_tab));
    for (final tab in TableEditorTab.values) {
      ref.watch(tableEditorDraftsProvider(tab));
    }
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
    final handle = _handle();
    final diveFilter = ref.watch(tableEditorDiveFilterProvider);
    final canPaste =
        handle != null && (drafts.editing ?? drafts.selected) != null;
    // While a text cell is open its own field handles Ctrl+V.
    final shortcutPaste = canPaste && drafts.editing == null;
    return PopScope(
      canPop: drafts.isEmpty,
      onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () {
            if (shortcutPaste) handle.paste();
          },
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () {
            if (shortcutPaste) handle.paste();
          },
        },
        child: Focus(
          focusNode: _focus,
          autofocus: true,
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
                  AppBarTextAction(
                    label: l10n.tableEditor_clearFilters,
                    onPressed: () =>
                        ref.read(tableEditorDiveFilterProvider.notifier).state =
                            const DiveFilterState(),
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
