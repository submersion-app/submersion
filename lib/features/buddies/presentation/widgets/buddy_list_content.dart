import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_entry_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_tile.dart';
import 'package:submersion/features/buddies/presentation/widgets/compact_buddy_list_tile.dart';
import 'package:submersion/features/buddies/presentation/widgets/dense_buddy_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Content widget for the buddy list, used in master-detail layout.
///
/// This widget contains the core list functionality extracted from BuddyListPage.
/// It can be used standalone (mobile) or as the master pane in a split view (desktop).
class BuddyListContent extends ConsumerStatefulWidget {
  /// Callback when an item is selected. Used in master-detail mode.
  final void Function(String?)? onItemSelected;

  /// Currently selected item ID. Used to highlight the selected item.
  final String? selectedId;

  /// Whether to show the app bar. Set to false when used inside MasterDetailScaffold.
  final bool showAppBar;

  /// Optional floating action button to display when showAppBar is true.
  final Widget? floatingActionButton;

  const BuddyListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
  });

  @override
  ConsumerState<BuddyListContent> createState() => _BuddyListContentState();
}

class _BuddyListContentState extends ConsumerState<BuddyListContent> {
  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList = false;

  /// Owns the bulk-selection state machine for this list.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;
  BuddyMergeSnapshot? _mergeSnapshot;

  /// Check if contact import is supported on this platform
  bool get _isContactImportSupported {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(BuddyListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != _lastScrolledToId) {
      if (_selectionFromList) {
        _selectionFromList = false;
        _lastScrolledToId = widget.selectedId;
      } else {
        _scrollToSelectedItem();
      }
    }
  }

