import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart'
    show BuddyWithDiveCount;
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/dive_roles/presentation/widgets/dive_role_selector_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Widget for selecting buddies for a dive
class BuddyPicker extends ConsumerWidget {
  final String? diveId;
  final List<BuddyWithRole> selectedBuddies;
  final ValueChanged<List<BuddyWithRole>> onChanged;

  /// The active diver's own role id (#547). The pinned Me chip renders only
  /// when [onDiverRoleChanged] is provided (bulk-edit surfaces pass null).
  final String? diverRoleId;
  final ValueChanged<String?>? onDiverRoleChanged;

  const BuddyPicker({
    super.key,
    this.diveId,
    required this.selectedBuddies,
    required this.onChanged,
    this.diverRoleId,
    this.onDiverRoleChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roles = ref.watch(allDiveRolesProvider).value ?? const <DiveRole>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.buddies_title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: () => _showBuddySelectionSheet(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.buddies_picker_add),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Pinned Me chip + selected buddies as chips
        if (onDiverRoleChanged != null || selectedBuddies.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (onDiverRoleChanged != null)
                _MeChip(
                  diverRoleId: diverRoleId,
                  onChanged: onDiverRoleChanged!,
                ),
              ...selectedBuddies.map((bwr) {
                return _BuddyChip(
                  buddyWithRole: bwr,
                  roles: roles,
                  onCreateCustomRole: (name) =>
                      _createCustomRole(context, ref, name),
                  onRemove: () {
                    final updated = selectedBuddies
                        .where((b) => b.buddy.id != bwr.buddy.id)
                        .toList();
                    onChanged(updated);
                  },
                  onRoleChanged: (role) {
                    final updated = selectedBuddies.map((b) {
                      if (b.buddy.id == bwr.buddy.id) {
                        return BuddyWithRole(buddy: b.buddy, role: role);
                      }
                      return b;
                    }).toList();
                    onChanged(updated);
                  },
                );
              }),
            ],
          ),
        if (onDiverRoleChanged != null && selectedBuddies.isEmpty)
          const SizedBox(height: 8),
        if (selectedBuddies.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline,
                  size: 32,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.buddies_picker_noneSelected,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.buddies_picker_tapToAdd,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<DiveRole?> _createCustomRole(
    BuildContext context,
    WidgetRef ref,
    String name,
  ) async {
    try {
      return await ref
          .read(diveRoleListNotifierProvider.notifier)
          .addDiveRoleByName(name);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveRoles_snackbar_errorAdding(e)),
          ),
        );
      }
      return null;
    }
  }

  void _showBuddySelectionSheet(BuildContext context, WidgetRef ref) async {
    final result = await showModalBottomSheet<List<BuddyWithRole>>(
      context: context,
      isScrollControlled: true,
      builder: (context) =>
          _BuddySelectionSheet(selectedBuddies: selectedBuddies),
    );

    // Update parent with the final list when sheet closes
    if (result != null) {
      onChanged(result);
    }
  }
}

class _BuddyChip extends StatelessWidget {
  final BuddyWithRole buddyWithRole;
  final List<DiveRole> roles;
  final VoidCallback onRemove;
  final ValueChanged<DiveRole> onRoleChanged;
  final Future<DiveRole?> Function(String name) onCreateCustomRole;

  const _BuddyChip({
    required this.buddyWithRole,
    required this.roles,
    required this.onRemove,
    required this.onRoleChanged,
    required this.onCreateCustomRole,
  });

  @override
  Widget build(BuildContext context) {
    return InputChip(
      avatar: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Text(
          buddyWithRole.buddy.initials,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
        ),
      ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(buddyWithRole.buddy.name),
          Text(
            buddyWithRole.role.localizedName(context.l10n),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onDeleted: onRemove,
      onPressed: () => _showRoleSelector(context),
    );
  }

  void _showRoleSelector(BuildContext context) async {
    final selection = await showDiveRoleSelector(
      context,
      title: context.l10n.buddies_picker_selectRole(buddyWithRole.buddy.name),
      roles: roles,
      selectedRoleId: buddyWithRole.role.id,
      onCreateCustomRole: onCreateCustomRole,
    );
    if (selection?.role != null) {
      onRoleChanged(selection!.role!);
    }
  }
}

/// Pinned chip for the active diver's own role on the dive (#547).
class _MeChip extends ConsumerWidget {
  final String? diverRoleId;
  final ValueChanged<String?> onChanged;

