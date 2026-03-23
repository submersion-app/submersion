import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';

/// The review step of the import wizard.
///
/// When the bundle contains a single entity type, renders an [EntityReviewList]
/// directly without a tab bar. When multiple types are present, a [TabBar] is
/// shown with one tab per type, each with a count badge.
///
/// A bottom bar is always shown with aggregate counts and an "Import Selected"
/// button that calls [onImport].
class ReviewStep extends ConsumerWidget {
  /// Fired when the user taps "Import Selected".
  final VoidCallback onImport;

  const ReviewStep({super.key, required this.onImport});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardProvider);
    final notifier = ref.read(importWizardProvider.notifier);
    final bundle = state.bundle;

    if (bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final types = bundle.availableTypes;
    final availableActions = notifier.supportedDuplicateActions;

    final counts = _AggregateCounts.compute(state);

    if (types.length == 1) {
      return _SingleTypeLayout(
        type: types.first,
        bundle: bundle,
        state: state,
        notifier: notifier,
        availableActions: availableActions,
        counts: counts,
        onImport: onImport,
      );
    }

    return _MultiTypeLayout(
      types: types,
      bundle: bundle,
      state: state,
      notifier: notifier,
      availableActions: availableActions,
      counts: counts,
      onImport: onImport,
    );
  }
}

// ---------------------------------------------------------------------------
// Single-type layout (no tab bar)
// ---------------------------------------------------------------------------

class _SingleTypeLayout extends StatelessWidget {
  final ImportEntityType type;
  final ImportBundle bundle;
  final ImportWizardState state;
  final ImportWizardNotifier notifier;
  final Set<DuplicateAction> availableActions;
  final _AggregateCounts counts;
  final VoidCallback onImport;

  const _SingleTypeLayout({
    required this.type,
    required this.bundle,
    required this.state,
    required this.notifier,
    required this.availableActions,
    required this.counts,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final group = bundle.groups[type]!;
    final selectedIndices = state.selections[type] ?? const <int>{};
    final duplicateActions = state.duplicateActions[type] ?? const {};

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: EntityReviewList(
              group: group,
              selectedIndices: selectedIndices,
              duplicateActions: duplicateActions,
              availableActions: availableActions,
              onToggleSelection: (i) => notifier.toggleSelection(type, i),
              onDuplicateActionChanged: (i, a) =>
                  notifier.setDuplicateAction(type, i, a),
              onSelectAll: () => notifier.selectAll(type),
              onDeselectAll: () => notifier.deselectAll(type),
              existingDiveIdForIndex: (i) =>
                  group.matchResults?[i]?.diveId ?? '',
            ),
          ),
        ),
        _BottomBar(counts: counts, onImport: onImport),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Multi-type layout (tab bar)
// ---------------------------------------------------------------------------

class _MultiTypeLayout extends StatelessWidget {
  final List<ImportEntityType> types;
  final ImportBundle bundle;
  final ImportWizardState state;
  final ImportWizardNotifier notifier;
  final Set<DuplicateAction> availableActions;
  final _AggregateCounts counts;
  final VoidCallback onImport;

  const _MultiTypeLayout({
    required this.types,
    required this.bundle,
    required this.state,
    required this.notifier,
    required this.availableActions,
    required this.counts,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: types.length,
      child: Column(
        children: [
          TabBar(
            tabs: [
              for (final type in types)
                Tab(text: _tabLabel(type, bundle.groups[type]!.items.length)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final type in types)
                  _EntityTab(
                    type: type,
                    bundle: bundle,
                    state: state,
                    notifier: notifier,
                    availableActions: availableActions,
                  ),
              ],
            ),
          ),
          _BottomBar(counts: counts, onImport: onImport),
        ],
      ),
    );
  }

  String _tabLabel(ImportEntityType type, int count) {
    return '${_typeDisplayName(type)} ($count)';
  }

  String _typeDisplayName(ImportEntityType type) {
    switch (type) {
      case ImportEntityType.dives:
        return 'Dives';
      case ImportEntityType.sites:
        return 'Sites';
      case ImportEntityType.buddies:
        return 'Buddies';
      case ImportEntityType.equipment:
        return 'Equipment';
      case ImportEntityType.trips:
        return 'Trips';
      case ImportEntityType.certifications:
        return 'Certifications';
      case ImportEntityType.diveCenters:
        return 'Dive Centers';
      case ImportEntityType.tags:
        return 'Tags';
      case ImportEntityType.diveTypes:
        return 'Dive Types';
      case ImportEntityType.equipmentSets:
        return 'Equipment Sets';
      case ImportEntityType.courses:
        return 'Courses';
    }
  }
}

