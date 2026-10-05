import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/import_wizard/data/adapters/cloud_computer_identity.dart';
import 'package:submersion/features/import_wizard/data/adapters/dive_number_conflict_notice.dart';
import 'package:submersion/features/import_wizard/data/adapters/suunto_route_writer.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/downloaded_dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Outcome of a single `SuuntoDiveImportCore._consolidateDive` call. Mirrors
/// `DiveComputerAdapter`'s outcome type -- see that class for the rationale.
enum _ConsolidateOutcome {
  consolidated,
  skippedSameComputer,
  keptStandalone,
  failed,
}

/// What a `_consolidateDive` call did, plus the id of the standalone dive it
/// left behind (only [_ConsolidateOutcome.keptStandalone] leaves one).
typedef _ConsolidateResult = ({_ConsolidateOutcome outcome, String? diveId});

/// The import pipeline shared by every Suunto source: the Suunto Cloud
/// account import (`SuuntoCloudAdapter`) and the Suunto app JSON file
/// import (`SuuntoFileAdapter`). Subclasses supply only how dives are
/// acquired; everything after that lives here.
///
/// Dives are converted into [DownloadedDive] so tanks, gas switches, and
/// duplicate/consolidation handling are shared with a real dive-computer
/// download. One Suunto source can span *several* distinct physical
/// computers, so the owning [DiveComputer] is resolved per dive (by device
/// model + serial number) instead of once per session. A dive's recorded
/// route (DiveRoute, issue #1445) is linked to whichever dive each write
/// path settles on, through [SuuntoRouteWriter].
abstract class SuuntoDiveImportCore implements ImportSourceAdapter {
  static final _log = LoggerService.forClass(SuuntoDiveImportCore);

  SuuntoDiveImportCore({
    required DiveImportService importService,
    required DiveComputerRepository computerRepository,
    required DiveRepository diveRepository,
    required DiveConsolidationService consolidationService,
    required String diverId,
    SuuntoRouteWriter? routeWriter,
    WidgetRef? ref,
  }) : _importService = importService,
       _computerRepository = computerRepository,
       _diveRepository = diveRepository,
       _consolidationService = consolidationService,
       _diverId = diverId,
       _routeWriter = routeWriter ?? SuuntoRouteWriter(),
       _ref = ref;

  final DiveImportService _importService;
  final DiveComputerRepository _computerRepository;
  final DiveRepository _diveRepository;
  final DiveConsolidationService _consolidationService;
  final String _diverId;
  final SuuntoRouteWriter _routeWriter;
  final WidgetRef? _ref;

  List<SuuntoParsedDive> _parsedDives = [];

  /// Resolved/created [DiveComputer] records, keyed by serial number (or by
  /// device model name when no serial was reported).
  final Map<String, DiveComputer> _computersByKey = {};

  /// The wizard's ref, for subclasses that reset their own step providers.
  @protected
  WidgetRef? get ref => _ref;

  /// The signed-in account shown on the Review step, for a source that has
  /// one (the cloud import); null otherwise.
  @protected
  String? get sourceAccount => null;

  /// How many files the dives were read from, for a file source; null for
  /// the cloud import.
  @protected
  int? get sourceFileCount => null;

  /// Today's date as yyyy-mm-dd, for [defaultTagName].
  @protected
  String todayIsoDate() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// Load the acquired and converted dives into this adapter. Called by the
  /// subclass's acquisition step once it has them.
  void setParsedDives(List<SuuntoParsedDive> dives) {
    _parsedDives = List.unmodifiable(dives);
  }

  @override
  @mustCallSuper
  void resetState() {
    _computersByKey.clear();
    _parsedDives = [];
  }

  @override
  Set<DuplicateAction> get supportedDuplicateActions => const {
    DuplicateAction.skip,
    DuplicateAction.importAsNew,
    DuplicateAction.consolidate,
    DuplicateAction.replaceSource,
  };

  /// A Suunto cloud import only ever produces dives, so there is no entity
  /// type that needs a narrower set than the adapter-wide one.
  @override
  Set<DuplicateAction> duplicateActionsFor(ImportEntityType type) =>
      supportedDuplicateActions;

  @override
  Future<ImportBundle> buildBundle() async {
    await _ensureComputers();

    final items = _parsedDives.map(_diveToEntityItem).toList();

    return ImportBundle(
      source: ImportSourceInfo(
        type: sourceType,
        displayName: displayName,
        details: ImportSourceDetails(
          account: sourceAccount,
          fileCount: sourceFileCount,
          deviceModels: _deviceModels(),
        ),
      ),
      groups: {ImportEntityType.dives: EntityGroup(items: items)},
    );
  }