  const _MeChip({required this.diverRoleId, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diver = ref.watch(currentDiverProvider).value;
    final rolesById =
        ref.watch(diveRoleMapProvider).value ?? const <String, DiveRole>{};
    final role = diverRoleId == null ? null : rolesById[diverRoleId!];
    final roleLabel = diverRoleId == null
        ? context.l10n.buddies_picker_setMyRole
        : (role ?? DiveRole.synthetic(diverRoleId!)).localizedName(
            context.l10n,
          );
    return InputChip(
      avatar: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          Icons.person,
          size: 14,
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(diver?.name ?? context.l10n.buddies_picker_me),
          Text(
            roleLabel,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      onPressed: () async {
        final roles =
            ref.read(allDiveRolesProvider).value ?? const <DiveRole>[];
        final selection = await showDiveRoleSelector(
          context,
          title: context.l10n.buddies_picker_selectMyRole,
          roles: roles,
          allowNone: true,
          selectedRoleId: diverRoleId,
        );
        if (selection != null) {
          onChanged(selection.role?.id);
        }
      },
    );
  }
}

class _BuddySelectionSheet extends ConsumerStatefulWidget {
  final List<BuddyWithRole> selectedBuddies;

  const _BuddySelectionSheet({required this.selectedBuddies});

  @override
  ConsumerState<_BuddySelectionSheet> createState() =>
      _BuddySelectionSheetState();
}

class _BuddySelectionSheetState extends ConsumerState<_BuddySelectionSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _debouncedQuery = '';
  Timer? _debounceTimer;
  List<BuddyWithDiveCount>? _lastSearchResults;
  late List<BuddyWithRole> _localSelectedBuddies;
  Map<String, List<Certification>> _certsByBuddy =
      const <String, List<Certification>>{};

  @override
  void initState() {
    super.initState();
    _localSelectedBuddies = List.from(widget.selectedBuddies);
    // A manual listener rather than `ref.watch(allBuddyCertificationsProvider)`
    // in build(): this widget also watches allBuddiesProvider directly for
    // the buddy list, and allBuddyCertificationsProvider transitively
    // watches allBuddiesProvider too. Riverpod's TickerMode-driven
    // auto-pause (which pauses `ref.watch` subscriptions while this sheet
    // is covered by another route, e.g. pushing the new-buddy page) trips a
    // pausedActiveSubscriptionCount assertion on resume for that diamond
    // dependency. Manual listeners are exempt from auto-pause, sidestepping
    // the bug while staying reactive via setState.
    ref.listenManual(allBuddyCertificationsProvider, (previous, next) {
      final value = next.value ?? const <String, List<Certification>>{};
      if (mounted) setState(() => _certsByBuddy = value);
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final buddiesAsync = _debouncedQuery.isEmpty
        ? ref.watch(allBuddiesWithDiveCountProvider)
        : ref.watch(buddySearchWithDiveCountProvider(_debouncedQuery));
    final sort = ref.watch(buddyPickerSortProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.l10n.buddies_picker_selectBuddies,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context, _localSelectedBuddies),
                    child: Text(context.l10n.buddies_picker_done),
                  ),
                ],
              ),
            ),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.l10n.buddies_picker_searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          tooltip: context.l10n.buddies_action_clearSearch,
                          onPressed: () {
                            _searchController.clear();
                            _debounceTimer?.cancel();
                            setState(() {
                              _searchQuery = '';
                              _debouncedQuery = '';
                              _lastSearchResults = null;
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _debounceTimer?.cancel();
                  if (value.isEmpty) {
                    setState(() {
                      _debouncedQuery = '';
                      _lastSearchResults = null;
                    });
                  } else {
                    _debounceTimer = Timer(
                      const Duration(milliseconds: 300),
                      () {
                        if (mounted) {
                          setState(() => _debouncedQuery = value);
                        }
                      },
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 8),

            // Add new buddy button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Push to create new buddy and wait for result
                  final result = await context.push<Buddy>('/buddies/new');
                  if (result != null) {
                    // New buddy was created, refresh the list so they can select it
                    ref.invalidate(allBuddiesProvider);
                    ref.invalidate(allBuddiesWithDiveCountProvider);
                  }
                },
                icon: const Icon(Icons.person_add),
                label: Text(context.l10n.buddies_picker_addNew),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Sort toggle (issue #638): alternates between dive-count-desc
            // (the default -- who do I dive with most) and alphabetical.
            // Favorites are pinned to the top regardless of this choice.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    final next = sort.field == BuddySortField.diveCount
                        // Text fields invert direction throughout this
                        // codebase: descending is what renders A->Z. Ascending
                        // here would flip the alphabetical toggle to Z->A.
                        ? const SortState(
                            field: BuddySortField.name,
                            direction: SortDirection.descending,
                          )
                        : const SortState(
                            field: BuddySortField.diveCount,
                            direction: SortDirection.descending,
                          );
                    ref.read(buddyPickerSortProvider.notifier).state = next;
                  },
                  icon: Icon(sort.field.icon, size: 18),
                  label: Text(
                    '${context.l10n.buddies_action_sort}: '
                    '${sort.field.localizedName(context.l10n)}',
                  ),
                ),
              ),
            ),
            const Divider(height: 1),