// ---------------------------------------------------------------------------
// Single tab content (used by multi-type layout)
// ---------------------------------------------------------------------------

class _EntityTab extends StatelessWidget {
  final ImportEntityType type;
  final ImportBundle bundle;
  final ImportWizardState state;
  final ImportWizardNotifier notifier;
  final Set<DuplicateAction> availableActions;

  const _EntityTab({
    required this.type,
    required this.bundle,
    required this.state,
    required this.notifier,
    required this.availableActions,
  });

  @override
  Widget build(BuildContext context) {
    final group = bundle.groups[type]!;
    final selectedIndices = state.selections[type] ?? const <int>{};
    final duplicateActions = state.duplicateActions[type] ?? const {};

    return SingleChildScrollView(
      child: EntityReviewList(
        group: group,
        selectedIndices: selectedIndices,
        duplicateActions: duplicateActions,
        availableActions: availableActions,
        onToggleSelection: (i) => notifier.toggleSelection(type, i),
        onDuplicateActionChanged: (i, a) =>
            notifier.setDuplicateAction(type, i, a),
        onSelectAll: () => notifier.selectAll(type),
        onDeselectAll: () => notifier.deselectAll(type),
        existingDiveIdForIndex: (i) => group.matchResults?[i]?.diveId ?? '',
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  final _AggregateCounts counts;
  final VoidCallback onImport;

  const _BottomBar({required this.counts, required this.onImport});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (counts.importing > 0) {
      parts.add('${counts.importing} importing');
    }
    if (counts.consolidating > 0) {
      parts.add('${counts.consolidating} consolidating');
    }
    if (counts.skipping > 0) {
      parts.add('${counts.skipping} skipping');
    }

    final countsText = parts.isEmpty ? 'Nothing selected' : parts.join(', ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                countsText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton(
              onPressed: onImport,
              child: const Text('Import Selected'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aggregate counts
// ---------------------------------------------------------------------------

/// Computed aggregate counts for the bottom bar summary text.
class _AggregateCounts {
  final int importing;
  final int consolidating;
  final int skipping;

  const _AggregateCounts({
    required this.importing,
    required this.consolidating,
    required this.skipping,
  });

  /// Compute counts from [ImportWizardState].
  ///
  /// - importing: selected non-duplicate items + duplicates with
  ///   [DuplicateAction.importAsNew]
  /// - consolidating: duplicates with [DuplicateAction.consolidate]
  /// - skipping: duplicates with [DuplicateAction.skip] + non-selected
  ///   non-duplicate items
  static _AggregateCounts compute(ImportWizardState state) {
    final bundle = state.bundle;
    if (bundle == null) {
      return const _AggregateCounts(
        importing: 0,
        consolidating: 0,
        skipping: 0,
      );
    }

    var importing = 0;
    var consolidating = 0;
    var skipping = 0;

    for (final entry in bundle.groups.entries) {
      final type = entry.key;
      final group = entry.value;
      final selectedIndices = state.selections[type] ?? const <int>{};
      final duplicateActions =
          state.duplicateActions[type] ?? const <int, DuplicateAction>{};

      // Non-duplicate items
      for (int i = 0; i < group.items.length; i++) {
        if (!group.duplicateIndices.contains(i)) {
          if (selectedIndices.contains(i)) {
            importing++;
          } else {
            skipping++;
          }
        }
      }

      // Duplicate items
      for (final dupIndex in group.duplicateIndices) {
        final action =
            duplicateActions[dupIndex] ?? _defaultAction(group, dupIndex);
        switch (action) {
          case DuplicateAction.importAsNew:
            importing++;
          case DuplicateAction.consolidate:
            consolidating++;
          case DuplicateAction.skip:
            skipping++;
        }
      }
    }

    return _AggregateCounts(
      importing: importing,
      consolidating: consolidating,
      skipping: skipping,
    );
  }

  static DuplicateAction _defaultAction(EntityGroup group, int index) {
    final result = group.matchResults?[index];
    if (result == null) return DuplicateAction.skip;
    return result.isProbable
        ? DuplicateAction.skip
        : DuplicateAction.importAsNew;
  }
}
