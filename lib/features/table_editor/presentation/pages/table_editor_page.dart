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
import 'package:submersion/features/table_editor/presentation/widgets/save_summary_dialog.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
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

  /// The tab last settled on. TabController.previousIndex goes stale on a
  /// tap of the selected tab, so the guard reads this instead.
  var _settled = 0;

  /// The open tab's handle, kept from the last build for a callback to use.
  _TabHandle? _handleNow;

  /// A Save all is running, from its summary to its last write.
  var _saving = false;

  TableEditorTab get _tab => TableEditorTab.values[_tabs.index];

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() => _settled = _tabs.index);
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

  bool get _anyDrafts => TableEditorTab.values.any(_hasDrafts);

  /// A cell left open holds typing no draft shows yet.
  bool get _anyOpenCell => TableEditorTab.values.any(
    (tab) => ref.read(tableEditorDraftsProvider(tab)).editing != null,
  );

  void _clearDrafts(TableEditorTab tab) {
    _lastPaste.remove(tab);
    ref.read(tableEditorDraftsProvider(tab).notifier).clear();
  }

  /// Closes any open cell and waits for what it held to land as a draft: a
  /// cell commits after the frame that removes it.
  Future<void> _closeOpenCells() async {
    if (!_anyOpenCell) return;
    for (final tab in TableEditorTab.values) {
      ref.read(tableEditorDraftsProvider(tab).notifier).setEditing(null);
    }
    await WidgetsBinding.instance.endOfFrame;
  }

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
    await _closeOpenCells();
    if (!mounted) return;
    if (_anyDrafts && !await _confirmDiscard()) return;
    if (!mounted) return;
    for (final tab in TableEditorTab.values) {
      _clearDrafts(tab);
    }
    navigator.pop();
  }

  /// The tab bar has already moved to [index] when this runs, so the tab
  /// being left is the one last settled on. With drafts there, go back and
  /// ask.
  Future<void> _onTabTap(int index) async {
    final from = _settled;
    if (index == from || !_hasDrafts(TableEditorTab.values[from])) return;
    _tabs.index = from;
    if (await _confirmDiscard() && mounted) {
      _clearDrafts(TableEditorTab.values[from]);
      _tabs.animateTo(index);
    }
  }

  /// Reached from a snackbar that may outlive the page.
  void _openChangeLog() {
    if (mounted) context.push('/settings/change-log');
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
        if (!mounted) return;
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
        if (!mounted) return;
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
      refresh: () {
        if (mounted) ref.invalidate(diveCenterListNotifierProvider);
      },
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
      pickColumns: () => showEntityTableColumnPicker<F>(
        context,
        configProvider: configProvider,
        adapter: entity.adapter,
      ),
      saveAll: ({bool confirm = true}) async {
        if (_saving) return false;
        setState(() => _saving = true);
        try {
          await _closeOpenCells();
          if (!mounted) return false;
          final saved = await TableEditorSaveFlow.saveAll<T, F>(
            context,
            ref,
            tab: tab,
            entity: entity,
            refresh: refresh,
            openChangeLog: _openChangeLog,
            lastPaste: _lastPaste[tab] as PastePlan<F>?,
            confirm: confirm,
          );
          if (saved) _lastPaste.remove(tab);
          return saved;
        } finally {
          if (mounted) setState(() => _saving = false);
        }
      },
      paste: () async {
        final drafts = ref.read(tableEditorDraftsProvider(tab));
        final selected = drafts.editing ?? drafts.selected;
        if (selected == null) return;
        final text = await readClipboardText();
        if (text == null || !mounted) return;
        final l10n = context.l10n;
        final config = ref.read(configProvider);
        final visible = [for (final c in config.columnsAsShown) c.field];
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
        final skipped = [...plan.skipped, ...extra];
        setState(
          () => _lastPaste[tab] = PastePlan<F>(
            matching: plan.matching,
            hadHeader: plan.hadHeader,
            cells: plan.cells,
            skipped: skipped,
          ),
        );
        // Skips wait for the save summary, which a paste that left nothing
        // to save never reaches: Save all stays off.
        if (skipped.isNotEmpty &&
            ref.read(tableEditorDraftsProvider(tab)).saveable.isEmpty) {
          final lines = [
            for (final s in skipped.take(5))
              pasteSkipLine(
                l10n,
                s,
                columnLabel: (name) =>
                    entity.fieldFromName(name).localizedDisplayName(l10n),
              ),
          ];
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(lines.join('\n'))));
        }
      },
    );
  }

  Future<void> _openRecord(String id) async {
    final handle = _handleNow;
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
          // Whatever the save wrote (flagged drafts stay as they are), the
          // diver asked to open the record.
          await handle.saveAll(confirm: false);
          if (!mounted) return;
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
      // The same guard as the wide view: drafts survive the narrowing and
      // must not be walked away from unasked.
      return PopScope(
        canPop: !_anyDrafts && !_anyOpenCell,
        onPopInvokedWithResult: (didPop, _) => _handlePop(didPop),
        child: Scaffold(
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
        ),
      );
    }
    final handle = _handleNow = _handle();
    final diveFilter = ref.watch(tableEditorDiveFilterProvider);
    final canPaste =
        handle != null && (drafts.editing ?? drafts.selected) != null;
    // While a text cell is open its own field handles Ctrl+V.
    final shortcutPaste = canPaste && drafts.editing == null;
    return PopScope(
      canPop: !_anyDrafts && !_anyOpenCell,
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
                  icon: const Icon(Icons.view_column_outlined),
                  tooltip: l10n.columnConfig_tooltip_columnSettings,
                  onPressed: handle?.pickColumns,
                ),
                IconButton(
                  icon: const Icon(Icons.content_paste),
                  tooltip: l10n.tableEditor_paste,
                  onPressed: canPaste ? handle.paste : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FilledButton(
                    // An open cell may hold the edit that makes it worth it.
                    onPressed:
                        handle != null &&
                            !_saving &&
                            (drafts.saveable.isNotEmpty ||
                                drafts.editing != null)
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
  final VoidCallback pickColumns;
  final Future<bool> Function({bool confirm}) saveAll;
  final Future<void> Function() paste;

  const _TabHandle({
    required this.route,
    required this.pickColumns,
    required this.saveAll,
    required this.paste,
  });
}
