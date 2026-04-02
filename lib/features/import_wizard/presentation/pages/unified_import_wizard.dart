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
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_computer_adapter.dart';
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
        importWizardNotifierProvider.overrideWith(
          (ref) => ImportWizardNotifier(
            adapter,
            tagRepository: ref.read(tagRepositoryProvider),
          ),
        ),
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
  bool _navigatingForward = true;
  bool _resetComplete = false;

  List<WizardStepDef> get _acquisitionSteps => widget.adapter.acquisitionSteps;
  int get _reviewIndex => _acquisitionSteps.length;
  int get _importIndex => _acquisitionSteps.length + 1;
  int get _summaryIndex => _acquisitionSteps.length + 2;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Provide a go-back callback so step widgets with hideBottomBar can
    // navigate backward (e.g. the dive computer confirm step).
    final adapter = widget.adapter;
    if (adapter is DiveComputerAdapter) {
      adapter.goBackFromConfirm = () {
        _navigatingForward = false;
        _animateToPage(_currentPage - 1);
      };
    }

    // Reset adapter state from any previous import session.
    // Deferred to post-frame because Riverpod forbids provider modifications
    // during initState/build. The _resetComplete flag prevents auto-advance
    // from firing during the first frame while stale state is still present.
    //
    // The setState is deferred to a second post-frame callback so that
    // Riverpod's scheduled provider rebuilds (triggered by resetState)
    // complete before the widget tree re-accesses those providers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.adapter.resetState();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _resetComplete = true);
      });
    });
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
    _navigatingForward = true;
    if (_currentPage < _reviewIndex) {
      // Let the current step commit any pending state before we leave it.
      final step = _acquisitionSteps[_currentPage];
      await step.onBeforeAdvance?.call();
      if (!mounted) return;

      // Last acquisition step: build bundle then advance to review.
      if (_currentPage == _reviewIndex - 1) {
        final bundle = await widget.adapter.buildBundle();
        if (!mounted) return;
        final checkedBundle = await widget.adapter.checkDuplicates(bundle);
        if (!mounted) return;
        ref
            .read(importWizardNotifierProvider.notifier)
            .setBundle(checkedBundle);
        ref.read(importWizardNotifierProvider.notifier).initializeDefaultTag();
      }
      await _animateToPage(_currentPage + 1);
    } else if (_currentPage == _reviewIndex) {
      await _startImport();
    }
  }

  Future<void> _startImport() async {
    await _animateToPage(_importIndex);
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (!mounted) return;
    final notifier = ref.read(importWizardNotifierProvider.notifier);
    notifier.setDiverId(diverId);
    await notifier.performImport();
    if (!mounted) return;
    _invalidateImportedProviders();
    await _animateToPage(_summaryIndex);
  }

  /// Invalidate list providers for entity types that were imported so
  /// list screens reflect the new data without requiring an app restart.
  void _invalidateImportedProviders() {
    final result = ref.read(importWizardNotifierProvider).importResult;
    if (result == null) return;

    // Always refresh the computers list — ensureComputer() may have created
    // a new record even when all dives were skipped.
    if (widget.adapter.sourceType == ImportSourceType.diveComputer) {
      ref.invalidate(allDiveComputersProvider);
    }

    for (final type in result.importedCounts.keys) {
      if ((result.importedCounts[type] ?? 0) <= 0) continue;
      switch (type) {
        case ImportEntityType.dives:
          ref.invalidate(diveListNotifierProvider);
          ref.invalidate(paginatedDiveListProvider);
          ref.invalidate(divesProvider);
          ref.invalidate(diveStatisticsProvider);
          ref.invalidate(diveRecordsProvider);
          ref.invalidate(allDiveComputersProvider);
          ref.invalidate(nextDiveNumberProvider);
          // Dives link to sites, buddies, trips, etc. — their counts/lists
          // may change even when those entities weren't imported.
          ref.invalidate(sitesWithCountsProvider);
          ref.invalidate(siteListNotifierProvider);
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
    final result = ref.read(importWizardNotifierProvider).importResult;
    if (result != null && result.importedDiveIds.isNotEmpty) {
      ref.read(diveFilterProvider.notifier).state = DiveFilterState(
        diveIds: result.importedDiveIds,
      );
    }
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
    final currentStepDef = _currentPage < _acquisitionSteps.length
        ? _acquisitionSteps[_currentPage]
        : null;
    final showBottomBar =
        _currentPage < _reviewIndex &&
        !(currentStepDef?.hideBottomBar ?? false);

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
                    navigatingForward: _navigatingForward,
                    resetComplete: _resetComplete,
                    onAutoAdvance: () => _onNext(),
                  ),
                ),
                ReviewStep(
                  onImport: _startImport,
                  onBack: () {
                    _navigatingForward = false;
                    _animateToPage(_currentPage - 1);
                  },
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
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(100, 48),
                ),
                onPressed: () {
                  _navigatingForward = false;
                  _animateToPage(_currentPage - 1);
                },
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
                style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
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
    required this.navigatingForward,
    required this.resetComplete,
    required this.onAutoAdvance,
  });

  final int stepIndex;
  final WizardStepDef step;
  final bool isCurrentPage;
  final bool navigatingForward;
  final bool resetComplete;
  final VoidCallback onAutoAdvance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (step.autoAdvance &&
        isCurrentPage &&
        navigatingForward &&
        resetComplete) {
      final autoProvider = step.canAutoAdvance ?? step.canAdvance;
      // Listen for transitions from false → true.
      ref.listen<bool>(autoProvider, (previous, next) {
        if (next && previous != true) {
          onAutoAdvance();
        }
      });

      // Also advance if already true when we arrive (e.g., the Map Fields
      // step for non-CSV imports where the payload is already produced).
      final alreadyReady = ref.read(autoProvider);
      if (alreadyReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) => onAutoAdvance());
      }
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
      style: FilledButton.styleFrom(minimumSize: const Size(120, 48)),
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