  @override
  Future<ImportBundle> checkDuplicates(ImportBundle bundle) async {
    final diveGroup = bundle.groups[ImportEntityType.dives];
    if (diveGroup == null || diveGroup.items.isEmpty) return bundle;

    final duplicateIndices = <int>{};
    final matchResults = <int, DiveMatchResult>{};

    final sourceKeysCache = await _diveRepository.getSourceKeysByDiveId(
      diverId: _diverId,
    );

    for (var i = 0; i < _parsedDives.length; i++) {
      final result = await _importService.detectDuplicate(
        _parsedDives[i].dive,
        diverId: _diverId,
        sourceKeysCache: sourceKeysCache,
      );

      if (result.isDuplicate && result.score >= 0.5) {
        duplicateIndices.add(i);
        final matchedComputerId = await _diveRepository.getComputerIdForDive(
          result.matchingDiveId!,
        );
        matchResults[i] = DiveMatchResult(
          diveId: result.matchingDiveId!,
          score: result.score,
          timeDifferenceMs: (result.timeDifferenceSeconds ?? 0) * 1000,
          depthDifferenceMeters: result.depthDifferenceMeters,
          durationDifferenceSeconds: null,
          matchedComputerId: matchedComputerId,
          matchedExistingSource: result.matchedExistingSource,
        );
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
    ImportCancellationToken? cancelToken,
  }) async {
    final baseSelections = Set<int>.from(
      selections[ImportEntityType.dives] ?? <int>{},
    );
    final diveActions = duplicateActions[ImportEntityType.dives] ?? {};

    final indicesToImport = <int>{};
    final indicesToConsolidate = <int>{};
    final indicesToReplaceSource = <int>{};
    final indicesToSkip = <int>{};
    var skipped = 0;

    for (final index in baseSelections) {
      final action = diveActions[index];
      if (action == DuplicateAction.skip) {
        skipped++;
        indicesToSkip.add(index);
      } else if (action == DuplicateAction.consolidate) {
        indicesToConsolidate.add(index);
      } else if (action == DuplicateAction.replaceSource) {
        indicesToReplaceSource.add(index);
      } else {
        indicesToImport.add(index);
      }
    }

    for (final entry in diveActions.entries) {
      if (entry.value == DuplicateAction.importAsNew) {
        indicesToImport.add(entry.key);
      } else if (entry.value == DuplicateAction.consolidate &&
          !baseSelections.contains(entry.key)) {
        indicesToConsolidate.add(entry.key);
      } else if (entry.value == DuplicateAction.replaceSource &&
          !baseSelections.contains(entry.key)) {
        indicesToReplaceSource.add(entry.key);
      } else if (entry.value == DuplicateAction.skip &&
          !baseSelections.contains(entry.key)) {
        skipped++;
        indicesToSkip.add(entry.key);
      }
    }

    // Merge and sort by startTime (oldest first) so sequential dive number
    // assignment produces correct chronological numbering.
    final allIndices =
        {
          ...indicesToImport,
          ...indicesToConsolidate,
          ...indicesToReplaceSource,
        }.toList()..sort((a, b) {
          final aTime = _parsedDives[a].dive.startTime;
          final bTime = _parsedDives[b].dive.startTime;
          return aTime.compareTo(bTime);
        });
    final total = allIndices.length;
    var imported = 0;
    var consolidated = 0;
    var updated = 0;
    final importedCountByComputerId = <String, int>{};
    final importedDiveIds = <String>[];

    for (var i = 0; i < allIndices.length; i++) {
      if (cancelToken?.isCancelled ?? false) break;

      final index = allIndices[i];
      if (index >= _parsedDives.length) continue;

      final parsed = _parsedDives[index];
      final comp = await _resolveComputer(parsed);

      if (indicesToConsolidate.contains(index)) {
        final diveGroup = bundle.groups[ImportEntityType.dives];
        final matchResult = diveGroup?.matchResults?[index];
        if (matchResult != null) {
          final result = await _consolidateDive(
            parsed,
            matchResult.diveId,
            comp,
            // A dive the fold refuses is kept standalone, so it must carry
            // the same number an import-as-new would have given it.
            retainSourceDiveNumber: retainSourceDiveNumbers,
          );
          switch (result.outcome) {
            case _ConsolidateOutcome.consolidated:
              consolidated++;
              importedCountByComputerId[comp.id] =
                  (importedCountByComputerId[comp.id] ?? 0) + 1;
              // The fold keeps the target's own header, so the notes go onto
              // the target, not the folded-away download.
              await _fillNotes(matchResult.diveId, parsed);
              await _routeWriter.attach(matchResult.diveId, parsed);
            case _ConsolidateOutcome.keptStandalone:
              // The fold refused, but the download survived as its own dive,
              // so it counts as imported rather than skipped.
              imported++;
              final keptId = result.diveId;
              if (keptId != null) {
                importedDiveIds.add(keptId);
                await _fillNotes(keptId, parsed);
                await _routeWriter.attach(keptId, parsed);
              }
              importedCountByComputerId[comp.id] =
                  (importedCountByComputerId[comp.id] ?? 0) + 1;
            case _ConsolidateOutcome.skippedSameComputer:
              skipped++;
              // The same computer's reading is already that dive; only a
              // route it never had is worth bringing over.
              await _routeWriter.attachIfMissing(matchResult.diveId, parsed);
            case _ConsolidateOutcome.failed:
              skipped++;
          }
        }
      } else if (indicesToReplaceSource.contains(index)) {
        final diveGroup = bundle.groups[ImportEntityType.dives];
        final matchResult = diveGroup?.matchResults?[index];
        if (matchResult != null) {
          final conflict = ImportConflict(
            downloaded: parsed.dive,
            existingDiveId: matchResult.diveId,
            duplicateResult: DuplicateResult(
              matchingDiveId: matchResult.diveId,
              confidence: DuplicateConfidence.exact,
              score: matchResult.score,
            ),
          );
          await _importService.resolveConflict(
            conflict,
            ConflictResolution.replaceSource,
            comp.id,
            diverId: _diverId,
            descriptorVendor: 'Suunto',
            descriptorProduct: parsed.deviceName,
          );
          updated++;
          await _fillNotes(matchResult.diveId, parsed);
          await _routeWriter.attach(matchResult.diveId, parsed);
        }
      } else {
        final diveId = await _importService.importSingleDiveAsNew(
          parsed.dive,
          computerId: comp.id,
          diverId: _diverId,
          descriptorVendor: 'Suunto',
          descriptorProduct: parsed.deviceName,
          retainSourceDiveNumber: retainSourceDiveNumbers,
        );
        imported++;
        importedDiveIds.add(diveId);
        await _fillNotes(diveId, parsed);
        await _routeWriter.attach(diveId, parsed);
        importedCountByComputerId[comp.id] =
            (importedCountByComputerId[comp.id] ?? 0) + 1;
      }

      onProgress?.call(ImportPhase.dives, i + 1, total);
    }

    // Skip leaves the matched dive untouched, but a dive imported before
    // routes were read gains its route here rather than only through
    // Replace source, which would rewrite the dive (issue #1445).
    final matchResults = bundle.groups[ImportEntityType.dives]?.matchResults;
    for (final index in indicesToSkip) {
      if (cancelToken?.isCancelled ?? false) break;
      final match = matchResults?[index];
      if (match == null || index >= _parsedDives.length) continue;
      await _routeWriter.attachIfMissing(match.diveId, _parsedDives[index]);
    }

    for (final entry in importedCountByComputerId.entries) {
      await _computerRepository.incrementDiveCount(entry.key, by: entry.value);
      await _computerRepository.updateLastDownload(entry.key);
    }

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
      consolidatedCount: consolidated,
      updatedCount: updated,
      skippedCount: skipped,
      importedDiveIds: importedDiveIds,
      notices: [?numberConflict],
    );
  }

