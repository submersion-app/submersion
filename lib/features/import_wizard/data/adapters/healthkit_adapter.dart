import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/domain/services/dive_altitude_enricher.dart';
import 'package:submersion/features/equipment/data/services/dive_computer_gear_linker.dart';
import 'package:submersion/features/equipment/data/services/equipment_set_for_computer_linker.dart';
import 'package:submersion/features/equipment/data/services/dive_equipment_defaulter.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/pre_dive/data/services/checklist_dive_linker.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/health_import_service.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/data/adapters/apple_watch_wall_clock_repair.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_number_conflict_notice.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';
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
    ChecklistDiveLinker? checklistLinker,
  }) : _healthService = healthService,
       _diveMatcher = diveMatcher,
       _converter = converter,
       _diveRepository = diveRepository,
       _diverId = diverId,
       _ref = ref,
       _settings = settings,
       _displayName = displayName,
       _checklistLinker = checklistLinker;

  final HealthImportService _healthService;
  final DiveMatcher _diveMatcher;
  final ImportedDiveConverter _converter;
  final DiveRepository _diveRepository;
  final String _diverId;
  final WidgetRef? _ref;
  final AppSettings _settings;
  final String _displayName;
  final ChecklistDiveLinker? _checklistLinker;

  List<ImportedDive> _parsedDives = [];

  /// The date range the fetch read, shown on the Review step (issue #161).
  DateTimeRange? _fetchedRange;

  /// Saved dives found by [checkDuplicates] still holding the instant the
  /// import saved before #2811, by dive id, with the shift to their wall
  /// clock and the start it moves to. [performImport] applies them (issue
  /// #2812).
  Map<String, ({Duration shift, DateTime correctedStart})> _timeCorrections =
      const {};

  /// Load the list of fetched [ImportedDive]s into this adapter, with the
  /// date [range] they were fetched for.
  ///
  /// Called internally by the Fetch step widget after fetching from HealthKit.
  void setParsedDives(List<ImportedDive> dives, {DateTimeRange? range}) {
    _parsedDives = List.unmodifiable(dives);
    _fetchedRange = range;
    _timeCorrections = const {};
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

  /// HealthKit only produces dives, so every tab gets the adapter-wide set.
  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;

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
          setParsedDives(dives, range: _ref?.read(healthKitDateRangeProvider));
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
        details: ImportSourceDetails(
          title: 'Apple Health',
          rangeStart: _fetchedRange?.start,
          rangeEnd: _fetchedRange?.end,
        ),
      ),
      groups: {ImportEntityType.dives: EntityGroup(items: items)},
    );
  }

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    _timeCorrections = const {};
    final diveGroup = bundle.groups[ImportEntityType.dives];
    if (diveGroup == null || diveGroup.items.isEmpty) return bundle;

    final existingDives = await _diveRepository.getAllDives(diverId: _diverId);

    final duplicateIndices = <int>{};
    final matchResults = <int, DiveMatchResult>{};
    final timeCorrections =
        <String, ({Duration shift, DateTime correctedStart})>{};
    final savedByWorkout = existingDives
        .where((dive) => dive.importSource == 'appleWatch')
        .groupListsBy((dive) => dive.importId);
    // A saved dive another fetched workout claims is that workout's dive, and
    // may be about to move, so the time-based pass never offers it to a
    // different workout that happens to start at its old time.
    final claimedIds = {
      for (final imported in _parsedDives)
        for (final saved in savedByWorkout[imported.sourceId] ?? const <Dive>[])
          saved.id,
    };
    final unclaimedDives = existingDives
        .where((dive) => !claimedIds.contains(dive.id))
        .toList();

    for (var i = 0; i < _parsedDives.length; i++) {
      final imported = _parsedDives[i];

      // The same workout is the same dive, however far apart the times: a
      // dive saved before #2811 sits a UTC offset away, too far for the
      // time-based score below to recognize it (issue #2812). Every saved
      // copy is corrected, in case the workout was imported as new twice.
      final sameWorkout = savedByWorkout[imported.sourceId];
      if (sameWorkout != null) {
        for (final saved in sameWorkout) {
          final shift = appleWatchWallClockShift(saved, imported);
          if (shift != null) {
            timeCorrections[saved.id] = (
              shift: shift,
              correctedStart: saved.effectiveEntryTime.add(shift),
            );
          }
        }
        final first = sameWorkout.first;
        duplicateIndices.add(i);
        matchResults[i] = _matchResult(
          imported,
          first,
          score: 1.0,
          existingStart:
              timeCorrections[first.id]?.correctedStart ??
              first.effectiveEntryTime,
          // A re-read of a workout the log already holds: the wizard
          // defaults it to skip instead of asking about each one.
          matchedExistingSource: true,
        );
        continue;
      }

      DiveMatchResult? bestMatch;

      for (final existing in unclaimedDives) {
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
            bestMatch = _matchResult(
              imported,
              existing,
              score: score,
              existingStart: existing.effectiveEntryTime,
            );
          }
        }
      }

      if (bestMatch != null) {
        duplicateIndices.add(i);
        matchResults[i] = bestMatch;
      }
    }

    _timeCorrections = Map.unmodifiable(timeCorrections);
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
    ImportCancellationToken? cancelToken,
  }) async {
    // Whatever the diver picks for the duplicate, the saved dive's time is
    // wrong, so it is corrected either way.
    final timesCorrected = await _applyTimeCorrections();

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

    // Oldest first, so auto-numbering follows the order the dives happened
    // in rather than the order the review list happened to show them.
    final sortedIndices =
        indicesToImport.where((i) => i < _parsedDives.length).toList()
          ..sort((a, b) {
            final byTime = _parsedDives[a].startTime.compareTo(
              _parsedDives[b].startTime,
            );
            return byTime != 0 ? byTime : a.compareTo(b);
          });
    final total = sortedIndices.length;
    var imported = 0;
    final importedDiveIds = <String>[];

    // One instance for the run: its lookup cache collapses a batch of dives
    // at the same location into a single elevation request.
    final altitudeEnricher = DiveAltitudeEnricher();
    final checklistLinker = _checklistLinker ?? ChecklistDiveLinker();

    for (var i = 0; i < sortedIndices.length; i++) {
      if (cancelToken?.isCancelled ?? false) break;

      final importedDive = _parsedDives[sortedIndices[i]];
      // HealthKit records no dive number of its own, but honour one if the
      // source ever supplies it; otherwise number the dive like every other
      // import does (issue #1832).
      final diveNumber =
          (retainSourceDiveNumbers ? importedDive.diveNumber : null) ??
          await _diveRepository.getNextDiveNumber(diverId: _diverId);
      final dive = _converter.convert(
        importedDive,
        diverId: _diverId,
        diveNumber: diveNumber,
      );
      await _diveRepository.createDive(dive);
      await DiveEquipmentDefaulter().applyForImportedDive(dive);
      await checklistLinker.applyForImportedDive(dive);
      await altitudeEnricher.applyForImportedDive(dive);
      // After the defaulter, never before: the defaulter bails on a dive
      // that already has equipment, so linking first would suppress the
      // diver's default and geofenced sets.
      await DiveComputerGearLinker().linkComputerGearForDive(diveId: dive.id);
      // Apply every equipment set that lists this computer as a member
      // (issue #1020). Additive, independent of the defaulter above.
      await EquipmentSetForComputerLinker().linkComputerSetsForDive(
        diveId: dive.id,
      );

      imported++;
      importedDiveIds.add(dive.id);
      onProgress?.call(ImportPhase.dives, i + 1, total);
    }

    // Queue a data-quality scan of the imported dives (fire-and-forget).
    scheduleQualityScan(importedDiveIds);
    scheduleSensorSummaryRefresh(importedDiveIds);
    scheduleDerivedMetricsRefresh(importedDiveIds);

    final numberConflict = await diveNumberConflictNotice(
      retainSourceDiveNumbers: retainSourceDiveNumbers,
      diveRepository: _diveRepository,
      importedDiveIds: importedDiveIds,
    );
    return UnifiedImportResult(
      importedCounts: {ImportEntityType.dives: imported},
      consolidatedCount: 0,
      timesCorrectedCount: timesCorrected,
      skippedCount: skipped,
      importedDiveIds: importedDiveIds,
      notices: [?numberConflict],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Move the saved dives [checkDuplicates] found to their wall clock and
  /// return how many moved. Taken before the write, so a second run of the
  /// same review cannot shift them again.
  Future<int> _applyTimeCorrections() async {
    final corrections = _timeCorrections;
    _timeCorrections = const {};
    // One write per offset: dives either side of a DST change differ.
    final idsByShift = corrections.keys.groupListsBy(
      (id) => corrections[id]!.shift,
    );
    for (final MapEntry(key: shift, value: ids) in idsByShift.entries) {
      await _diveRepository.shiftDiveTimes(ids, shift);
    }
    // Checklist runs were linked against the shifted start when the dive was
    // first imported; link them again against the corrected one. Best-effort,
    // as on import.
    final linker = _checklistLinker ?? ChecklistDiveLinker();
    for (final MapEntry(key: diveId, value: correction)
        in corrections.entries) {
      await linker.autoLinkForDive(
        diveId: diveId,
        diverId: _diverId,
        diveStart: correction.correctedStart,
      );
    }
    return corrections.length;
  }

  DiveMatchResult _matchResult(
    ImportedDive imported,
    Dive existing, {
    required double score,
    required DateTime existingStart,
    bool matchedExistingSource = false,
  }) {
    return DiveMatchResult(
      diveId: existing.id,
      score: score,
      timeDifferenceMs: imported.startTime
          .difference(existingStart)
          .inMilliseconds
          .abs(),
      depthDifferenceMeters: (imported.maxDepth - (existing.maxDepth ?? 0.0))
          .abs(),
      durationDifferenceSeconds:
          (imported.durationSeconds - _diveSeconds(existing)).abs(),
      siteName: existing.site?.name,
      matchedExistingSource: matchedExistingSource,
    );
  }

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

  EntityItem _diveToEntityItem(ImportedDive dive) {
    final units = UnitFormatter(_settings);

    final dateStr = units.formatDate(dive.startTime);
    final timeStr = units.formatTime(dive.startTime);
    final title = '$dateStr \u2014 $timeStr';
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
      diveNumber: dive.diveNumber,
    );

    return EntityItem(title: title, subtitle: subtitle, diveData: diveData);
  }
}
