import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/features/dive_import/data/services/fit_parser_service.dart';
import 'package:submersion/features/dive_import/domain/entities/imported_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_import/domain/services/imported_dive_converter.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/domain/models/wizard_step_def.dart';

/// Riverpod [StateProvider] signalling whether the FIT file acquisition step
/// has loaded dives and may advance to the review step.
///
/// Set to `true` externally via [FitAdapter.setParsedDives] after files have
/// been parsed and loaded.
final fitAdapterCanAdvanceProvider = StateProvider<bool>((ref) => false);

/// Import source adapter for Garmin FIT files.
///
/// Implements [ImportSourceAdapter] for the unified import wizard. Supports
/// dives only (no sites, equipment, etc.) and duplicate detection via fuzzy
/// matching. The [consolidate] action is not supported — only [skip] and
/// [importAsNew] are available.
///
/// Acquisition (file picking) is handled externally: call [setParsedDives]
/// with the list of [ImportedDive]s produced by [FitParserService] before
/// [buildBundle] is invoked.
class FitAdapter implements ImportSourceAdapter {
  FitAdapter({
    required FitParserService fitParser,
    required DiveMatcher diveMatcher,
    required ImportedDiveConverter converter,
    required DiveRepository diveRepository,
    required String diverId,
    String displayName = 'FIT Import',
  }) : _fitParser = fitParser,
       _diveMatcher = diveMatcher,
       _converter = converter,
       _diveRepository = diveRepository,
       _diverId = diverId,
       _displayName = displayName;

  // ignore: unused_field
  final FitParserService _fitParser;
  final DiveMatcher _diveMatcher;
  final ImportedDiveConverter _converter;
  final DiveRepository _diveRepository;
  final String _diverId;
  final String _displayName;

  List<ImportedDive> _parsedDives = [];

  /// Load the list of already-parsed [ImportedDive]s into this adapter.
  ///
  /// Must be called before [buildBundle]. The actual file-picking UI is
  /// provided by the [acquisitionSteps] placeholder; the parsed dives are
  /// set here to decouple file I/O from the adapter logic.
  void setParsedDives(List<ImportedDive> dives) {
    _parsedDives = List.unmodifiable(dives);
  }

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  ImportSourceType get sourceType => ImportSourceType.fit;

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
      label: 'Select Files',
      icon: Icons.file_open,
      builder: (context) => const _FitAcquisitionPlaceholder(),
      canAdvance: fitAdapterCanAdvanceProvider,
    ),
  ];

  @override
  Future<ImportBundle> buildBundle() async {
    final items = _parsedDives.map(_diveToEntityItem).toList();

    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.fit,
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

    for (var i = 0; i < sortedIndices.length; i++) {
      final index = sortedIndices[i];

      if (index >= _parsedDives.length) continue;

      final importedDive = _parsedDives[index];
      final dive = _converter.convert(importedDive, diverId: _diverId);
      await _diveRepository.createDive(dive);

      imported++;
      onProgress?.call('Dives', i + 1, total);
    }

    return UnifiedImportResult(
      importedCounts: {ImportEntityType.dives: imported},
      consolidatedCount: 0,
      skippedCount: skipped,
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

/// Placeholder widget for the FIT file acquisition step.
///
/// The actual file picker UI will be extracted from [FitImportPage] during
/// route integration (Task 11). For now this serves as a non-null widget so
/// the wizard can render the step.
class _FitAcquisitionPlaceholder extends StatelessWidget {
  const _FitAcquisitionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Select FIT files to import.'));
  }
}