  /// Brings the notes the diver wrote in the Suunto app onto [diveId]
  /// (issue #2410), only where the dive has none, so nothing written in
  /// Submersion is overwritten.
  ///
  /// The dive itself is already saved by now, so a failure here is logged
  /// rather than thrown: losing the notes must not fail the import or stop
  /// the dives after this one.
  Future<void> _fillNotes(String diveId, SuuntoParsedDive parsed) async {
    final notes = parsed.notes;
    if (notes == null) return;
    try {
      await _diveRepository.fillNotesIfEmpty(diveId, notes);
    } catch (e, st) {
      _log.error(
        'Could not bring Suunto notes onto dive $diveId',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers -- dive computer resolution
  // ---------------------------------------------------------------------------

  /// The models of the devices that recorded the read dives, each once,
  /// in the order the dives list them.
  List<String> _deviceModels() => {
    for (final parsed in _parsedDives)
      ?normalizedIdentityPart(parsed.deviceName),
  }.toList();

  Future<void> _ensureComputers() async {
    for (final parsed in _parsedDives) {
      await _resolveComputer(parsed);
    }
  }

  String _computerCacheKey(SuuntoParsedDive parsed) =>
      normalizedIdentityPart(parsed.serialNumber) ??
      normalizedIdentityPart(parsed.deviceName) ??
      'Suunto';

  DiveComputer? _computerFor(SuuntoParsedDive parsed) =>
      _computersByKey[_computerCacheKey(parsed)];

  /// Finds or creates the [DiveComputer] record for [parsed]'s reporting
  /// device, matching on hardware identity (manufacturer/model/serial) the
  /// same way [DiveComputerAdapter.ensureComputer] does for a freshly
  /// discovered BLE/USB device.
  Future<DiveComputer> _resolveComputer(SuuntoParsedDive parsed) async {
    final cacheKey = _computerCacheKey(parsed);
    final cached = _computersByKey[cacheKey];
    if (cached != null) return cached;

    final model = normalizedIdentityPart(parsed.deviceName) ?? 'Suunto';
    final serial = normalizedIdentityPart(parsed.serialNumber);

    if (serial != null) {
      final existing = await _computerRepository.findByHardwareIdentity(
        manufacturer: 'Suunto',
        model: model,
        serialNumber: serial,
        diverId: _diverId,
      );
      if (existing != null) {
        _computersByKey[cacheKey] = existing;
        return existing;
      }
    }

    final created = await _computerRepository.createComputer(
      DiveComputer.create(
        id: const Uuid().v4(),
        name: model,
        diverId: _diverId,
        manufacturer: 'Suunto',
        model: model,
      ).copyWith(
        serialNumber: serial,
        firmwareVersion: normalizedIdentityPart(parsed.firmwareVersion),
        connectionType: 'cloud',
      ),
    );
    _computersByKey[cacheKey] = created;
    return created;
  }

  // ---------------------------------------------------------------------------
  // Helpers -- entity item conversion
  // ---------------------------------------------------------------------------

  EntityItem _diveToEntityItem(SuuntoParsedDive parsed) {
    final settings = _ref?.read(settingsProvider) ?? const AppSettings();
    final summary = formatDownloadedDiveSummary(parsed.dive, settings);

    final diveData = IncomingDiveData.fromDownloadedDive(
      parsed.dive,
      computer: _computerFor(parsed),
    );

    return EntityItem(
      title: summary.title,
      subtitle: summary.subtitle,
      diveData: diveData,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers -- consolidation
  // ---------------------------------------------------------------------------

  /// Consolidate a downloaded dive as a secondary computer reading on an
  /// existing dive. Mirrors `DiveComputerAdapter._consolidateDive` -- see
  /// that method's doc comment for the failure modes it guards against.
  Future<_ConsolidateResult> _consolidateDive(
    SuuntoParsedDive parsed,
    String targetDiveId,
    DiveComputer comp, {
    required bool retainSourceDiveNumber,
  }) async {
    final targetComputerId = await _diveRepository.getComputerIdForDive(
      targetDiveId,
    );
    if (targetComputerId != null && targetComputerId == comp.id) {
      return (outcome: _ConsolidateOutcome.skippedSameComputer, diveId: null);
    }

    String? newDiveId;
    try {
      newDiveId = await _importService.importSingleDiveAsNew(
        parsed.dive,
        computerId: comp.id,
        diverId: _diverId,
        descriptorVendor: 'Suunto',
        descriptorProduct: parsed.deviceName,
        retainSourceDiveNumber: retainSourceDiveNumber,
      );
      await _consolidationService.apply(
        targetDiveId: targetDiveId,
        secondaryDiveIds: [newDiveId],
      );
      return (outcome: _ConsolidateOutcome.consolidated, diveId: newDiveId);
    } on UnreadableSeriesException catch (e) {
      // The refusal is about the PRE-EXISTING target dive's stored series,
      // not about this download, so the download is kept as its own dive
      // instead of being compensated away.
      final keptId = newDiveId;
      if (keptId != null) {
        _log.warning(
          'Kept downloaded dive $keptId standalone instead of folding it '
          'into $targetDiveId: that dive holds ${e.seriesIds.length} '
          'series this build cannot decode',
        );
        return (outcome: _ConsolidateOutcome.keptStandalone, diveId: keptId);
      }
      // Nothing was imported, so there is nothing to keep or compensate.
      _log.error('Consolidation fold refused for $targetDiveId', error: e);
      return (outcome: _ConsolidateOutcome.failed, diveId: null);
    } catch (e, st) {
      _log.error(
        'Consolidation fold failed for dive into $targetDiveId',
        error: e,
        stackTrace: st,
      );
      if (newDiveId != null) {
        try {
          await _diveRepository.bulkDeleteDives([newDiveId]);
        } catch (deleteError, deleteStack) {
          // The compensating delete failed too; fall through rather than
          // rethrow, so the import loop still processes the remaining dives
          // instead of aborting on a stranded standalone dive.
          _log.error(
            'Compensating delete failed for orphaned dive $newDiveId',
            error: deleteError,
            stackTrace: deleteStack,
          );
        }
      }
      return (outcome: _ConsolidateOutcome.failed, diveId: null);
    }
  }
}
