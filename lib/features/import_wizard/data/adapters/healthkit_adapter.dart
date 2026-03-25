import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';

/// Riverpod [StateProvider] signalling whether HealthKit permissions have been
/// granted and the wizard may advance to the date range step.
final healthKitPermissionsGrantedProvider = StateProvider<bool>((ref) => false);

/// Riverpod [StateProvider] signalling whether a date range has been selected
/// and the wizard may advance to the fetch step.
final healthKitDateRangeSelectedProvider = StateProvider<bool>((ref) => true);

/// Riverpod [StateProvider] signalling whether dives have been fetched from
/// HealthKit and the wizard may advance to the review step.
final healthKitDivesFetchedProvider = StateProvider<bool>((ref) => false);

/// Import source adapter for Apple HealthKit dives (Apple Watch).
///
/// Implements [ImportSourceAdapter] for the unified import wizard with three
/// acquisition steps:
/// 1. Permissions — request HealthKit access.
/// 2. Date Range — pick start and end dates (defaults to last 30 days).
/// 3. Fetch — fetch dives from HealthKit (auto-advances on completion).
///
/// Supports dives only. The [consolidate] duplicate action is not supported —
/// only [skip] and [importAsNew] are available.
class HealthKitAdapter implements ImportSourceAdapter {
  HealthKitAdapter({
    required HealthImportService healthService,
    required DiveMatcher diveMatcher,
    required ImportedDiveConverter converter,
    required DiveRepository diveRepository,
    required String diverId,
    String displayName = 'HealthKit Import',
  }) : _healthService = healthService,
       _diveMatcher = diveMatcher,
       _converter = converter,
       _diveRepository = diveRepository,
       _diverId = diverId,
       _displayName = displayName;

  final HealthImportService _healthService;
  final DiveMatcher _diveMatcher;
  final ImportedDiveConverter _converter;
  final DiveRepository _diveRepository;
  final String _diverId;
  final String _displayName;

  List<ImportedDive> _parsedDives = [];

  /// Load the list of fetched [ImportedDive]s into this adapter.
  ///
  /// Called internally by the Fetch step widget after fetching from HealthKit.
  void setParsedDives(List<ImportedDive> dives) {
    _parsedDives = List.unmodifiable(dives);
  }

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  ImportSourceType get sourceType => ImportSourceType.healthKit;

