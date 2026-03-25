import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/providers/import_wizard_providers.dart';
import 'package:submersion/features/tags/presentation/providers/tag_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_progress_step.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/import_summary_step.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/review_step.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/wizard_step_indicator.dart';

/// The unified import wizard shell.
///
/// Accepts an [ImportSourceAdapter] and orchestrates the full import flow:
/// acquisition steps (source-specific), review, import progress, and summary.
class UnifiedImportWizard extends StatelessWidget {
  const UnifiedImportWizard({super.key, required this.adapter});

  final ImportSourceAdapter adapter;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        importWizardProvider.overrideWith((_) => ImportWizardNotifier(adapter)),
      ],
      child: _UnifiedImportWizardBody(adapter: adapter),
    );
  }
}

class _UnifiedImportWizardBody extends ConsumerStatefulWidget {
  const _UnifiedImportWizardBody({required this.adapter});

  final ImportSourceAdapter adapter;

  @override
  ConsumerState<_UnifiedImportWizardBody> createState() =>
      _UnifiedImportWizardBodyState();
}

class _UnifiedImportWizardBodyState
    extends ConsumerState<_UnifiedImportWizardBody> {
  late final PageController _pageController;
  int _currentPage = 0;

  List<WizardStepDef> get _acquisitionSteps => widget.adapter.acquisitionSteps;
  int get _reviewIndex => _acquisitionSteps.length;
  int get _importIndex => _acquisitionSteps.length + 1;
  int get _summaryIndex => _acquisitionSteps.length + 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<String> _buildStepLabels() {
    final labels = _acquisitionSteps.map((s) => s.label).toList();
    labels.add('Review');
    labels.add('Import');
    labels.add('Done');
    return labels;
  }

  Future<void> _animateToPage(int page) async {
    if (_pageController.hasClients) {
      await _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    if (mounted) {
      setState(() => _currentPage = page);
    }
  }

  Future<void> _onNext() async {
    if (_currentPage < _reviewIndex) {
      // Last acquisition step: build bundle then advance to review.
      if (_currentPage == _reviewIndex - 1) {
        final bundle = await widget.adapter.buildBundle();
        final checkedBundle = await widget.adapter.checkDuplicates(bundle);
        ref.read(importWizardProvider.notifier).setBundle(checkedBundle);
      }
      await _animateToPage(_currentPage + 1);
    } else if (_currentPage == _reviewIndex) {
      await _startImport();
    }
  }

  Future<void> _startImport() async {
    await _animateToPage(_importIndex);
    await ref.read(importWizardProvider.notifier).performImport();
    _invalidateImportedProviders();
    await _animateToPage(_summaryIndex);
  }

  /// Invalidate list providers for entity types that were imported so
  /// list screens reflect the new data without requiring an app restart.
  void _invalidateImportedProviders() {
    final result = ref.read(importWizardProvider).importResult;
    if (result == null) return;

    for (final type in result.importedCounts.keys) {
      if ((result.importedCounts[type] ?? 0) <= 0) continue;
      switch (type) {
        case ImportEntityType.dives:
          ref.invalidate(diveListNotifierProvider);
          ref.invalidate(paginatedDiveListProvider);
          ref.invalidate(allDiveComputersProvider);
        case ImportEntityType.sites:
          ref.invalidate(sitesProvider);
          ref.invalidate(sitesWithCountsProvider);
          ref.invalidate(siteListNotifierProvider);
        case ImportEntityType.buddies:
          ref.invalidate(allBuddiesProvider);
        case ImportEntityType.equipment:
          ref.invalidate(allEquipmentProvider);
          ref.invalidate(activeEquipmentProvider);
          ref.invalidate(retiredEquipmentProvider);
          ref.invalidate(serviceDueEquipmentProvider);
          ref.invalidate(equipmentListNotifierProvider);
        case ImportEntityType.equipmentSets:
          ref.invalidate(equipmentSetsProvider);
        case ImportEntityType.trips:
          ref.invalidate(allTripsProvider);
        case ImportEntityType.diveCenters:
          ref.invalidate(allDiveCentersProvider);
        case ImportEntityType.certifications:
          ref.invalidate(allCertificationsProvider);
        case ImportEntityType.courses:
          ref.invalidate(allCoursesProvider);
        case ImportEntityType.tags:
          ref.invalidate(tagsProvider);
        case ImportEntityType.diveTypes:
          ref.invalidate(diveTypesProvider);
      }
    }
  }

  void _close() {
    context.pop();
  }

  void _navigateToDives() {
    context.go('/dives');
  }

  Future<void> _onClosePressed() async {
    if (_currentPage >= _summaryIndex) {
      _close();
      return;
    }

    if (_currentPage >= _importIndex) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Import in progress'),
          content: const Text('Import is in progress and cannot be cancelled.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    final String message;
    if (_currentPage == _reviewIndex) {
      message = 'Discard selections and cancel?';
    } else {
      message = 'Cancel import?';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepLabels = _buildStepLabels();
    final showBottomBar = _currentPage < _reviewIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.adapter.displayName),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _onClosePressed,
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          WizardStepIndicator(labels: stepLabels, currentStep: _currentPage),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ..._acquisitionSteps.mapIndexed(
                  (i, step) => _AcquisitionStepPage(
                    stepIndex: i,
                    step: step,
                    isCurrentPage: _currentPage == i,
                    onAutoAdvance: () => _onNext(),
                  ),
                ),
                ReviewStep(
                  onImport: _startImport,
                  onBack: () => _animateToPage(_currentPage - 1),
                ),
                const ImportProgressStep(),
                ImportSummaryStep(
                  onDone: _close,
                  onViewDives: _navigateToDives,
                ),
              ],
            ),
          ),
          if (showBottomBar) _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            if (_currentPage > 0 &&
                _currentPage < _importIndex &&
                _currentPage != _summaryIndex)
              TextButton(
                onPressed: () => _animateToPage(_currentPage - 1),
                child: const Text('Back'),
              ),
            const Spacer(),
            if (_currentPage < _reviewIndex)
              _AcquisitionNextButton(
                stepIndex: _currentPage,
                step: _acquisitionSteps[_currentPage],
                onNext: _onNext,
              )
            else if (_currentPage == _reviewIndex)
              FilledButton(
                onPressed: _startImport,
                child: const Text('Import Selected'),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Acquisition step page wrapper (handles autoAdvance)
// ---------------------------------------------------------------------------

class _AcquisitionStepPage extends ConsumerWidget {
  const _AcquisitionStepPage({
    required this.stepIndex,
    required this.step,
    required this.isCurrentPage,
    required this.onAutoAdvance,
  });

  final int stepIndex;
  final WizardStepDef step;
  final bool isCurrentPage;
  final VoidCallback onAutoAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (step.autoAdvance && isCurrentPage) {
      ref.listen<bool>(step.canAdvance, (previous, next) {
        if (next && previous != true) {
          onAutoAdvance();
        }
      });
    }

    return step.builder(context);
  }
}

// ---------------------------------------------------------------------------
// Next button for acquisition steps (watches canAdvance)
// ---------------------------------------------------------------------------

class _AcquisitionNextButton extends ConsumerWidget {
  const _AcquisitionNextButton({
    required this.stepIndex,
    required this.step,
    required this.onNext,
  });

  final int stepIndex;
  final WizardStepDef step;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canAdvance = ref.watch(step.canAdvance);

    return FilledButton(
      onPressed: canAdvance ? onNext : null,
      child: const Text('Next'),
    );
  }
}

// ---------------------------------------------------------------------------
// Iterable extension helper
// ---------------------------------------------------------------------------

extension _IndexedMap<T> on List<T> {
  Iterable<E> mapIndexed<E>(E Function(int index, T item) fn) sync* {
    for (var i = 0; i < length; i++) {
      yield fn(i, this[i]);
    }
  }
}
