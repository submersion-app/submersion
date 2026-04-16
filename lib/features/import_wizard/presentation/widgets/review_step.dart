import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/entity_review_list.dart';
import 'package:submersion/core/providers/async_value_extensions.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_tags_field.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The review step of the import wizard.
///
/// Always renders a [TabBar] with one tab per entity type, each with a count
/// badge. A bottom bar shows aggregate counts and an "Import Selected" button
/// that calls [onImport].
class ReviewStep extends ConsumerWidget {
  /// Fired when the user taps "Import Selected".
  final VoidCallback onImport;

  /// Fired when the user taps "Back".
  final VoidCallback? onBack;

  const ReviewStep({super.key, required this.onImport, this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardNotifierProvider);
    final notifier = ref.read(importWizardNotifierProvider.notifier);
    final bundle = state.bundle;

    if (bundle == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final types = bundle.availableTypes;
    final availableActions = notifier.supportedDuplicateActions;
    final counts = _AggregateCounts.compute(state);

    // Compute projected dive numbers for the review list.
    final nextDiveNumber = ref.watch(nextDiveNumberProvider).whenData((v) => v);
    final projectedDiveNumbers = _computeProjectedDiveNumbers(
      bundle: bundle,
      nextDiveNumber: nextDiveNumber.value,
      retainSource: state.retainSourceDiveNumbers,
      selections: state.selections[ImportEntityType.dives] ?? const {},
      duplicateActions:
          state.duplicateActions[ImportEntityType.dives] ?? const {},
      duplicateIndices:
          bundle.groups[ImportEntityType.dives]?.duplicateIndices ?? const {},
    );

    final existingTags = ref.watch(tagsProvider).valueOrNull ?? const <Tag>[];

    return _MultiTypeLayout(
      types: types,
      bundle: bundle,
      state: state,
      notifier: notifier,
      availableActions: availableActions,
      counts: counts,
      projectedDiveNumbers: projectedDiveNumbers,
      existingTags: existingTags,
      onImport: onImport,
      onBack: onBack,
    );
  }

  /// Compute a map from item index → projected dive number.
  ///
  /// Only assigns numbers to dives that will actually be imported as new
  /// (selected non-duplicates + duplicates with "Import as New" action).
  /// Skipped and consolidated dives are excluded.
  static Map<int, int>? _computeProjectedDiveNumbers({
    required ImportBundle bundle,
    required int? nextDiveNumber,
    required bool retainSource,
    required Set<int> selections,
    required Map<int, DuplicateAction> duplicateActions,
    required Set<int> duplicateIndices,
  }) {
    final group = bundle.groups[ImportEntityType.dives];
    if (group == null || nextDiveNumber == null) return null;

    final items = group.items;

    // Determine which indices will be imported as new dives.
    final importIndices = <int>{};
    for (var i = 0; i < items.length; i++) {
      if (duplicateIndices.contains(i)) {
        // Duplicate: only include if action is importAsNew.
        if (duplicateActions[i] == DuplicateAction.importAsNew) {
          importIndices.add(i);
        }
      } else if (selections.contains(i)) {
        // Non-duplicate: include if selected.
        importIndices.add(i);
      }
    }

    // Build (index, startTime) pairs for sorting.
    final indexed = <(int, DateTime)>[];
    for (final i in importIndices) {
      final time = items[i].diveData?.startTime ?? DateTime(0);
      indexed.add((i, time));
    }
    indexed.sort((a, b) => a.$2.compareTo(b.$2));

    // Assign numbers oldest-first.
    final result = <int, int>{};
    for (var n = 0; n < indexed.length; n++) {
      final itemIndex = indexed[n].$1;
      result[itemIndex] = nextDiveNumber + n;
    }
    return result;
  }
}

// ---------------------------------------------------------------------------
// Multi-type layout (tab bar)
// ---------------------------------------------------------------------------

class _MultiTypeLayout extends StatefulWidget {
  final List<ImportEntityType> types;
  final ImportBundle bundle;
  final ImportWizardState state;
  final ImportWizardNotifier notifier;
  final Set<DuplicateAction> availableActions;
  final _AggregateCounts counts;
  final Map<int, int>? projectedDiveNumbers;
  final List<Tag> existingTags;
  final VoidCallback onImport;
  final VoidCallback? onBack;