  @override
  String get displayName => _displayName;

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
  };

  @override
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Permissions',
      icon: Icons.health_and_safety,
      builder: (context) =>
          _HealthKitPermissionsStep(healthService: _healthService),
      canAdvance: healthKitPermissionsGrantedProvider,
      autoAdvance: false,
    ),
    WizardStepDef(
      label: 'Date Range',
      icon: Icons.date_range,
      builder: (context) => const _HealthKitDateRangeStep(),
      canAdvance: healthKitDateRangeSelectedProvider,
      autoAdvance: false,
    ),
    WizardStepDef(
      label: 'Fetch',
      icon: Icons.download,
      builder: (context) => _HealthKitFetchStep(
        healthService: _healthService,
        onDivesFetched: (dives) {
          setParsedDives(dives);
        },
      ),
      canAdvance: healthKitDivesFetchedProvider,
      autoAdvance: true,
    ),
  ];

  @override
  Future<ImportBundle> buildBundle() async {
    final items = _parsedDives.map(_diveToEntityItem).toList();

    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.healthKit,
        displayName: _displayName,
      ),
      groups: {ImportEntityType.dives: EntityGroup(items: items)},
    );
  }

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    final diveGroup = bundle.groups[ImportEntityType.dives];
    if (diveGroup == null || diveGroup.items.isEmpty) return bundle;

    final existingDives = await _diveRepository.getAllDives(diverId: _diverId);

    final duplicateIndices = <int>{};
    final matchResults = <int, DiveMatchResult>{};

    for (var i = 0; i < _parsedDives.length; i++) {
      final imported = _parsedDives[i];
      DiveMatchResult? bestMatch;

      for (final existing in existingDives) {
        final score = _diveMatcher.calculateMatchScore(
          wearableStartTime: imported.startTime,
          wearableMaxDepth: imported.maxDepth,
          wearableDurationSeconds: imported.durationSeconds,
          existingStartTime: existing.effectiveEntryTime,
          existingMaxDepth: existing.maxDepth ?? 0.0,
          existingDurationSeconds: existing.duration?.inSeconds ?? 0,
        );

        if (score >= 0.5) {
          if (bestMatch == null || score > bestMatch.score) {
            bestMatch = DiveMatchResult(
              diveId: existing.id,
              score: score,
              timeDifferenceMs: imported.startTime
                  .difference(existing.effectiveEntryTime)
                  .inMilliseconds
                  .abs(),
              depthDifferenceMeters:
                  ((imported.maxDepth) - (existing.maxDepth ?? 0.0)).abs(),
              durationDifferenceSeconds:
                  (imported.durationSeconds -
                          (existing.duration?.inSeconds ?? 0))
                      .abs(),
            );
          }
        }
      }

      if (bestMatch != null) {
        duplicateIndices.add(i);
        matchResults[i] = bestMatch;
      }
    }

    return ImportBundle(
      source: bundle.source,
      groups: {
        ...bundle.groups,
        ImportEntityType.dives: EntityGroup(
          items: diveGroup.items,
          duplicateIndices: duplicateIndices,
          matchResults: matchResults,
        ),
      },
    );
  }

  @override
  Future<UnifiedImportResult> performImport(
    ImportBundle bundle,
    Map<ImportEntityType, Set<int>> selections,
    Map<ImportEntityType, Map<int, DuplicateAction>> duplicateActions, {
    void Function(String phase, int current, int total)? onProgress,
  }) async {
    final baseSelections = Set<int>.from(
      selections[ImportEntityType.dives] ?? <int>{},
    );
    final diveActions = duplicateActions[ImportEntityType.dives] ?? {};

    // Build the final set of indices to import and count skips.
    // - Plain selections are imported unless overridden with skip.
    // - importAsNew action adds an index even if not in plain selections.
    // - skip action removes an index and increments skipped count.
    final indicesToImport = <int>{};
    var skipped = 0;

    for (final index in baseSelections) {
      final action = diveActions[index];
      if (action == DuplicateAction.skip) {
        skipped++;
      } else {
        indicesToImport.add(index);
      }
    }

    for (final entry in diveActions.entries) {
      if (entry.value == DuplicateAction.importAsNew) {
        indicesToImport.add(entry.key);
      } else if (entry.value == DuplicateAction.skip &&
          !baseSelections.contains(entry.key)) {
        // skip action on an index not in selections — count it as skipped
        skipped++;
      }
    }

    final sortedIndices = indicesToImport.toList()..sort();
    final total = sortedIndices.length;
    var imported = 0;
    final importedDiveIds = <String>[];

    for (var i = 0; i < sortedIndices.length; i++) {
      final index = sortedIndices[i];

      if (index >= _parsedDives.length) continue;

      final importedDive = _parsedDives[index];
      final dive = _converter.convert(importedDive, diverId: _diverId);
      await _diveRepository.createDive(dive);

      imported++;
      importedDiveIds.add(dive.id);
      onProgress?.call('Dives', i + 1, total);
    }

    return UnifiedImportResult(
      importedCounts: {ImportEntityType.dives: imported},
      consolidatedCount: 0,
      skippedCount: skipped,
      importedDiveIds: importedDiveIds,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static final _dateFormatter = DateFormat('MMM d, yyyy');
  static final _timeFormatter = DateFormat('h:mm a');

  EntityItem _diveToEntityItem(ImportedDive dive) {
    final dateStr = _dateFormatter.format(dive.startTime);
    final timeStr = _timeFormatter.format(dive.startTime);
    final title = '$dateStr \u2014 $timeStr';

    final depthStr = dive.maxDepth.toStringAsFixed(1);
    final durationMin = dive.duration.inMinutes;
    final tempStr = dive.minTemperature != null
        ? ' \u00b7 ${dive.minTemperature!.toStringAsFixed(1)}\u00b0C'
        : '';
    final subtitle = '${depthStr}m max \u00b7 $durationMin min$tempStr';

    final profile = dive.profile
        .map(
          (s) => DiveProfilePoint(
            timestamp: s.timeSeconds,
            depth: s.depth,
            temperature: s.temperature,
            heartRate: s.heartRate,
          ),
        )
        .toList();

    final diveData = IncomingDiveData(
      startTime: dive.startTime,
      maxDepth: dive.maxDepth,
      avgDepth: dive.avgDepth,
      durationSeconds: dive.durationSeconds,
      waterTemp: dive.minTemperature,
      profile: profile,
    );

    return EntityItem(title: title, subtitle: subtitle, diveData: diveData);
  }
}

// =============================================================================
// Private widgets
// =============================================================================

/// Permissions step for the HealthKit import wizard.
///
/// Checks whether HealthKit permissions have already been granted. If not,
/// presents a button to request them. Sets [healthKitPermissionsGrantedProvider]
/// to true when permissions are granted.
class _HealthKitPermissionsStep extends ConsumerStatefulWidget {
  const _HealthKitPermissionsStep({required this.healthService});

  final HealthImportService healthService;

  @override
  ConsumerState<_HealthKitPermissionsStep> createState() =>
      _HealthKitPermissionsStepState();
}

class _HealthKitPermissionsStepState
    extends ConsumerState<_HealthKitPermissionsStep> {
  bool _isChecking = true;
  bool _isRequesting = false;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    try {
      final granted = await widget.healthService.hasPermissions();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _permissionsGranted = granted;
        });
        if (granted) {
          ref.read(healthKitPermissionsGrantedProvider.notifier).state = true;
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _isRequesting = true);
    try {
      final granted = await widget.healthService.requestPermissions();
      if (mounted) {
        setState(() {
          _isRequesting = false;
          _permissionsGranted = granted;
        });
        ref.read(healthKitPermissionsGrantedProvider.notifier).state = granted;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isChecking) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_permissionsGranted) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'HealthKit Access Granted',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'You can proceed to the next step.',
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.health_and_safety,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'HealthKit Access Required',
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Submersion needs access to your Apple Health data to import '
              'dives recorded by your Apple Watch.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: _isRequesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.health_and_safety),
              label: Text(
                _isRequesting ? 'Requesting...' : 'Grant HealthKit Access',
              ),
              onPressed: _isRequesting ? null : _requestPermissions,
            ),
          ],
        ),
      ),
    );
  }
}

