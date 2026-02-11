import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_import/presentation/providers/dive_import_providers.dart';
import 'package:submersion/features/dive_import/presentation/widgets/imported_dive_card.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Import wizard for Garmin FIT dive files.
///
/// Three-step process:
/// 1. Pick FIT files - Select and parse .fit files from device
/// 2. Review duplicates - Check for existing matches, choose skip/import
/// 3. Summary - Show import results with counts
class FitImportPage extends ConsumerStatefulWidget {
  const FitImportPage({super.key});

  @override
  ConsumerState<FitImportPage> createState() => _FitImportPageState();
}

class _FitImportPageState extends ConsumerState<FitImportPage> {
  int _currentStep = 0;
  int _skippedFileCount = 0;
  int _totalFileCount = 0;
  bool _isParsing = false;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diveImport_fit_title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: context.l10n.diveImport_fit_closeTooltip,
          onPressed: () {
            ref.read(fitImportProvider.notifier).reset();
            context.pop();
          },
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(context),
          Expanded(
            child: switch (_currentStep) {
              0 => _buildStepPickFiles(context),
              1 => _buildStepHandleDuplicates(context),
              2 => _buildStepSummary(context),
              _ => const SizedBox.shrink(),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              label: [
                context.l10n.diveImport_step_select,
                context.l10n.diveImport_step_review,
                context.l10n.diveImport_step_done,
              ][i],
              isActive: i == _currentStep,
              isCompleted: i < _currentStep,
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Step 0: Pick and parse FIT files
  // ===========================================================================

  Widget _buildStepPickFiles(BuildContext context) {
    final importState = ref.watch(fitImportProvider);
    final theme = Theme.of(context);

    return Column(
      children: [
        // File picker button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isParsing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_open),
              label: Text(
                _isParsing
                    ? context.l10n.diveImport_fit_parsing
                    : context.l10n.diveImport_fit_selectFiles,
              ),
              onPressed: _isParsing ? null : _pickAndParseFiles,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Parse results summary
        if (_totalFileCount > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _skippedFileCount > 0
                  ? context.l10n.diveImport_fit_parsedWithSkipped(
                      importState.availableDives.length,
                      _totalFileCount,
                      _skippedFileCount,
                    )
                  : context.l10n.diveImport_fit_parsed(
                      importState.availableDives.length,
                      _totalFileCount,
                    ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 16),

        // Error display
        if (importState.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildError(context, importState.error!),
          ),

        // Dive list
        Expanded(
          child: importState.availableDives.isEmpty
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
                        ? () =>
                              ref.read(fitImportProvider.notifier).deselectAll()
                        : () =>
                              ref.read(fitImportProvider.notifier).selectAll(),
                    child: Text(
                      importState.hasSelection
                          ? context.l10n.diveImport_deselectAll
                          : context.l10n.diveImport_selectAll,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    context.l10n.diveImport_selectedCount(
                      importState.selectedCount,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton(
                    onPressed: importState.hasSelection
                        ? _checkDuplicatesAndAdvance
                        : null,
                    child: Text(context.l10n.diveImport_next),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDiveList(BuildContext context, DiveImportState state) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.availableDives.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final dive = state.availableDives[index];
        return ImportedDiveCard(
          dive: dive,
          isSelected: state.isSelected(dive.sourceId),
          onToggleSelection: () {
            ref.read(fitImportProvider.notifier).toggleSelection(dive.sourceId);
          },
          matchStatus: state.matchResults[dive.sourceId],
        );
      },
    );
  }

  // ===========================================================================
  // Step 1: Review duplicates
  // ===========================================================================

  Widget _buildStepHandleDuplicates(BuildContext context) {
    final importState = ref.watch(fitImportProvider);
    final theme = Theme.of(context);

    if (importState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final newCount = importState.matchResults.values
        .where((s) => s == ImportMatchStatus.none)
        .length;
    final possibleCount = importState.matchResults.values
        .where((s) => s == ImportMatchStatus.possible)
        .length;
    final skipCount = importState.matchResults.values
        .where(
          (s) =>
              s == ImportMatchStatus.alreadyImported ||
              s == ImportMatchStatus.probable,
        )
        .length;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.diveImport_reviewSelectedDives,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.diveImport_reviewSummary(
                    newCount,
                    possibleCount,
                    skipCount,
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.separated(
                    itemCount: importState.selectedCount,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final sourceId = importState.selectedDiveIds.elementAt(
                        index,
                      );
                      final dive = importState.getDiveById(sourceId);
                      if (dive == null) return const SizedBox.shrink();

                      return ImportedDiveCard(
                        dive: dive,
                        isSelected: true,
                        onToggleSelection: () {},
                        matchStatus: importState.matchResults[sourceId],
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
                  child: Text(context.l10n.diveImport_back),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: importState.isImporting ? null : _performImport,
                  child: importState.isImporting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.diveImport_import),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Step 2: Summary
  // ===========================================================================

  Widget _buildStepSummary(BuildContext context) {
    final importState = ref.watch(fitImportProvider);
    final theme = Theme.of(context);

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
          _SummaryRow(
            label: context.l10n.diveImport_divesImported,
            value: importState.importedCount.toString(),
            icon: Icons.add_circle_outline,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: context.l10n.diveImport_divesMerged,
            value: importState.mergedCount.toString(),
            icon: Icons.merge,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: context.l10n.diveImport_divesSkipped,
            value: importState.skippedCount.toString(),
            icon: Icons.skip_next,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () {
              ref.read(fitImportProvider.notifier).reset();
              context.pop();
            },
            child: Text(context.l10n.diveImport_done),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Shared widgets
  // ===========================================================================

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.file_open,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.diveImport_fit_noDivesLoaded,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.diveImport_fit_noDivesDescription,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
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

  // ===========================================================================
  // Actions
  // ===========================================================================

  Future<void> _pickAndParseFiles() async {
    setState(() => _isParsing = true);

    try {
      // Platform-aware file type handling
      final useAnyType = Platform.isIOS || Platform.isMacOS;
      final result = await FilePicker.platform.pickFiles(
        type: useAnyType ? FileType.any : FileType.custom,
        allowedExtensions: useAnyType ? null : ['fit'],
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isParsing = false);
        return;
      }

      // Filter to .fit files (manual check for iOS/macOS)
      final fitFiles = result.files.where((f) {
        final ext = f.extension?.toLowerCase();
        return ext == 'fit';
      }).toList();

      if (fitFiles.isEmpty) {
        setState(() {
          _isParsing = false;
          _totalFileCount = result.files.length;
          _skippedFileCount = result.files.length;
        });
        ref.read(fitImportProvider.notifier).loadDives([]);
        return;
      }

      // Read file bytes
      final fileBytesList = <Uint8List>[];
      final fileNames = <String>[];
      for (final file in fitFiles) {
        final path = file.path;
        if (path == null) continue;
        final bytes = await File(path).readAsBytes();
        fileBytesList.add(bytes);
        fileNames.add(file.name);
      }

      // Parse FIT files
      final parser = ref.read(fitParserServiceProvider);
      final dives = await parser.parseFitFiles(
        fileBytesList,
        fileNames: fileNames,
      );

      final notifier = ref.read(fitImportProvider.notifier);
      notifier.loadDives(dives);

      setState(() {
        _totalFileCount = fitFiles.length;
        _skippedFileCount = fitFiles.length - dives.length;
        _isParsing = false;
      });
    } catch (e) {
      setState(() => _isParsing = false);
      ref.read(fitImportProvider.notifier).loadDives([]);
    }
  }

  Future<void> _checkDuplicatesAndAdvance() async {
    final notifier = ref.read(fitImportProvider.notifier);
    final repository = ref.read(diveRepositoryProvider);
    final matcher = ref.read(diveMatcherProvider);

    await notifier.checkForDuplicates(repository: repository, matcher: matcher);

    if (mounted) {
      setState(() => _currentStep = 1);
    }
  }

  Future<void> _performImport() async {
    final notifier = ref.read(fitImportProvider.notifier);
    final repository = ref.read(diveRepositoryProvider);
    final converter = ref.read(importedDiveConverterProvider);
    final diverId = ref.read(currentDiverIdProvider);

    await notifier.performImport(
      repository: repository,
      converter: converter,
      diverId: diverId,
    );

    // Refresh the dive list so new imports appear immediately
    ref.invalidate(divesProvider);

    if (mounted) {
      setState(() => _currentStep = 2);
    }
  }
}

// =============================================================================
// Private widgets
// =============================================================================

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
