import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/healthkit_adapter_steps.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

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
    WidgetRef? ref,
    AppSettings settings = const AppSettings(),
    String displayName = 'HealthKit Import',
  }) : _healthService = healthService,
       _diveMatcher = diveMatcher,
       _converter = converter,
       _diveRepository = diveRepository,
       _diverId = diverId,
       _ref = ref,
       _settings = settings,
       _displayName = displayName;

  final HealthImportService _healthService;
  final DiveMatcher _diveMatcher;
  final ImportedDiveConverter _converter;
  final DiveRepository _diveRepository;
  final String _diverId;
  final WidgetRef? _ref;
  final AppSettings _settings;
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
  void resetState() {
    final ref = _ref;
    if (ref == null) return;
    ref.invalidate(healthKitPermissionsGrantedProvider);
    ref.invalidate(healthKitDateRangeSelectedProvider);
    ref.invalidate(healthKitDivesFetchedProvider);
    ref.invalidate(healthKitDateRangeProvider);
  }

  @override
  ImportSourceType get sourceType => ImportSourceType.healthKit;

  @override
  String get displayName => _displayName;

  @override
  String get defaultTagName {
    final name = _displayName.trim();
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    final base = name.toLowerCase().endsWith('import') ? name : '$name Import';
    return '$base $date';
  }

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
          HealthKitPermissionsStep(healthService: _healthService),
      canAdvance: healthKitPermissionsGrantedProvider,
      autoAdvance: false,
    ),
    WizardStepDef(
      label: 'Date Range',
      icon: Icons.date_range,
      builder: (context) => const HealthKitDateRangeStep(),
      canAdvance: healthKitDateRangeSelectedProvider,
      autoAdvance: false,
    ),
    WizardStepDef(
      label: 'Fetch',
      icon: Icons.download,
      builder: (context) => HealthKitFetchStep(
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
        final existingSeconds = _diveSeconds(existing);
        final score = _diveMatcher.calculateMatchScore(
          wearableStartTime: imported.startTime,
          wearableMaxDepth: imported.maxDepth,
          wearableDurationSeconds: imported.durationSeconds,
          existingStartTime: existing.effectiveEntryTime,
          existingMaxDepth: existing.maxDepth ?? 0.0,
          existingDurationSeconds: existingSeconds,
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
                  (imported.durationSeconds - existingSeconds).abs(),
              siteName: existing.site?.name,
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
    bool retainSourceDiveNumbers = false,
    ImportProgressCallback? onProgress,
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
      onProgress?.call(ImportPhase.dives, i + 1, total);
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

  /// Use runtime (total time), not duration (bottom time), to match the
  /// incoming side which uses runtime ?? duration.
  static int _diveSeconds(Dive dive) {
    if (dive.runtime != null) return dive.runtime!.inSeconds;
    if (dive.exitTime != null && dive.entryTime != null) {
      return dive.exitTime!.difference(dive.entryTime!).inSeconds;
    }
    if (dive.bottomTime != null) return dive.bottomTime!.inSeconds;
    return 0;
  }

  static final _dateFormatter = DateFormat('MMM d, yyyy');
  static final _timeFormatter = DateFormat('h:mm a');

  EntityItem _diveToEntityItem(ImportedDive dive) {
    final dateStr = _dateFormatter.format(dive.startTime);
    final timeStr = _timeFormatter.format(dive.startTime);
    final title = '$dateStr \u2014 $timeStr';

    final units = UnitFormatter(_settings);
    final durationMin = dive.duration.inMinutes;
    final tempStr = dive.minTemperature != null
        ? ' \u00b7 ${units.formatTemperature(dive.minTemperature!, decimals: 1)}'
        : '';
    final subtitle =
        '${units.formatDepth(dive.maxDepth)} max \u00b7 $durationMin min$tempStr';

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