  void _scrollToSelectedItem() {
    if (widget.selectedId == null) return;

    final buddiesAsync = ref.read(allBuddiesWithDiveCountProvider);
    buddiesAsync.whenData((buddies) {
      final index = buddies.indexWhere((b) => b.buddy.id == widget.selectedId);
      if (index >= 0 && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || buddies.isEmpty) return;

          final maxScroll = _scrollController.position.maxScrollExtent;
          final viewportHeight = _scrollController.position.viewportDimension;
          final totalContentHeight = maxScroll + viewportHeight - 80;
          final avgItemHeight = totalContentHeight / buddies.length;
          final targetOffset = (index * avgItemHeight) - (viewportHeight / 3);
          final clampedOffset = targetOffset.clamp(0.0, maxScroll);

          _scrollController.animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _lastScrolledToId = widget.selectedId;
        });
      }
    });
  }

  void _handleItemTap(Buddy buddy) {
    if (_isSelectionMode) {
      _toggleSelection(buddy.id);
      return;
    }

    ref.read(highlightedBuddyIdProvider.notifier).state = buddy.id;

    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(buddy.id);
    } else {
      context.push('/buddies/${buddy.id}');
    }
  }

  /// Enter selection mode implicitly, from a modifier-click, checking [id].
  ///
  /// Clearing the highlight keeps the detail pane from arguing with the bulk
  /// selection about what the row means: a row left highlighted but unchecked
  /// reads as selected while no bulk action would touch it.
  ///
  /// The Select controls route to [SelectionController.enterExplicit] directly
  /// -- they have no row to check -- so this helper only ever serves the
  /// implicit path, which since the removal of long-press entry means
  /// modifier-click alone.
  void _enterImplicitSelection(String id, {String? seedId}) {
    ref.read(highlightedBuddyIdProvider.notifier).state = null;
    _selection.enterImplicit(id, seedId: seedId);
  }

  void _exitSelectionMode() => _selection.exit();

  void _toggleSelection(String id) => _selection.toggle(id);

  /// Select the contiguous span from the anchor buddy to [targetId].
  ///
  /// With no anchor yet, the highlighted row is the origin, matching Finder.
  void _selectRangeTo(String targetId, List<String> orderedIds) {
    _selection.extendTo(
      targetId,
      orderedIds,
      fallbackAnchorId: ref.read(highlightedBuddyIdProvider),
    );
  }

  /// Cmd/Ctrl-click [id], carrying the highlighted buddy into the selection.
  ///
  /// Outside selection mode the highlighted row is what the user sees as
  /// selected, so a modifier-click adds to it rather than replacing it. A
  /// highlight that filtering has pushed out of [orderedIds] is ignored, so
  /// the count can never include a buddy that is not on screen.
  void _modifierTap(String id, List<String> orderedIds) {
    final highlighted = ref.read(highlightedBuddyIdProvider);
    _enterImplicitSelection(
      id,
      seedId: highlighted != null && orderedIds.contains(highlighted)
          ? highlighted
          : null,
    );
  }

  /// One tap policy for every buddy row, in every view mode.
  ///
  /// A held modifier turns a tap into an implicit entry -- the one path that
  /// still evaporates at zero checked, since touch has no gesture entry left.
  /// Shift extends from the anchor, falling back to the highlighted row.
  void _handleRowTap(String id, List<BuddyWithDiveCount> buddies) {
    final orderedIds = buddies.map((b) => b.buddy.id).toList();
    if (SelectableListScope.isShiftPressed()) {
      _selectRangeTo(id, orderedIds);
      return;
    }
    if (SelectableListScope.isModifierPressed()) {
      _modifierTap(id, orderedIds);
      return;
    }
    if (_isSelectionMode) {
      _selection.toggle(id);
      return;
    }
    final index = buddies.indexWhere((b) => b.buddy.id == id);
    if (index < 0) return;
    _handleItemTap(buddies[index].buddy);
  }

  Future<void> _startMerge() async {
    final selectedCount = _selectedIds.length;
    final result = await context.push<BuddyMergeResult>(
      '/buddies/merge',
      extra: _selectedIds.toList(),
    );

    if (!mounted || result == null) return;

    _mergeSnapshot = result.snapshot;
    final mergedId = result.survivorId;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    _selection.exit();

    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(mergedId);
    }

    if (_mergeSnapshot != null && mounted) {
      scaffoldMessenger.clearSnackBars();
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.buddies_list_merge_snackbar(selectedCount),
          ),
          duration: const Duration(seconds: 5),
          showCloseIcon: true,
          action: SnackBarAction(
            label: context.l10n.buddies_list_merge_undo,
            onPressed: () async {
              if (_mergeSnapshot != null) {
                await ref
                    .read(buddyListNotifierProvider.notifier)
                    .undoMerge(_mergeSnapshot!);
                _mergeSnapshot = null;
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(context.l10n.buddies_list_merge_restored),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    }
  }

  Future<void> _confirmAndDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.buddies_list_bulkDelete_title),
        content: Text(context.l10n.buddies_list_bulkDelete_content(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.buddies_list_bulkDelete_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.buddies_list_bulkDelete_confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final idsToDelete = _selectedIds.toList();
      _exitSelectionMode();

      await ref
          .read(buddyListNotifierProvider.notifier)
          .bulkDeleteBuddies(idsToDelete);

      if (mounted) {
        scaffoldMessenger.clearSnackBars();
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.buddies_list_bulkDelete_snackbar(idsToDelete.length),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _importFromContacts(BuildContext context) async {
    if (!_isContactImportSupported) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.buddies_message_contactImportUnavailable,
            ),
          ),
        );
      }
      return;
    }

    try {
      if (!await FlutterContacts.permissions.has(PermissionType.read)) {
        await FlutterContacts.permissions.request(PermissionType.read);
        if (!await FlutterContacts.permissions.has(PermissionType.read)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  context.l10n.buddies_message_contactPermissionRequired,
                ),
              ),
            );
          }
          return;
        }
      }

      final pickedContact = await FlutterContacts.native.showPicker();
      final contactId = pickedContact?.id;
      if (contactId == null) return;

      final fullContact = await FlutterContacts.get(contactId);
      if (fullContact == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.buddies_message_contactLoadFailed),
            ),
          );
        }
        return;
      }

      final name = fullContact.displayName;
      final email = fullContact.emails.isNotEmpty
          ? fullContact.emails.first.address
          : null;
      final phone = fullContact.phones.isNotEmpty
          ? fullContact.phones.first.number
          : null;

      if (context.mounted) {
        if (ResponsiveBreakpoints.isMasterDetail(context)) {
          // For desktop, pass data via query params (simplified approach)
          final state = GoRouterState.of(context);
          context.go('${state.uri.path}?mode=new');
        } else {
          context.push(
            '/buddies/new',
            extra: {'name': name, 'email': email, 'phone': phone},
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.buddies_message_errorImportingContact(e.toString()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(buddyListViewModeProvider);
    final buddiesAsync = ref.watch(allBuddiesWithDiveCountProvider);

    // Table mode uses a dedicated scaffold with column configuration support.
    if (viewMode == ListViewMode.table) {
      return _buildTableModeScaffold(context, buddiesAsync);
    }

    final sort = ref.watch(buddySortProvider);

    // Built inside the selection listener below so rows re-render as checks
    // change; computing it here would leave the list frozen mid-selection.
    Widget buildContent() {
      return buddiesAsync.when(
        data: (buddies) {
          final sorted = applyBuddyWithDiveCountSorting(buddies, sort);
          return sorted.isEmpty
              ? _buildEmptyState(context)
              : _buildBuddyList(context, ref, sorted);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error),
      );
    }

    final loadedBuddies =
        buddiesAsync.valueOrNull ?? const <BuddyWithDiveCount>[];
    final visibleIds = loadedBuddies.map((b) => b.buddy.id).toList();

    // Drop checked buddies that fell out of the visible list, so the count
    // always matches what is on screen. pruneTo is a no-op when nothing
    // changed, which keeps this off a rebuild loop.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    if (!widget.showAppBar) {
      return SelectableListScope(
        controller: _selection,
        selectableIds: visibleIds,
        child: ValueListenableBuilder<SelectionState>(
          valueListenable: _selection,
          builder: (context, selection, _) => Column(
            children: [
              selection.isActive
                  ? _buildCompactSelectionAppBar(context, loadedBuddies)
                  : _buildCompactAppBar(context),
              Expanded(child: buildContent()),
            ],
          ),
        ),
      );
    }

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? _buildSelectionAppBar(loadedBuddies)
              : AppBar(
                  title: FeatureAppBarTitle(
                    featureId: 'buddies',
                    title: context.l10n.buddies_title,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: context.l10n.buddies_action_search,
                      onPressed: () {
                        showSearch(
                          context: context,
                          delegate: BuddySearchDelegate(ref),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.sort),
                      tooltip: context.l10n.buddies_action_sort,
                      onPressed: () => _showSortSheet(context),
                    ),
                    // The only way into bulk actions: entry by long-press was removed,
                    // so nothing but this control opens selection mode on touch.
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: context.l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: context.l10n.buddies_action_moreOptions,
                      onSelected: (value) {
                        if (value == 'import') {
                          _importFromContacts(context);
                        } else if (value.startsWith('view_')) {
                          final mode = ListViewMode.fromName(
                            value.replaceFirst('view_', ''),
                          );
                          ref.read(buddyListViewModeProvider.notifier).state =
                              mode;
                        }
                      },
                      itemBuilder: (context) {
                        final currentMode = ref.read(buddyListViewModeProvider);
                        return [
                          ...ListViewModeToggle.menuItems(
                            context,
                            currentMode: currentMode,
                            modes: const [
                              ListViewMode.detailed,
                              ListViewMode.compact,
                              ListViewMode.table,
                            ],
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'import',
                            child: ListTile(
                              leading: const Icon(Icons.contacts),
                              title: Text(
                                context.l10n.buddies_action_importFromContacts,
                              ),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
          body: buildContent(),
          floatingActionButton: selection.isActive
              ? null
              : widget.floatingActionButton,
        ),
      ),
    );
  }

  /// Build the full scaffold/layout for table mode.
  ///
  /// When embedded inside [TableModeLayout] (showAppBar: false), the outer
  /// TableModeLayout already provides the AppBar, so we only show the table
  /// content (plus selection bar when in selection mode).
  Widget _buildTableModeScaffold(
    BuildContext context,
    AsyncValue<List<BuddyWithDiveCount>> buddiesAsync,
  ) {
    final loadedBuddies =
        buddiesAsync.valueOrNull ?? const <BuddyWithDiveCount>[];
    final visibleIds = loadedBuddies.map((b) => b.buddy.id).toList();

    // Same pruning the list path does: drop checked buddies that fell out of
    // the visible list, so the count always matches what is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    // The scope carries Escape, Ctrl/Cmd-A and the Android back handling, and
    // the builder is what repaints the table as checks change -- the table is
    // built inside it for that reason.
    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) {
          final tableContent = _buildTableView(context, buddiesAsync);

          // Table mode has no app bar of its own, so the Select affordance
          // lives in the same slot the contextual bar takes, at the same
          // height -- the table does not shift as the mode opens.
          return Column(
            children: [
              if (selection.isActive)
                _buildCompactSelectionAppBar(context, loadedBuddies)
              else
                SelectionEntryBar(controller: _selection),
              Expanded(child: tableContent),
            ],
          );
        },
      ),
    );
  }

  /// Build the [EntityTableView] for buddy table mode.
  Widget _buildTableView(
    BuildContext context,
    AsyncValue<List<BuddyWithDiveCount>> buddiesAsync,
  ) {
    return buddiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => _buildErrorState(context, e),
      data: (buddies) {
        if (buddies.isEmpty) {
          return _buildEmptyState(context);
        }
        final config = ref.watch(buddyTableConfigProvider);
        final notifier = ref.read(buddyTableConfigProvider.notifier);
        final settings = ref.watch(settingsProvider);
        final units = UnitFormatter(settings);

        return EntityTableView<BuddyWithCount, BuddyField>(
          entities: buddies,
          idExtractor: (b) => b.buddy.id,
          adapter: BuddyFieldAdapter.instance,
          config: config,
          units: units,
          onSortFieldChanged: notifier.setSortField,
          onResizeColumn: notifier.resizeColumn,
          onEntityTapDown: (id) {
            // Rows carry a double-tap, so onEntityTap only resolves after the
            // double-tap timer -- long after this fires. A modified click is a
            // selection gesture, not a navigation one: moving the highlight
            // here would overwrite the very anchor the shift-click is about to
            // extend from.
            if (_isSelectionMode ||
                SelectableListScope.isShiftPressed() ||
                SelectableListScope.isModifierPressed()) {
              return;
            }
            ref.read(highlightedBuddyIdProvider.notifier).state = id;
          },
          onEntityTap: (id) {
            // Table mode honours modifier and shift clicks too, so selection
            // works the same way as in the list view modes.
            final orderedIds = buddies.map((b) => b.buddy.id).toList();
            if (SelectableListScope.isShiftPressed()) {
              _selectRangeTo(id, orderedIds);
            } else if (SelectableListScope.isModifierPressed()) {
              _modifierTap(id, orderedIds);
            } else if (_isSelectionMode) {
              _toggleSelection(id);
            }
          },
          onEntityDoubleTap: (id) {
            if (_isSelectionMode) return;
            context.push('/buddies/$id');
          },
          selectedIds: _selectedIds,
          isSelectionMode: _isSelectionMode,
          highlightedId: ref.watch(highlightedBuddyIdProvider),
        );
      },
    );
  }

  Widget _buildCompactAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Expanded, and no Spacer: the title must be the row's only flexible
          // child, or Spacer takes half the free space and the leftover half
          // lands after the last icon (see trip_list_content for the detail).
          Expanded(
            child: FeatureAppBarTitle(
              featureId: 'buddies',
              title: context.l10n.buddies_title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.buddies_action_search,
            onPressed: () {
              showSearch(context: context, delegate: BuddySearchDelegate(ref));
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.buddies_action_sort,
            onPressed: () => _showSortSheet(context),
          ),
          // The only way into bulk actions: entry by long-press was removed,
          // so nothing but this control opens selection mode on touch.
          IconButton(
            key: const ValueKey('enter_selection'),
            icon: const Icon(Icons.checklist, size: 20),
            tooltip: context.l10n.common_selection_enterTooltip,
            onPressed: _selection.enterExplicit,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: context.l10n.buddies_action_moreOptions,
            onSelected: (value) {
              if (value == 'import') {
                _importFromContacts(context);
              } else if (value.startsWith('view_')) {
                final mode = ListViewMode.fromName(
                  value.replaceFirst('view_', ''),
                );
                ref.read(buddyListViewModeProvider.notifier).state = mode;
              }
            },
            itemBuilder: (context) {
              final currentMode = ref.read(buddyListViewModeProvider);
              return [
                ...ListViewModeToggle.menuItems(
                  context,
                  currentMode: currentMode,
                  modes: const [
                    ListViewMode.detailed,
                    ListViewMode.compact,
                    ListViewMode.table,
                  ],
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: const Icon(Icons.contacts),
                    title: Text(context.l10n.buddies_action_importFromContacts),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  /// Buddy-specific extras. Select-all, deselect-all and delete are supplied
  /// by SelectionAppBar. Computed once and shared by both shells so the pane
  /// cannot drift from the full-width bar.
  List<BulkAction> _bulkActions(List<BuddyWithDiveCount> buddies) {
    return [
      BulkAction(
        id: 'merge',
        icon: Icons.merge_type,
        label: context.l10n.buddies_list_selection_mergeTooltip,
        minCount: 2,
        onInvoke: _startMerge,
      ),
    ];
  }

  /// Contextual bar for the master pane, which is too narrow for every icon.
  Widget _buildCompactSelectionAppBar(
    BuildContext context,
    List<BuddyWithDiveCount> buddies,
  ) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: buddies.map((b) => b.buddy.id).toList(),
      actions: _bulkActions(buddies),
      shell: SelectionBarShell.pane,
      maxInlineActions: 1,
      onDelete: _confirmAndDelete,
    );
  }

  /// Contextual bar for the full-width standalone layout.
  SelectionAppBar _buildSelectionAppBar(List<BuddyWithDiveCount> buddies) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: buddies.map((b) => b.buddy.id).toList(),
      actions: _bulkActions(buddies),
      shell: SelectionBarShell.appBar,
      onDelete: _confirmAndDelete,
    );
  }

  void _showSortSheet(BuildContext context) {
    final sort = ref.read(buddySortProvider);
    showSortBottomSheet<BuddySortField>(
      context: context,
      title: context.l10n.buddies_action_sortTitle,
      currentField: sort.field,
      currentDirection: sort.direction,
      fields: BuddySortField.values,
      getFieldDisplayName: (field) => field.localizedName(context.l10n),
      getFieldIcon: (field) => field.icon,
      onSortChanged: (field, direction) {
        ref.read(buddySortProvider.notifier).state = SortState(
          field: field,
          direction: direction,
        );
      },
    );
  }

  Widget _buildBuddyList(
    BuildContext context,
    WidgetRef ref,
    List<BuddyWithDiveCount> buddies,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allBuddiesWithDiveCountProvider);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: buddies.length,
        itemBuilder: (context, index) {
          final buddyWithCount = buddies[index];
          final buddy = buddyWithCount.buddy;
          final highlightedId = ref.watch(highlightedBuddyIdProvider);
          final isHighlighted = highlightedId == buddy.id;
          final isSelected = widget.selectedId == buddy.id || isHighlighted;
          final isChecked = _selectedIds.contains(buddy.id);
          final viewMode = ref.watch(buddyListViewModeProvider);
          return switch (viewMode) {
            ListViewMode.detailed => BuddyListTile(
              entry: buddyWithCount,
              isSelected: isSelected,
              isChecked: isChecked,
              isSelectionMode: _isSelectionMode,
              onTap: () => _handleRowTap(buddy.id, buddies),
            ),
            ListViewMode.compact => CompactBuddyListTile(
              entry: buddyWithCount,
              isSelectionMode: _isSelectionMode,
              isSelected: isChecked,
              isHighlighted: !_isSelectionMode && isHighlighted,
              onTap: () => _handleRowTap(buddy.id, buddies),
            ),
            ListViewMode.dense || ListViewMode.table => DenseBuddyListTile(
              buddy: buddy,
              diveCount: buddyWithCount.diveCount,
              isChecked: isChecked,
              isHighlighted: !_isSelectionMode && isHighlighted,
              isSelectionMode: _isSelectionMode,
              onTap: () => _handleRowTap(buddy.id, buddies),
            ),
          };
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.buddies_empty_title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.buddies_empty_subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              if (ResponsiveBreakpoints.isMasterDetail(context)) {
                final routerState = GoRouterState.of(context);
                context.go('${routerState.uri.path}?mode=new');
              } else {
                context.push('/buddies/new');
              }
            },
            icon: const Icon(Icons.person_add),
            label: Text(context.l10n.buddies_action_addFirst),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(context.l10n.buddies_error_loading(error.toString())),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => ref.invalidate(allBuddiesWithDiveCountProvider),
            child: Text(context.l10n.buddies_action_retry),
          ),
        ],
      ),
    );
  }
}

/// Search delegate for buddies
class BuddySearchDelegate extends SearchDelegate<Buddy?> {
  final WidgetRef ref;

  BuddySearchDelegate(this.ref);

  @override
  String get searchFieldLabel => 'Search buddies...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: context.l10n.buddies_action_clearSearch,
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: context.l10n.common_action_back,
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.buddies_search_hint,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return DebouncedSearchResults<Buddy>(
      query: query,
      watchProvider: (ref, q) => ref.watch(buddySearchProvider(q)),
      dataBuilder: (context, buddies) {
        return ListView.builder(
          itemCount: buddies.length,
          itemBuilder: (context, index) {
            final buddy = buddies[index];
            return BuddyListTile(
              entry: BuddyWithDiveCount(buddy: buddy, diveCount: 0),
              onTap: () {
                close(context, buddy);
                context.push('/buddies/${buddy.id}');
              },
            );
          },
        );
      },
      emptyBuilder: (context, query) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.buddies_search_noResults(query),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error) {
        return Center(
          child: Text('${context.l10n.common_label_error}: $error'),
        );
      },
    );
  }
}
