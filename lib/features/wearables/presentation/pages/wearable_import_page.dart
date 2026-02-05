import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/wearables/presentation/providers/wearable_providers.dart';
import 'package:submersion/features/wearables/presentation/widgets/wearable_dive_card.dart';

/// Import wizard for wearable dives (Apple Watch via HealthKit).
///
/// Three-step process:
/// 1. Select dives - Date range filter, list of available dives with selection
/// 2. Handle duplicates - Review potential matches, choose merge/skip/import
/// 3. Summary - Show import results with counts
class WearableImportPage extends ConsumerStatefulWidget {
  const WearableImportPage({super.key});

  @override
  ConsumerState<WearableImportPage> createState() => _WearableImportPageState();
}

class _WearableImportPageState extends ConsumerState<WearableImportPage> {
  int _currentStep = 0;
  bool _hasRequestedPermissions = false;

  @override
  Widget build(BuildContext context) {
    // Check platform availability
    if (!Platform.isIOS && !Platform.isMacOS) {
      return _buildPlatformUnavailable(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Apple Watch'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final hasPermissions = ref.watch(wearableHasPermissionsProvider);

    return hasPermissions.when(
      data: (hasPerms) {
        if (!hasPerms && !_hasRequestedPermissions) {
          return _buildPermissionRequest(context);
        }
        return _buildWizard(context);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildError(context, 'Failed to check permissions'),
    );
  }

  Widget _buildPlatformUnavailable(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import from Watch'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.watch_off,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Not Available',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Apple Watch import is only available on iOS and macOS devices.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionRequest(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.health_and_safety,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'HealthKit Access Required',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Submersion needs access to your Apple Watch dive data to import dives.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.lock_open),
              label: const Text('Grant Access'),
              onPressed: _requestPermissions,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestPermissions() async {
    final notifier = ref.read(wearableImportProvider.notifier);
    final granted = await notifier.requestPermissions();
    setState(() {
      _hasRequestedPermissions = true;
    });

    if (granted) {
      // Refresh permissions provider
      ref.invalidate(wearableHasPermissionsProvider);
    }
  }

  Widget _buildWizard(BuildContext context) {
    return Column(
      children: [
        _buildStepIndicator(context),
        Expanded(
          child: switch (_currentStep) {
            0 => _buildStepSelectDives(context),
            1 => _buildStepHandleDuplicates(context),
            2 => _buildStepSummary(context),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= _currentStep
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                ),
              ),
            _StepDot(
              step: i + 1,
              label: ['Select', 'Review', 'Done'][i],
              isActive: i == _currentStep,
              isCompleted: i < _currentStep,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepSelectDives(BuildContext context) {
    final importState = ref.watch(wearableImportProvider);
    final dateRange = ref.watch(importDateRangeProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // Date range filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _DateRangeSelector(
            startDate: dateRange.startDate,
            endDate: dateRange.endDate,
            onChanged: (start, end) {
              ref.read(importDateRangeProvider.notifier).setRange(start, end);
            },
          ),
        ),
        const SizedBox(height: 8),

        // Fetch button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: importState.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: Text(
                importState.isLoading ? 'Fetching...' : 'Fetch Dives',
              ),
              onPressed: importState.isLoading ? null : _fetchDives,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Dive list
        Expanded(
          child: importState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : importState.error != null
                  ? _buildError(context, importState.error!)
                  : importState.availableDives.isEmpty
                      ? _buildEmptyState(context)
                      : _buildDiveList(context, importState),
        ),

        // Action buttons
        if (importState.availableDives.isNotEmpty)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  TextButton(
                    onPressed: importState.hasSelection
                        ? () => ref
                            .read(wearableImportProvider.notifier)
                            .deselectAll()
                        : () => ref
                            .read(wearableImportProvider.notifier)
                            .selectAll(),
                    child: Text(
                      importState.hasSelection ? 'Deselect All' : 'Select All',
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${importState.selectedCount} selected',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: importState.hasSelection
                        ? () => setState(() => _currentStep = 1)
                        : null,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDiveList(BuildContext context, WearableImportState state) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.availableDives.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final dive = state.availableDives[index];
        return WearableDiveCard(
          dive: dive,
          isSelected: state.isSelected(dive.sourceId),
          onToggleSelection: () {
            ref.read(wearableImportProvider.notifier).toggleSelection(
                  dive.sourceId,
                );
          },
          matchStatus: WearableDiveMatchStatus.none, // TODO: Implement matching
        );
      },
    );
  }

  Widget _buildStepHandleDuplicates(BuildContext context) {
    final importState = ref.watch(wearableImportProvider);

    // For now, just show selected dives with option to proceed
    // TODO: Implement actual duplicate checking against existing dives
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Selected Dives',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${importState.selectedCount} dives will be imported. '
                  'Duplicate checking with existing dives will be implemented in a future update.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: importState.selectedCount,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sourceId =
                          importState.selectedDiveIds.elementAt(index);
                      final dive = importState.getDiveById(sourceId);
                      if (dive == null) return const SizedBox.shrink();

                      return WearableDiveCard(
                        dive: dive,
                        isSelected: true,
                        onToggleSelection: () {},
                        matchStatus: WearableDiveMatchStatus.none,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text('Back'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: _performImport,
                  child: const Text('Import'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepSummary(BuildContext context) {
    final importState = ref.watch(wearableImportProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle,
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Import Complete',
            style: theme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 16),
          _SummaryRow(
            label: 'Dives imported',
            value: importState.importedCount.toString(),
            icon: Icons.add_circle_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Dives merged',
            value: importState.mergedCount.toString(),
            icon: Icons.merge,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Dives skipped',
            value: importState.skippedCount.toString(),
            icon: Icons.skip_next,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.watch_off,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No Dives Found',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'No underwater diving activities found in the selected date range.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _fetchDives() {
    final dateRange = ref.read(importDateRangeProvider);
    ref.read(wearableImportProvider.notifier).fetchDives(
          startDate: dateRange.startDate,
          endDate: dateRange.endDate,
        );
  }

  void _performImport() {
    final importState = ref.read(wearableImportProvider);

    // TODO: Actually import dives to database
    // For now, just simulate success
    ref.read(wearableImportProvider.notifier).updateCounts(
          imported: importState.selectedCount,
          merged: 0,
          skipped: 0,
        );

    setState(() => _currentStep = 2);
  }
}

/// Step indicator dot.
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
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: colorScheme.onPrimary,
                  )
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

/// Date range selector widget.
class _DateRangeSelector extends StatelessWidget {
  const _DateRangeSelector({
    required this.startDate,
    required this.endDate,
    required this.onChanged,
  });

  final DateTime startDate;
  final DateTime endDate;
  final void Function(DateTime start, DateTime end) onChanged;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd();

    return Row(
      children: [
        Expanded(
          child: _DateButton(
            label: 'From',
            date: startDate,
            onTap: () => _selectDate(context, true),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _DateButton(
            label: 'To',
            date: endDate,
            onTap: () => _selectDate(context, false),
          ),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final now = DateTime.now();
    final initialDate = isStart ? startDate : endDate;
    final firstDate = isStart ? now.subtract(const Duration(days: 365)) : startDate;
    final lastDate = isStart ? endDate : now;

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (selected != null) {
      if (isStart) {
        onChanged(selected, endDate);
      } else {
        onChanged(startDate, selected);
      }
    }
  }
}

/// Date selection button.
class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    dateFormat.format(date),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary row for import results.
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

    return Row(
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
    );
  }
}
