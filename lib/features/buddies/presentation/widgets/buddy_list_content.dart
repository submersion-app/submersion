import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/buddies/presentation/widgets/dense_buddy_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';

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
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
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

    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(buddy.id);
    } else {
      context.push('/buddies/${buddy.id}');
    }
  }

  void _enterSelectionMode(String? initialId) {
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      if (initialId != null) {
        _selectedIds.add(initialId);
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<BuddyWithDiveCount> buddies) {
    setState(() {
      _selectedIds.addAll(buddies.map((b) => b.buddy.id));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedIds.clear();
    });
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

    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });

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
      if (!await FlutterContacts.requestPermission(readonly: true)) {
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

      final contact = await FlutterContacts.openExternalPick();
      if (contact == null) return;

      final fullContact = await FlutterContacts.getContact(contact.id);
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
    final sort = ref.watch(buddySortProvider);
    final buddiesAsync = ref.watch(allBuddiesWithDiveCountProvider);

    final content = buddiesAsync.when(
      data: (buddies) {
        final sorted = applyBuddyWithDiveCountSorting(buddies, sort);
        return sorted.isEmpty
            ? _buildEmptyState(context)
            : _buildBuddyList(context, ref, sorted);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );

    if (!widget.showAppBar) {
      return Column(
        children: [
          _isSelectionMode
              ? _buildCompactSelectionAppBar(
                  context,
                  buddiesAsync.valueOrNull ?? [],
                )
              : _buildCompactAppBar(context),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(buddiesAsync.valueOrNull ?? [])
          : AppBar(
              title: Text(context.l10n.buddies_title),
              actions: [
                ListViewModeToggle(
                  currentMode: ref.watch(buddyListViewModeProvider),
                  availableModes: const [
                    ListViewMode.detailed,
                    ListViewMode.dense,
                  ],
                  onModeChanged: (mode) {
                    ref.read(buddyListViewModeProvider.notifier).state = mode;
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.sort),
                  tooltip: context.l10n.buddies_action_sort,
                  onPressed: () => _showSortSheet(context),
                ),
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
                PopupMenuButton<String>(
                  tooltip: context.l10n.buddies_action_moreOptions,
                  onSelected: (value) {
                    if (value == 'import') {
                      _importFromContacts(context);
                    }
                  },
                  itemBuilder: (context) => [
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
                  ],
                ),
              ],
            ),
      body: content,
      floatingActionButton: _isSelectionMode
          ? null
          : widget.floatingActionButton,
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
          Text(
            context.l10n.buddies_title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          ListViewModeToggle(
            currentMode: ref.watch(buddyListViewModeProvider),
            availableModes: const [ListViewMode.detailed, ListViewMode.dense],
            onModeChanged: (mode) {
              ref.read(buddyListViewModeProvider.notifier).state = mode;
            },
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.buddies_action_sort,
            onPressed: () => _showSortSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.buddies_action_search,
            onPressed: () {
              showSearch(context: context, delegate: BuddySearchDelegate(ref));
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: context.l10n.buddies_action_moreOptions,
            onSelected: (value) {
              if (value == 'import') {
                _importFromContacts(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: const Icon(Icons.contacts),
                  title: Text(context.l10n.buddies_action_importFromContacts),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSelectionAppBar(
    BuildContext context,
    List<BuddyWithDiveCount> buddies,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            tooltip: context.l10n.buddies_list_selection_closeTooltip,
            onPressed: _exitSelectionMode,
          ),
          Text(
            context.l10n.buddies_list_selection_count(_selectedIds.length),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.select_all, size: 20),
            tooltip: context.l10n.buddies_list_selection_selectAllTooltip,
            onPressed: _selectedIds.length < buddies.length
                ? () => _selectAll(buddies)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.deselect, size: 20),
            tooltip: context.l10n.buddies_list_selection_deselectAllTooltip,
            onPressed: _selectedIds.isNotEmpty ? _deselectAll : null,
          ),
          IconButton(
            icon: const Icon(Icons.merge_type, size: 20),
            tooltip: context.l10n.buddies_list_selection_mergeTooltip,
            onPressed: _selectedIds.length > 1 ? _startMerge : null,
          ),
          IconButton(
            icon: Icon(
              Icons.delete,
              size: 20,
              color: Theme.of(context).colorScheme.error,
            ),
            tooltip: context.l10n.buddies_list_selection_deleteTooltip,
            onPressed: _selectedIds.isNotEmpty ? _confirmAndDelete : null,
          ),
        ],
      ),
    );
  }

  AppBar _buildSelectionAppBar(List<BuddyWithDiveCount> buddies) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: context.l10n.buddies_list_selection_closeTooltip,
        onPressed: _exitSelectionMode,
      ),
      title: Text(
        context.l10n.buddies_list_selection_count(_selectedIds.length),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.select_all),
          tooltip: context.l10n.buddies_list_selection_selectAllTooltip,
          onPressed: _selectedIds.length < buddies.length
              ? () => _selectAll(buddies)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.deselect),
          tooltip: context.l10n.buddies_list_selection_deselectAllTooltip,
          onPressed: _selectedIds.isNotEmpty ? _deselectAll : null,
        ),
        IconButton(
          icon: const Icon(Icons.merge_type),
          tooltip: context.l10n.buddies_list_selection_mergeTooltip,
          onPressed: _selectedIds.length > 1 ? _startMerge : null,
        ),
        IconButton(
          icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
          tooltip: context.l10n.buddies_list_selection_deleteTooltip,
          onPressed: _selectedIds.isNotEmpty ? _confirmAndDelete : null,
        ),
      ],
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
      getFieldDisplayName: (field) => field.displayName,
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
          final isSelected = widget.selectedId == buddy.id;
          final isChecked = _selectedIds.contains(buddy.id);
          final viewMode = ref.watch(buddyListViewModeProvider);
          return switch (viewMode) {
            ListViewMode.detailed || ListViewMode.compact => GestureDetector(
              onLongPress: _isSelectionMode
                  ? null
                  : () => _enterSelectionMode(buddy.id),
              child: BuddyListTile(
                buddy: buddy,
                diveCount: buddyWithCount.diveCount,
                isSelected: isSelected,
                isChecked: isChecked,
                isSelectionMode: _isSelectionMode,
                onTap: () => _handleItemTap(buddy),
              ),
            ),
            ListViewMode.dense => GestureDetector(
              onLongPress: _isSelectionMode
                  ? null
                  : () => _enterSelectionMode(buddy.id),
              child: DenseBuddyListTile(
                buddy: buddy,
                diveCount: buddyWithCount.diveCount,
                isSelected: isSelected,
                isChecked: isChecked,
                isSelectionMode: _isSelectionMode,
                onTap: () => _handleItemTap(buddy),
              ),
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

/// List item widget for displaying a buddy
class BuddyListTile extends StatelessWidget {
  final Buddy buddy;
  final int? diveCount;
  final bool isSelected;
  final bool isChecked;
  final bool isSelectionMode;
  final VoidCallback? onTap;

  const BuddyListTile({
    super.key,
    required this.buddy,
    this.diveCount,
    this.isSelected = false,
    this.isChecked = false,
    this.isSelectionMode = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isChecked
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: ListTile(
        onTap: onTap,
        leading: isSelectionMode
            ? SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Checkbox(
                    value: isChecked,
                    onChanged: (_) => onTap?.call(),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              )
            : CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                backgroundImage: buddy.photoPath != null
                    ? AssetImage(buddy.photoPath!)
                    : null,
                child: buddy.photoPath == null
                    ? Text(
                        buddy.initials,
                        style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
        title: Text(buddy.name),
        subtitle: _buildSubtitle(context),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (diveCount != null)
              Text(
                context.l10n.buddies_label_diveCount(diveCount!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (diveCount != null) const SizedBox(width: 8),
            ExcludeSemantics(
              child: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildSubtitle(BuildContext context) {
    final parts = <String>[];

    if (buddy.certificationLevel != null) {
      parts.add(buddy.certificationLevel!.displayName);
    }
    if (buddy.certificationAgency != null) {
      parts.add(buddy.certificationAgency!.displayName);
    }

    if (parts.isEmpty) {
      return null;
    }

    return Text(parts.join(' - '));
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
              buddy: buddy,
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
        return Center(child: Text('Error: $error'));
      },
    );
  }
}