  const _MultiTypeLayout({
    required this.types,
    required this.bundle,
    required this.state,
    required this.notifier,
    required this.availableActions,
    required this.counts,
    this.projectedDiveNumbers,
    required this.existingTags,
    required this.onImport,
    this.onBack,
  });

  @override
  State<_MultiTypeLayout> createState() => _MultiTypeLayoutState();
}

class _MultiTypeLayoutState extends State<_MultiTypeLayout> {
  void _showImportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _ImportOptionsSheet(
        notifier: widget.notifier,
        existingTags: widget.existingTags,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasDives = widget.bundle.groups.containsKey(ImportEntityType.dives);

    return DefaultTabController(
      length: widget.types.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Builder(
            builder: (context) {
              final tabController = DefaultTabController.of(context);
              return ListenableBuilder(
                listenable: tabController,
                builder: (context, _) {
                  final showOptionsButton =
                      hasDives &&
                      (widget.types.length == 1 ||
                          tabController.index ==
                              widget.types.indexOf(ImportEntityType.dives));
                  return Row(
                    children: [
                      Expanded(
                        child: TabBar(
                          labelPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.label,
                          indicatorColor: colorScheme.primary,
                          labelColor: colorScheme.primary,
                          unselectedLabelColor: colorScheme.onSurfaceVariant,
                          labelStyle: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          unselectedLabelStyle: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                          tabs: [
                            for (final type in widget.types)
                              Tab(
                                height: 36,
                                text: _tabLabel(
                                  type,
                                  widget.bundle.groups[type]!.items.length,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (showOptionsButton)
                        TextButton.icon(
                          icon: const Icon(Icons.tune, size: 18),
                          label: Text(
                            context.l10n.universalImport_label_options,
                          ),
                          onPressed: () => _showImportOptions(context),
                        ),
                    ],
                  );
                },
              );
            },
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final type in widget.types)
                  _EntityTab(
                    type: type,
                    bundle: widget.bundle,
                    state: widget.state,
                    notifier: widget.notifier,
                    availableActions: widget.availableActions,
                    projectedDiveNumbers: type == ImportEntityType.dives
                        ? widget.projectedDiveNumbers
                        : null,
                  ),
              ],
            ),
          ),
          Builder(
            builder: (ctx) => _BottomBar(
              counts: widget.counts,
              onImport: widget.onImport,
              onBack: widget.onBack,
              hasPendingReviews: widget.state.hasPendingReviews,
              totalPending: widget.state.totalPending,
              onReviewPending: () {
                final loc = widget.notifier.firstPendingLocation();
                if (loc == null) return;
                final tabIdx = widget.types.indexOf(loc.type);
                if (tabIdx < 0) return;
                DefaultTabController.maybeOf(ctx)?.animateTo(tabIdx);
              },
            ),
          ),
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
  final Map<int, int>? projectedDiveNumbers;

  const _EntityTab({
    required this.type,
    required this.bundle,
    required this.state,
    required this.notifier,
    required this.availableActions,
    this.projectedDiveNumbers,
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
        pendingIndices: state.pendingFor(type),
        onToggleSelection: (i) => notifier.toggleSelection(type, i),
        onDuplicateActionChanged: (i, a) {
          notifier.setDuplicateAction(type, i, a);
          _showActionSnackbar(
            context,
            context.l10n.universalImport_snackbar_markedAs(
              _actionLabel(context, a),
            ),
          );
        },
        onBulkAction: (action) {
          final count = state.pendingFor(type).length;
          notifier.applyBulkAction(type, action);
          _showActionSnackbar(
            context,
            context.l10n.universalImport_snackbar_bulkMarkedAs(
              count,
              _actionLabel(context, action),
            ),
          );
        },
        onSelectAll: () => notifier.selectAll(type),
        onDeselectAll: () => notifier.deselectAll(type),
        existingDiveIdForIndex: (i) => group.matchResults?[i]?.diveId ?? '',
        projectedDiveNumbers: projectedDiveNumbers,
      ),
    );
  }
}

String _actionLabel(
  BuildContext context,
  DuplicateAction action,
) => switch (action) {
  DuplicateAction.skip => context.l10n.universalImport_label_skip,
  DuplicateAction.importAsNew => context.l10n.universalImport_label_importAsNew,
  DuplicateAction.consolidate => context.l10n.universalImport_label_consolidate,
  DuplicateAction.replaceSource =>
    context.l10n.universalImport_label_replaceSource,
};

void _showActionSnackbar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1500),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

// ---------------------------------------------------------------------------
// Bottom bar
// ---------------------------------------------------------------------------

class _BottomBar extends StatelessWidget {
  final _AggregateCounts counts;
  final VoidCallback onImport;
  final VoidCallback? onBack;
  final bool hasPendingReviews;
  final int totalPending;
  final VoidCallback onReviewPending;

  const _BottomBar({
    required this.counts,
    required this.onImport,
    this.onBack,
    required this.hasPendingReviews,
    required this.totalPending,
    required this.onReviewPending,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[];
    if (counts.importing > 0) {
      parts.add('${counts.importing} new');
    }
    if (counts.consolidating > 0) {
      parts.add('${counts.consolidating} merging');
    }
    if (counts.replacing > 0) {
      parts.add('${counts.replacing} replacing');
    }
    if (counts.skipping > 0) {
      parts.add('${counts.skipping} skipped');
    }

    final countsText = parts.isEmpty ? 'Nothing selected' : parts.join(', ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasPendingReviews) ...[
              Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.universalImport_pending_gateHint(
                          totalPending,
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: onReviewPending,
                      child: Text(
                        context.l10n.universalImport_pending_reviewAction,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                if (onBack != null)
                  TextButton(onPressed: onBack, child: const Text('Back')),
                Expanded(
                  child: Text(
                    countsText,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                FilledButton(
                  onPressed:
                      (hasPendingReviews ||
                          (counts.importing +
                                  counts.consolidating +
                                  counts.replacing) ==
                              0)
                      ? null
                      : onImport,
                  child: const Text('Import Selected'),
                ),
              ],
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
  final int replacing;

  const _AggregateCounts({
    required this.importing,
    required this.consolidating,
    required this.skipping,
    required this.replacing,
  });

  /// Compute counts from [ImportWizardState].
  ///
  /// - importing: selected non-duplicate items + duplicates with
  ///   [DuplicateAction.importAsNew]
  /// - consolidating: duplicates with [DuplicateAction.consolidate]
  /// - skipping: duplicates with [DuplicateAction.skip] + non-selected
  ///   non-duplicate items
  /// - replacing: duplicates with [DuplicateAction.replaceSource]
  static _AggregateCounts compute(ImportWizardState state) {
    final bundle = state.bundle;
    if (bundle == null) {
      return const _AggregateCounts(
        importing: 0,
        consolidating: 0,
        skipping: 0,
        replacing: 0,
      );
    }

    var importing = 0;
    var consolidating = 0;
    var skipping = 0;
    var replacing = 0;

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
          case DuplicateAction.replaceSource:
            replacing++;
        }
      }
    }

    return _AggregateCounts(
      importing: importing,
      consolidating: consolidating,
      skipping: skipping,
      replacing: replacing,
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

/// Bottom sheet content for import options (retain dive numbers + tags).
///
/// Uses [StateNotifier.addListener] to reactively rebuild when the notifier's
/// state changes, avoiding the need for a [ProviderScope] in the overlay tree.
class _ImportOptionsSheet extends StatefulWidget {
  final ImportWizardNotifier notifier;
  final List<Tag> existingTags;

  const _ImportOptionsSheet({
    required this.notifier,
    required this.existingTags,
  });

  @override
  State<_ImportOptionsSheet> createState() => _ImportOptionsSheetState();
}

class _ImportOptionsSheetState extends State<_ImportOptionsSheet> {
  ImportWizardState? _currentState;
  late final Function() _removeListener;

  @override
  void initState() {
    super.initState();
    _removeListener = widget.notifier.addListener((state) {
      if (mounted) {
        setState(() => _currentState = state);
      } else {
        _currentState = state;
      }
    });
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _currentState;
    if (state == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.universalImport_title_importOptions,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: Text(context.l10n.universalImport_label_retainDiveNumbers),
            subtitle: Text(
              context.l10n.universalImport_label_retainDiveNumbersSubtitle,
            ),
            value: state.retainSourceDiveNumbers,
            onChanged: (value) =>
                widget.notifier.setRetainSourceDiveNumbers(value),
          ),
          const Divider(),
          ImportTagsField(
            tags: state.importTags,
            existingTags: widget.existingTags,
            onAdd: (tag) => widget.notifier.addImportTag(tag),
            onRemove: (index) => widget.notifier.removeImportTag(index),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