            // Buddy list
            Expanded(
              child: buddiesAsync.when(
                data: (buddies) {
                  if (_debouncedQuery.isNotEmpty) {
                    _lastSearchResults = buddies;
                  }
                  if (buddies.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.people_outline
                                : Icons.search_off,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? context.l10n.buddies_picker_noBuddiesYet
                                : context.l10n.buddies_picker_noBuddiesFound,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  }

                  return _buildBuddyListView(
                    scrollController,
                    buddies,
                    _certsByBuddy,
                    sort,
                  );
                },
                loading: () {
                  if (_lastSearchResults != null &&
                      _lastSearchResults!.isNotEmpty) {
                    return Column(
                      children: [
                        const LinearProgressIndicator(),
                        Expanded(
                          child: _buildBuddyListView(
                            scrollController,
                            _lastSearchResults!,
                            _certsByBuddy,
                            sort,
                          ),
                        ),
                      ],
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                },
                error: (error, _) => Center(
                  child: Text('${context.l10n.common_label_error}: $error'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBuddyListView(
    ScrollController scrollController,
    List<BuddyWithDiveCount> buddies,
    Map<String, List<Certification>> certsByBuddy,
    SortState<BuddySortField> sort,
  ) {
    // Favorites are pinned to the top regardless of the chosen sort field
    // (issue #638); each partition is sorted independently so the toggle
    // still reorders within both groups.
    final favorites = applyBuddyWithDiveCountSorting(
      buddies.where((b) => b.buddy.isFavorite).toList(),
      sort,
    );
    final others = applyBuddyWithDiveCountSorting(
      buddies.where((b) => !b.buddy.isFavorite).toList(),
      sort,
    );

    final rows = <_PickerRow>[
      if (favorites.isNotEmpty)
        _PickerRow.header(context.l10n.diveLog_filterChip_favorites),
      ...favorites.map(_PickerRow.entry),
      if (favorites.isNotEmpty && others.isNotEmpty) const _PickerRow.divider(),
      ...others.map(_PickerRow.entry),
    ];

    return ListView.builder(
      controller: scrollController,
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.isDivider) return const Divider(height: 1);
        if (row.header != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              row.header!,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        }

        final buddy = row.entry!.buddy;
        final diveCount = row.entry!.diveCount;
        final isSelected = _localSelectedBuddies.any(
          (b) => b.buddy.id == buddy.id,
        );
        final selectedRole = _localSelectedBuddies
            .where((b) => b.buddy.id == buddy.id)
            .map((b) => b.role)
            .firstOrNull;

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: isSelected
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )
                : Text(
                    buddy.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
          ),
          title: Text(buddy.name),
          subtitle: buddy.certificationLevel == null
              ? null
              : Text(buddy.certificationLevel!.displayName),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (diveCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    context.l10n.buddies_label_diveCount(diveCount),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(
                  buddy.isFavorite ? Icons.star : Icons.star_border,
                  size: 20,
                  color: buddy.isFavorite
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                tooltip: buddy.isFavorite
                    ? context.l10n.diveLog_detail_tooltip_removeFromFavorites
                    : context.l10n.diveLog_detail_tooltip_addToFavorites,
                visualDensity: VisualDensity.compact,
                onPressed: () => ref
                    .read(buddyListNotifierProvider.notifier)
                    .toggleFavorite(buddy.id),
              ),
              if (isSelected)
                Chip(
                  label: Text(
                    selectedRole?.localizedName(context.l10n) ??
                        context.l10n.diveRole_builtin_buddy,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          onTap: () {
            if (isSelected) {
              _removeBuddy(buddy.id);
            } else {
              _showRoleSelectorForBuddy(
                context,
                buddy,
                certsByBuddy[buddy.id] ?? const [],
              );
            }
          },
        );
      },
    );
  }

  void _removeBuddy(String buddyId) {
    setState(() {
      _localSelectedBuddies = _localSelectedBuddies
          .where((b) => b.buddy.id != buddyId)
          .toList();
    });
  }

  void _addBuddy(Buddy buddy, DiveRole role) {
    final existing = _localSelectedBuddies.indexWhere(
      (b) => b.buddy.id == buddy.id,
    );
    setState(() {
      if (existing >= 0) {
        // Update role
        _localSelectedBuddies = [
          ..._localSelectedBuddies.sublist(0, existing),
          BuddyWithRole(buddy: buddy, role: role),
          ..._localSelectedBuddies.sublist(existing + 1),
        ];
      } else {
        _localSelectedBuddies = [
          ..._localSelectedBuddies,
          BuddyWithRole(buddy: buddy, role: role),
        ];
      }
    });
  }

  void _showRoleSelectorForBuddy(
    BuildContext context,
    Buddy buddy,
    List<Certification> certs,
  ) async {
    final roles = ref.read(allDiveRolesProvider).value ?? const <DiveRole>[];
    final selection = await showDiveRoleSelector(
      context,
      title: context.l10n.buddies_picker_selectRole(buddy.name),
      roles: roles,
      credentialRoleIds: _professionalRoleIds(certs),
      onCreateCustomRole: _createCustomRole,
    );
    if (selection?.role != null) {
      _addBuddy(buddy, selection!.role!);
    }
  }

  /// Dive-role ids this buddy plausibly acts as professionally, derived from
  /// their certification levels; floats those roles to the top of the sheet
  /// and badges them (replaces the buddy_roles credential lookup).
  Set<String> _professionalRoleIds(List<Certification> certs) {
    final ids = <String>{};
    for (final cert in certs) {
      final level = cert.level;
      if (level == null) continue;
      if (level.isInstructorLevel) ids.add(DiveRole.instructorId);
      if (level == CertificationLevel.diveMaster) {
        ids.add(DiveRole.diveMasterId);
      }
      if (level == CertificationLevel.diveGuide) {
        ids.add(DiveRole.diveGuideId);
      }
    }
    return ids;
  }

  Future<DiveRole?> _createCustomRole(String name) async {
    try {
      return await ref
          .read(diveRoleListNotifierProvider.notifier)
          .addDiveRoleByName(name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveRoles_snackbar_errorAdding(e)),
          ),
        );
      }
      return null;
    }
  }
}

/// A single row in the Add-buddy list: a section header, a divider between
/// the favorites section and the rest, or a buddy entry.
class _PickerRow {
  final String? header;
  final bool isDivider;
  final BuddyWithDiveCount? entry;

  const _PickerRow.header(this.header) : isDivider = false, entry = null;

  const _PickerRow.divider() : header = null, isDivider = true, entry = null;

  const _PickerRow.entry(BuddyWithDiveCount value)
    : header = null,
      isDivider = false,
      entry = value;
}
