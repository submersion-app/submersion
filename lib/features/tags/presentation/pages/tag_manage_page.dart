import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/log_failure.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_input_widget.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_merge_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/selection/selection_state.dart';

class TagManagePage extends ConsumerStatefulWidget {
  const TagManagePage({super.key});

  @override
  ConsumerState<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends ConsumerState<TagManagePage> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  /// Owns the bulk-selection state machine for this page.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;

  static const _uuid = Uuid();
  static final _log = LoggerService.forClass(TagManagePage);

  @override
  void dispose() {
    _searchController.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(tagStatisticsProvider);
    final visibleIds = _visibleStats(
      statsAsync.valueOrNull ?? const [],
    ).map((s) => s.tag.id).toList();

    // Drop checked tags that the search query hid, so a bulk delete can never
    // reach a tag that is not on screen. pruneTo is a no-op when nothing
    // changed, which keeps this off a rebuild loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? _buildSelectionAppBar(statsAsync.valueOrNull ?? const [])
              : AppBar(
                  title: Text(context.l10n.tags_manage_title),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: context.l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                  ],
                ),
          floatingActionButton: selection.isActive
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showCreateDialog(),
                  tooltip: context.l10n.tags_manage_createTitle,
                  icon: const Icon(Icons.add),
                  label: Text(context.l10n.tags_manage_createTitle),
                ),
          body: Column(
            children: [
              // Hidden during selection: this is a settings control, not
              // part of the list being acted on, and the space is better
              // spent on the list itself while a bulk action is in progress.
              if (!selection.isActive) _buildAutoTagSection(),
              // Search stays visible during selection: narrowing the list
              // mid-selection is a supported move, and the selection prunes
              // to whatever remains.
              _buildSearchBar(),
              Expanded(
                child: statsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error: $e')),
                  data: (stats) => _buildTagList(stats),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Whether the import wizard auto-tags every new import session (issue
  /// #998), plus its switch.
  ///
  /// Placed above the search bar, not as a wizard step, so the choice is a
  /// standing preference rather than something re-decided at every import.
  /// This is only the starting point for a new session -- the review step's
  /// Import Options sheet lets the diver override it for a single import
  /// without touching this default.
  ///
  /// Watches only [AppSettings.autoTagImports] via `select`, not the whole
  /// [settingsProvider]: a change to any other setting elsewhere in the app
  /// would otherwise rebuild this switch for no reason.
  Widget _buildAutoTagSection() {
    final autoTagImports = ref.watch(
      settingsProvider.select((s) => s.autoTagImports),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            context.l10n.tags_manage_importsSection,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        SwitchListTile(
          title: Text(context.l10n.tags_manage_autoTagImports),
          subtitle: Text(context.l10n.tags_manage_autoTagImports_subtitle),
          value: autoTagImports,
          onChanged: (value) {
            ref.read(settingsProvider.notifier).setAutoTagImports(value);
          },
        ),
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: context.l10n.tags_manage_searchHint,
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true,
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  /// Tags matching the current search query.
  ///
  /// Shared by the list and by the pruning in [build], so the selection can
  /// never hold a tag the query has hidden.
  List<TagStatistic> _visibleStats(List<TagStatistic> stats) {
    if (_searchQuery.isEmpty) return stats;
    final query = _searchQuery.toLowerCase();
    return stats
        .where((stat) => stat.tag.name.toLowerCase().contains(query))
        .toList();
  }

  Widget _buildTagList(List<TagStatistic> stats) {
    final filtered = _visibleStats(stats);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          context.l10n.tags_manage_emptyState,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final stat = filtered[index];
        return _buildTagRow(stat);
      },
    );
  }

  Widget _buildTagRow(TagStatistic stat) {
    final tag = stat.tag;
    final isSelected = _selectedIds.contains(tag.id);

    return ListTile(
      leading: SelectionLeading(
        isSelectionMode: _isSelectionMode,
        isChecked: isSelected,
        onChanged: (_) => _toggleSelection(tag.id),
        child: CircleAvatar(radius: 16, backgroundColor: tag.color),
      ),
      title: Text(tag.name),
      // Where the tag is offered (issue #1765).
      subtitle: Text(
        [
          if (tag.appliesToDives) context.l10n.tags_manage_scope_dives,
          if (tag.appliesToSites) context.l10n.tags_manage_scope_sites,
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            [
              context.l10n.tags_manage_diveCount(stat.diveCount),
              if (stat.siteCount > 0)
                context.l10n.tags_manage_siteCount(stat.siteCount),
            ].join(', '),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          // The one way to edit a tag. Hidden while selecting, where a row
          // tap toggles the row and a second target inside it would be a
          // trap.
          if (!_isSelectionMode)
            IconButton(
              key: ValueKey('tag_edit_${tag.id}'),
              icon: const Icon(Icons.edit_outlined),
              tooltip: context.l10n.tags_manage_editTitle,
              onPressed: () => _showEditDialog(stat),
            ),
        ],
      ),
      selected: isSelected,
      // Outside selection the row is inert, whatever the tag's scope: this is
      // a settings page, and a tap here must not leave it. The edit button is
      // the row's only action.
      onTap: _isSelectionMode ? () => _toggleSelection(tag.id) : null,
    );
  }

  void _showCreateDialog() {
    final controller = TextEditingController();
    String selectedColor = TagColors.predefined.first;
    bool forDives = true;
    bool forSites = false;
    bool saving = false;
    bool failed = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          // The barrier, Back and Escape all ask before popping. A save in
          // flight says no, so a failure still has its dialog to report into.
          canPop: !saving,
          child: AlertDialog(
            title: Text(context.l10n.tags_manage_createTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.tags_manage_nameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.tags_manage_colorLabel),
                  const SizedBox(height: 8),
                  TagColorPicker(
                    selectedColor: selectedColor,
                    onColorSelected: (color) =>
                        setDialogState(() => selectedColor = color),
                  ),
                  const SizedBox(height: 8),
                  ..._scopeEditor(
                    forDives: forDives,
                    forSites: forSites,
                    onDives: (v) => setDialogState(() => forDives = v),
                    onSites: (v) => setDialogState(() => forSites = v),
                  ),
                  if (failed) _saveErrorLine(),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: Text(context.l10n.common_action_cancel),
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () {
                        // A second tap in the same frame still reaches this
                        // callback: the disabled button is only built next frame.
                        if (saving) return;
                        final name = controller.text.trim();
                        if (name.isEmpty || (!forDives && !forSites)) return;
                        final newTag =
                            Tag.create(
                              id: _uuid.v4(),
                              name: name,
                              colorHex: selectedColor,
                            ).copyWith(
                              appliesToDives: forDives,
                              appliesToSites: forSites,
                            );
                        _saveFromDialog(
                          dialogContext,
                          setSaving: (v) => setDialogState(() => saving = v),
                          setFailed: (v) => setDialogState(() => failed = v),
                          save: () async {
                            await ref
                                .read(tagListNotifierProvider.notifier)
                                .addTag(newTag);
                            return true;
                          },
                        );
                      },
                child: Text(context.l10n.common_action_save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(TagStatistic stat) {
    final tag = stat.tag;
    final controller = TextEditingController(text: tag.name);
    String selectedColor = tag.colorHex ?? TagColors.predefined.first;
    bool forDives = tag.appliesToDives;
    bool forSites = tag.appliesToSites;
    bool saving = false;
    bool failed = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => PopScope(
          // See _showCreateDialog: no dismissal while a save is in flight.
          canPop: !saving,
          child: AlertDialog(
            title: Text(context.l10n.tags_manage_editTitle),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.l10n.tags_manage_nameLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.tags_manage_colorLabel),
                  const SizedBox(height: 8),
                  TagColorPicker(
                    selectedColor: selectedColor,
                    onColorSelected: (color) =>
                        setDialogState(() => selectedColor = color),
                  ),
                  const SizedBox(height: 8),
                  ..._scopeEditor(
                    forDives: forDives,
                    forSites: forSites,
                    onDives: (v) => setDialogState(() => forDives = v),
                    onSites: (v) => setDialogState(() => forSites = v),
                  ),
                  if (failed) _saveErrorLine(),
                ],
              ),
            ),
            // Delete sits apart on the leading edge, away from Save (#1889).
            // Before this it was reachable only through selection mode.
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: [
              TextButton(
                key: const ValueKey('tag_edit_delete'),
                // Disabled with Cancel while a save is in flight. Otherwise
                // onPressed cannot await, so the flow carries its own
                // listener, as the selection bar's dispatch does.
                onPressed: saving
                    ? null
                    : () => logFailure(
                        _deleteFromEditor(dialogContext, stat),
                        TagManagePage,
                        'delete a tag from its edit dialog',
                      ),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(context.l10n.common_action_delete),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: saving
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: Text(context.l10n.common_action_cancel),
                  ),
                  TextButton(
                    onPressed: saving
                        ? null
                        : () {
                            // See _showCreateDialog: guards a same-frame second tap.
                            if (saving) return;
                            // Taken now, so the write matches what the narrowing
                            // confirmation described even if the controls change
                            // while the usage read is in flight.
                            final name = controller.text.trim();
                            final color = selectedColor;
                            final dives = forDives;
                            final sites = forSites;
                            if (name.isEmpty || (!dives && !sites)) return;
                            _saveFromDialog(
                              dialogContext,
                              setSaving: (v) =>
                                  setDialogState(() => saving = v),
                              setFailed: (v) =>
                                  setDialogState(() => failed = v),
                              save: () async {
                                final confirmed = await _confirmNarrowing(
                                  tag,
                                  forDives: dives,
                                  forSites: sites,
                                );
                                if (!confirmed) return false;
                                await ref
                                    .read(tagListNotifierProvider.notifier)
                                    .updateTag(
                                      tag.copyWith(
                                        name: name,
                                        colorHex: color,
                                        updatedAt: DateTime.now(),
                                        appliesToDives: dives,
                                        appliesToSites: sites,
                                      ),
                                    );
                                // Site cards and the site filter read tags too.
                                ref.invalidate(sitesWithCountsProvider);
                                return true;
                              },
                            );
                          },
                    child: Text(context.l10n.common_action_save),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deletes [stat]'s tag from its edit dialog, once the diver confirms.
  ///
  /// The confirmation stacks over the editor, so cancelling it returns there
  /// with any unsaved edits intact.
  Future<void> _deleteFromEditor(
    BuildContext dialogContext,
    TagStatistic stat,
  ) async {
    if (!await _confirmDeleteTag(dialogContext, stat)) return;
    if (!dialogContext.mounted) return;
    Navigator.pop(dialogContext);
    await ref.read(tagListNotifierProvider.notifier).deleteTag(stat.tag.id);
  }

  /// Runs a tag dialog's [save], closing the dialog only once it lands.
  ///
  /// [save] returns false when it chose not to write (the diver declined the
  /// narrowing confirmation), which leaves the dialog open without an error.
  /// A failure is logged and flagged through [setFailed], and the dialog
  /// stays open with its edits so the diver can retry (#1907). [setSaving]
  /// disables the dialog's buttons meanwhile, so a second tap cannot start a
  /// second write. A new attempt clears the previous failure.
  ///
  /// Every failure is caught here, so the Future a button drops cannot reach
  /// the zone unattributed.
  Future<void> _saveFromDialog(
    BuildContext dialogContext, {
    required ValueChanged<bool> setSaving,
    required ValueChanged<bool> setFailed,
    required Future<bool> Function() save,
  }) async {
    setFailed(false);
    setSaving(true);
    try {
      if (await save() && dialogContext.mounted) {
        Navigator.pop(dialogContext);
      }
    } catch (e, stackTrace) {
      _log.error('Failed to save a tag', error: e, stackTrace: stackTrace);
      if (dialogContext.mounted) setFailed(true);
    } finally {
      if (dialogContext.mounted) setSaving(false);
    }
  }

  /// The failed-save line, shown in the dialog itself: a page SnackBar would
  /// render under the dialog's barrier, dimmed and out of reach (#1907). A
  /// live region, so a screen reader announces it.
  Widget _saveErrorLine() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Semantics(
      liveRegion: true,
      child: Text(
        context.l10n.common_error_tryAgain,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ),
  );

  /// "Use for dives" and "Use for sites" (issue #1765), with an error line
  /// while neither is ticked.
  List<Widget> _scopeEditor({
    required bool forDives,
    required bool forSites,
    required ValueChanged<bool> onDives,
    required ValueChanged<bool> onSites,
  }) {
    final l10n = context.l10n;
    return [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.tags_manage_useForDives),
        value: forDives,
        onChanged: (v) => onDives(v ?? false),
      ),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.tags_manage_useForSites),
        value: forSites,
        onChanged: (v) => onSites(v ?? false),
      ),
      if (!forDives && !forSites)
        Text(
          l10n.tags_manage_scopeRequired,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
    ];
  }

  /// Turning off a scope removes the tag from every dive or site carrying it
  /// (the repository does that so a link always implies its scope). Asks
  /// first when that would remove anything; true to go ahead.
  Future<bool> _confirmNarrowing(
    Tag tag, {
    required bool forDives,
    required bool forSites,
  }) async {
    final droppingDives = tag.appliesToDives && !forDives;
    final droppingSites = tag.appliesToSites && !forSites;
    if (!droppingDives && !droppingSites) return true;

    final l10n = context.l10n;
    final usage = await ref.read(tagRepositoryProvider).getTagUsage(tag.id);
    final messages = [
      if (droppingDives && usage.dives > 0)
        l10n.tags_manage_narrowDialog_dives(usage.dives),
      if (droppingSites && usage.sites > 0)
        l10n.tags_manage_narrowDialog_sites(usage.sites),
    ];
    if (messages.isEmpty || !mounted) return true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.tags_manage_narrowDialog_title),
        content: Text(messages.join('\n\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.l10n.tags_manage_narrowDialog_confirm),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  // -- Selection mode --

  /// Tag-specific extras. Select-all, deselect-all and delete are supplied by
  /// SelectionAppBar -- this page had neither select-all nor deselect-all
  /// before, and gains both from the shared bar.
  List<BulkAction> _bulkActions(List<TagStatistic> stats) {
    return [
      BulkAction(
        id: 'merge',
        // Canonical merge glyph. This page used Icons.merge while sites and
        // buddies used Icons.merge_type for the same concept.
        icon: Icons.merge_type,
        label: context.l10n.tags_manage_mergeAction,
        minCount: 2,
        onInvoke: () => _showMergeSheet(context),
      ),
    ];
  }

  SelectionAppBar _buildSelectionAppBar(List<TagStatistic> stats) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: _visibleStats(stats).map((s) => s.tag.id).toList(),
      actions: _bulkActions(stats),
      shell: SelectionBarShell.appBar,
      onDelete: () => _confirmDelete(context),
    );
  }

  Future<BulkActionOutcome> _confirmDelete(BuildContext context) async {
    final repository = ref.read(tagRepositoryProvider);
    final statsAsync = ref.read(tagStatisticsProvider);
    final stats = statsAsync.valueOrNull ?? [];

    if (_selectedIds.length == 1) {
      final tagId = _selectedIds.first;
      final stat = stats.firstWhere((s) => s.tag.id == tagId);

      if (!await _confirmDeleteTag(context, stat)) {
        return BulkActionOutcome.cancelled;
      }
      await ref.read(tagListNotifierProvider.notifier).deleteTag(tagId);
      return BulkActionOutcome.completed;
    } else {
      final totalDives = await repository.getMergedDiveCount(
        _selectedIds.toList(),
      );

      if (!context.mounted) return BulkActionOutcome.cancelled;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            ctx.l10n.tags_manage_bulkDeleteTitle(_selectedIds.length),
          ),
          content: Text(ctx.l10n.tags_manage_bulkDeleteMessage(totalDives)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.common_action_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(ctx.l10n.common_action_delete),
            ),
          ],
        ),
      );

      if (confirmed != true) return BulkActionOutcome.cancelled;
      await ref
          .read(tagListNotifierProvider.notifier)
          .deleteTags(_selectedIds.toList());
      return BulkActionOutcome.completed;
    }
  }

  /// Asks before deleting one tag, naming it and the dives it will leave.
  ///
  /// Shared by the selection bar and the edit dialog so the two delete paths
  /// cannot drift apart.
  Future<bool> _confirmDeleteTag(
    BuildContext context,
    TagStatistic stat,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.tags_manage_deleteTitle),
        content: Text(
          ctx.l10n.tags_manage_deleteMessage(stat.tag.name, stat.diveCount),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(ctx.l10n.common_action_delete),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<BulkActionOutcome> _showMergeSheet(BuildContext context) async {
    final statsAsync = ref.read(tagStatisticsProvider);
    final stats = statsAsync.valueOrNull ?? [];
    final selectedStats = stats
        .where((s) => _selectedIds.contains(s.tag.id))
        .toList();

    if (selectedStats.length < 2) return BulkActionOutcome.cancelled;

    final merged = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => TagMergeSheet(selectedStats: selectedStats),
    );

    return merged == true
        ? BulkActionOutcome.completed
        : BulkActionOutcome.cancelled;
  }

  void _toggleSelection(String id) => _selection.toggle(id);
}