/// Date range step for the HealthKit import wizard.
///
/// Presents start and end date pickers defaulting to the last 30 days.
/// Sets [healthKitDateRangeSelectedProvider] to true when both dates are
/// selected (which they are by default).
class _HealthKitDateRangeStep extends ConsumerStatefulWidget {
  const _HealthKitDateRangeStep();

  @override
  ConsumerState<_HealthKitDateRangeStep> createState() =>
      _HealthKitDateRangeStepState();
}

class _HealthKitDateRangeStepState
    extends ConsumerState<_HealthKitDateRangeStep> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 30));
    // Both dates are initialized so canAdvance starts true.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(healthKitDateRangeSelectedProvider.notifier).state = true;
      }
    });
  }

  Future<void> _selectStartDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      lastDate: _endDate,
    );
    if (selected != null && mounted) {
      setState(() => _startDate = selected);
      ref.read(healthKitDateRangeSelectedProvider.notifier).state = true;
    }
  }

  Future<void> _selectEndDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _endDate = selected);
      ref.read(healthKitDateRangeSelectedProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select Date Range', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Choose the date range to search for dives in Apple Health.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _DatePickerButton(
                  label: 'From',
                  date: _startDate,
                  dateText: dateFormat.format(_startDate),
                  onTap: _selectStartDate,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DatePickerButton(
                  label: 'To',
                  date: _endDate,
                  dateText: dateFormat.format(_endDate),
                  onTap: _selectEndDate,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple date picker button used by [_HealthKitDateRangeStep].
class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.dateText,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final String dateText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                  Text(dateText, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fetch step for the HealthKit import wizard.
///
/// Reads the date range stored by [_HealthKitDateRangeStep] and calls
/// [HealthImportService.fetchDives]. Shows a progress spinner while fetching.
/// When complete, calls [onDivesFetched] and sets
/// [healthKitDivesFetchedProvider] to true, triggering auto-advance.
class _HealthKitFetchStep extends ConsumerStatefulWidget {
  const _HealthKitFetchStep({
    required this.healthService,
    required this.onDivesFetched,
  });

  final HealthImportService healthService;
  final void Function(List<ImportedDive> dives) onDivesFetched;

  @override
  ConsumerState<_HealthKitFetchStep> createState() =>
      _HealthKitFetchStepState();
}

class _HealthKitFetchStepState extends ConsumerState<_HealthKitFetchStep> {
  bool _isFetching = false;
  bool _hasFetched = false;
  int _diveCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDives();
    });
  }

  Future<void> _fetchDives() async {
    if (_isFetching) return;

    setState(() {
      _isFetching = true;
      _error = null;
    });

    try {
      // Derive the date range from the date range provider state (defaults to
      // last 30 days — the step widget initialises to that range).
      final now = DateTime.now();
      final startDate = now.subtract(const Duration(days: 30));
      final endDate = now;

      final dives = await widget.healthService.fetchDives(
        startDate: startDate,
        endDate: endDate,
      );

      widget.onDivesFetched(dives);

      if (mounted) {
        setState(() {
          _isFetching = false;
          _hasFetched = true;
          _diveCount = dives.length;
        });
        ref.read(healthKitDivesFetchedProvider.notifier).state = true;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFetching = false;
          _error = 'Failed to fetch dives: $e';
        });
        widget.onDivesFetched([]);
        ref.read(healthKitDivesFetchedProvider.notifier).state = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isFetching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Fetching dives from Apple Health...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
              Text('Fetch Failed', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                _error!,
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

    if (_hasFetched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.check_circle,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Found $_diveCount dive${_diveCount == 1 ? '' : 's'}',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Proceeding to review...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
