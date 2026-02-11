import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart' as enums;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/features/dive_import/presentation/providers/uddf_import_providers.dart';
import 'package:submersion/features/dive_import/presentation/widgets/uddf_entity_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Import wizard for UDDF files.
///
/// Four-step process:
/// 0. Pick UDDF file - Select and parse file
/// 1. Review & Select - Choose which entities to import, see duplicates
/// 2. Importing - Progress indicator during import
/// 3. Summary - Show import results with counts
class UddfImportPage extends ConsumerWidget {
  const UddfImportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(uddfImportNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diveImport_uddf_title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: context.l10n.diveImport_uddf_closeTooltip,
          onPressed: () {
            ref.read(uddfImportNotifierProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: Column(
        children: [
          _StepIndicator(currentStep: state.currentStep),
          Expanded(
            child: switch (state.currentStep) {
              0 => _StepFileSelection(state: state),
              1 => _StepReviewSelect(state: state),
              2 => _StepImporting(state: state),
              3 => _StepSummary(state: state),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Step indicator
// =============================================================================

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= currentStep
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
            _StepDot(
              step: i + 1,
              label: [
                context.l10n.diveImport_step_select,
                context.l10n.diveImport_step_review,
                context.l10n.diveImport_uddf_stepImport,
                context.l10n.diveImport_step_done,
              ][i],
              isActive: i == currentStep,
              isCompleted: i < currentStep,
            ),
          ],
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.step,
    required this.label,
    required this.isActive,
    required this.isCompleted,
  });

  final int step;
  final String label;
  final bool isActive;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive || isCompleted
                ? colorScheme.primary
                : colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: isActive || isCompleted
                  ? colorScheme.primary
                  : colorScheme.outline,
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? Icon(Icons.check, size: 18, color: colorScheme.onPrimary)
                : Text(
                    step.toString(),
                    style: TextStyle(
                      color: isActive
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Step 0: File selection
// =============================================================================

class _StepFileSelection extends ConsumerWidget {
  const _StepFileSelection({required this.state});

  final UddfImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open),
              label: Text(
                state.isLoading
                    ? context.l10n.diveImport_uddf_parsing
                    : context.l10n.diveImport_uddf_selectFile,
              ),
              onPressed: state.isLoading
                  ? null
                  : () => ref
                        .read(uddfImportNotifierProvider.notifier)
                        .pickAndParseFile(),
            ),
          ),
          if (state.error != null) ...[
            const SizedBox(height: 16),
            _ErrorCard(message: state.error!),
          ],
          const Spacer(),
          ExcludeSemantics(
            child: Icon(
              Icons.file_open,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.diveImport_uddf_noFileSelected,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.diveImport_uddf_noFileDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

// =============================================================================
// Step 1: Review & select entities
// =============================================================================

class _StepReviewSelect extends ConsumerWidget {
  const _StepReviewSelect({required this.state});

  final UddfImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = state.parsedData;
    if (data == null) return const SizedBox.shrink();

    // Build tab entries for entity types that have data
    final tabs = <_EntityTab>[];
    for (final type in UddfEntityType.values) {
      final count = state.totalCountFor(type);
      if (count > 0) {
        tabs.add(_EntityTab(type: type, count: count));
      }
    }

    if (tabs.isEmpty) return const SizedBox.shrink();

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          // Duplicate summary
          if (state.duplicateCheckResult?.hasDuplicates == true)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                color: theme.colorScheme.tertiaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.l10n.diveImport_uddf_duplicatesFound(
                            state.duplicateCheckResult!.totalDuplicates,
                          ),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Tabs
          TabBar(
            isScrollable: tabs.length > 4,
            tabs: tabs
                .map((t) => Tab(text: '${t.label(context)} (${t.count})'))
                .toList(),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              children: tabs.map((tab) {
                return _EntityList(type: tab.type, state: state);
              }).toList(),
            ),
          ),
          // Bottom bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    context.l10n.diveImport_selectedCount(state.totalSelected),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: state.totalSelected > 0
                        ? () => ref
                              .read(uddfImportNotifierProvider.notifier)
                              .performImport()
                        : null,
                    child: Text(context.l10n.diveImport_import),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// List of entities for a single entity type tab.
class _EntityList extends ConsumerWidget {
  const _EntityList({required this.type, required this.state});

  final UddfEntityType type;
  final UddfImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = state.parsedData;
    if (data == null) return const SizedBox.shrink();

    final items = _getItems(data);
    final selection = state.selectionFor(type);
    final duplicates = _getDuplicateIndices();

    return Column(
      children: [
        // Select/Deselect all
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                context.l10n.diveImport_uddf_selectedOfTotal(
                  selection.length,
                  items.length,
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: selection.length == items.length
                    ? () => ref
                          .read(uddfImportNotifierProvider.notifier)
                          .deselectAll(type)
                    : () => ref
                          .read(uddfImportNotifierProvider.notifier)
                          .selectAll(type),
                child: Text(
                  selection.length == items.length
                      ? context.l10n.diveImport_deselectAll
                      : context.l10n.diveImport_selectAll,
                ),
              ),
            ],
          ),
        ),
        // Item list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final isSelected = selection.contains(index);
              final isDuplicate = duplicates.contains(index);

              if (type == UddfEntityType.dives) {
                return _buildDiveCard(
                  context,
                  ref,
                  item,
                  index,
                  isSelected,
                  isDuplicate,
                );
              }

              return UddfEntityCard(
                name: _getName(item),
                subtitle: _getSubtitle(item),
                icon: _getIcon(),
                isSelected: isSelected,
                onToggle: () => ref
                    .read(uddfImportNotifierProvider.notifier)
                    .toggleSelection(type, index),
                isDuplicate: isDuplicate,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDiveCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
    int index,
    bool isSelected,
    bool isDuplicate,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateTime = item['dateTime'] as DateTime?;
    final maxDepth = item['maxDepth'] as double?;
    final duration = item['duration'] as int?;
    final siteName = item['siteName'] as String?;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(alpha: 0.3)
          : null,
      child: Semantics(
        button: true,
        label: context.l10n.diveImport_uddf_toggleDiveSelection,
        child: InkWell(
          onTap: () => ref
              .read(uddfImportNotifierProvider.notifier)
              .toggleSelection(type, index),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildCheckbox(colorScheme, isSelected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dateTime != null)
                        Text(
                          '${DateFormat.yMMMd().format(dateTime)} '
                          '${DateFormat.jm().format(dateTime)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (siteName != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          siteName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        children: [
                          if (maxDepth != null)
                            _diveMetric(
                              Icons.arrow_downward,
                              '${maxDepth.toStringAsFixed(1)}m',
                              theme,
                            ),
                          if (duration != null)
                            _diveMetric(
                              Icons.timer_outlined,
                              _formatDuration(duration),
                              theme,
                            ),
                        ],
                      ),
                      if (isDuplicate) ...[
                        const SizedBox(height: 8),
                        _buildDiveDuplicateBadge(context, colorScheme),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(ColorScheme colorScheme, bool isSelected) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isSelected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
        color: isSelected ? colorScheme.primary : Colors.transparent,
      ),
      child: isSelected
          ? Icon(Icons.check, size: 16, color: colorScheme.onPrimary)
          : null,
    );
  }

  Widget _diveMetric(IconData icon, String value, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildDiveDuplicateBadge(
    BuildContext context,
    ColorScheme colorScheme,
  ) {
    final dupResult = state.duplicateCheckResult;
    final matchInfo = dupResult?.diveMatches;
    // Find this dive's index in the diveMatches map
    final score = matchInfo?.values.firstOrNull?.score;
    final label = score != null && score >= 0.7
        ? context.l10n.diveImport_uddf_likelyDuplicate
        : context.l10n.diveImport_uddf_possibleDuplicate;
    final badgeColor = score != null && score >= 0.7
        ? colorScheme.error
        : colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 14, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: badgeColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m';
    }
    return '${minutes}m';
  }

  List<Map<String, dynamic>> _getItems(UddfImportResult data) {
    return switch (type) {
      UddfEntityType.trips => data.trips,
      UddfEntityType.equipment => data.equipment,
      UddfEntityType.buddies => data.buddies,
      UddfEntityType.diveCenters => data.diveCenters,
      UddfEntityType.certifications => data.certifications,
      UddfEntityType.courses => data.courses,
      UddfEntityType.tags => data.tags,
      UddfEntityType.diveTypes => data.customDiveTypes,
      UddfEntityType.sites => data.sites,
      UddfEntityType.equipmentSets => data.equipmentSets,
      UddfEntityType.dives => data.dives,
    };
  }

  Set<int> _getDuplicateIndices() {
    final dup = state.duplicateCheckResult;
    if (dup == null) return const {};
    return switch (type) {
      UddfEntityType.trips => dup.duplicateTrips,
      UddfEntityType.sites => dup.duplicateSites,
      UddfEntityType.equipment => dup.duplicateEquipment,
      UddfEntityType.buddies => dup.duplicateBuddies,
      UddfEntityType.diveCenters => dup.duplicateDiveCenters,
      UddfEntityType.certifications => dup.duplicateCertifications,
      UddfEntityType.courses => const {},
      UddfEntityType.tags => dup.duplicateTags,
      UddfEntityType.diveTypes => dup.duplicateDiveTypes,
      UddfEntityType.equipmentSets => const {},
      UddfEntityType.dives => Set<int>.from(dup.diveMatches.keys),
    };
  }

  String _getName(Map<String, dynamic> item) {
    return (item['name'] as String?) ?? 'Unnamed';
  }

  String? _getSubtitle(Map<String, dynamic> item) {
    return switch (type) {
      UddfEntityType.sites => _formatLocation(
        item['latitude'] as double?,
        item['longitude'] as double?,
      ),
      UddfEntityType.equipment =>
        (item['type'] as enums.EquipmentType?)?.displayName,
      UddfEntityType.certifications =>
        (item['agency'] as enums.CertificationAgency?)?.displayName,
      UddfEntityType.courses => item['agency'] as String?,
      UddfEntityType.diveCenters =>
        item['country'] as String? ?? item['city'] as String?,
      _ => null,
    };
  }

  String? _formatLocation(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    return '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}';
  }

  IconData _getIcon() {
    return switch (type) {
      UddfEntityType.trips => Icons.card_travel,
      UddfEntityType.equipment => Icons.build_outlined,
      UddfEntityType.buddies => Icons.person_outline,
      UddfEntityType.diveCenters => Icons.store_outlined,
      UddfEntityType.certifications => Icons.workspace_premium_outlined,
      UddfEntityType.courses => Icons.school_outlined,
      UddfEntityType.tags => Icons.label_outline,
      UddfEntityType.diveTypes => Icons.category_outlined,
      UddfEntityType.sites => Icons.location_on_outlined,
      UddfEntityType.equipmentSets => Icons.inventory_2_outlined,
      UddfEntityType.dives => Icons.scuba_diving,
    };
  }
}

// =============================================================================
// Step 2: Importing
// =============================================================================

class _StepImporting extends StatelessWidget {
  const _StepImporting({required this.state});

  final UddfImportState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = state.importTotal > 0
        ? state.importCurrent / state.importTotal
        : null;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(strokeWidth: 4),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.diveImport_uddf_importing,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (state.importPhase.isNotEmpty)
            Text(
              state.importPhase,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 16),
          if (progress != null)
            LinearProgressIndicator(value: progress)
          else
            const LinearProgressIndicator(),
          if (state.importTotal > 0) ...[
            const SizedBox(height: 8),
            Text(
              context.l10n.diveImport_uddf_importProgress(
                state.importCurrent,
                state.importTotal,
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 24),
            _ErrorCard(message: state.error!),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Step 3: Summary
// =============================================================================

class _StepSummary extends ConsumerWidget {
  const _StepSummary({required this.state});

  final UddfImportState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final result = state.importResult;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              Icons.check_circle,
              size: 80,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            context.l10n.diveImport_importComplete,
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          if (result != null) ...[
            if (result.dives > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_dives,
                value: result.dives.toString(),
                icon: Icons.scuba_diving,
                color: theme.colorScheme.primary,
              ),
            if (result.sites > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_sites,
                value: result.sites.toString(),
                icon: Icons.location_on_outlined,
                color: theme.colorScheme.primary,
              ),
            if (result.trips > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_trips,
                value: result.trips.toString(),
                icon: Icons.card_travel,
                color: theme.colorScheme.primary,
              ),
            if (result.equipment > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_equipment,
                value: result.equipment.toString(),
                icon: Icons.build_outlined,
                color: theme.colorScheme.primary,
              ),
            if (result.buddies > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_buddies,
                value: result.buddies.toString(),
                icon: Icons.person_outline,
                color: theme.colorScheme.primary,
              ),
            if (result.diveCenters > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_diveCenters,
                value: result.diveCenters.toString(),
                icon: Icons.store_outlined,
                color: theme.colorScheme.primary,
              ),
            if (result.certifications > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_certifications,
                value: result.certifications.toString(),
                icon: Icons.workspace_premium_outlined,
                color: theme.colorScheme.primary,
              ),
            if (result.tags > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_tags,
                value: result.tags.toString(),
                icon: Icons.label_outline,
                color: theme.colorScheme.primary,
              ),
            if (result.diveTypes > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_diveTypes,
                value: result.diveTypes.toString(),
                icon: Icons.category_outlined,
                color: theme.colorScheme.primary,
              ),
            if (result.equipmentSets > 0)
              _SummaryRow(
                label: context.l10n.diveImport_uddf_equipmentSets,
                value: result.equipmentSets.toString(),
                icon: Icons.inventory_2_outlined,
                color: theme.colorScheme.primary,
              ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              ref.read(uddfImportNotifierProvider.notifier).reset();
              context.pop();
            },
            child: Text(context.l10n.diveImport_done),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared widgets
// =============================================================================

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab metadata for entity type tabs.
class _EntityTab {
  final UddfEntityType type;
  final int count;

  const _EntityTab({required this.type, required this.count});

  String label(BuildContext context) => switch (type) {
    UddfEntityType.trips => context.l10n.diveImport_uddf_tabTrips,
    UddfEntityType.equipment => context.l10n.diveImport_uddf_tabEquipment,
    UddfEntityType.buddies => context.l10n.diveImport_uddf_tabBuddies,
    UddfEntityType.diveCenters => context.l10n.diveImport_uddf_tabCenters,
    UddfEntityType.certifications => context.l10n.diveImport_uddf_tabCerts,
    UddfEntityType.courses => context.l10n.diveImport_uddf_tabCourses,
    UddfEntityType.tags => context.l10n.diveImport_uddf_tabTags,
    UddfEntityType.diveTypes => context.l10n.diveImport_uddf_tabTypes,
    UddfEntityType.sites => context.l10n.diveImport_uddf_tabSites,
    UddfEntityType.equipmentSets => context.l10n.diveImport_uddf_tabSets,
    UddfEntityType.dives => context.l10n.diveImport_uddf_tabDives,
  };
}
