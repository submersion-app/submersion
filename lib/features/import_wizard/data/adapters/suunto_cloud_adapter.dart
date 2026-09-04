import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/domain/models/incoming_dive_data.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_cloud_client.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_dive_parser.dart';
import 'package:submersion/core/services/suunto_cloud/suunto_session_store.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_computer/data/services/dive_import_service.dart';
import 'package:submersion/features/dive_computer/domain/entities/downloaded_dive.dart';
import 'package:submersion/features/dive_import/domain/services/dive_matcher.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart'
    hide DiveMatchResult;
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/domain/services/unreadable_series_exception.dart';
import 'package:submersion/features/import_wizard/data/adapters/cloud_computer_identity.dart';
import 'package:submersion/features/import_wizard/domain/adapters/import_source_adapter.dart';
import 'package:submersion/features/import_wizard/domain/models/duplicate_action.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/import_wizard/domain/models/import_phase.dart';
import 'package:submersion/features/import_wizard/domain/models/import_bundle.dart';
import 'package:submersion/features/import_wizard/domain/models/unified_import_result.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/suunto_cloud_adapter_steps.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/wizard/wizard_step_def.dart';

/// Signals that the sign-in step can advance (a usable session was obtained).
final suuntoCloudSignedInProvider = StateProvider<bool>((ref) => false);

/// The keychain-backed session cache the sign-in step reads and writes.
/// Injected rather than constructed inline so a widget test can supply an
/// in-memory store instead of hitting the platform keychain.
final suuntoSessionStoreProvider = Provider<SuuntoSessionStore>(
  (ref) => SuuntoSessionStore(),
);

/// Builds the client the sign-in step authenticates with. Injected for the
/// same reason as [suuntoSessionStoreProvider]: overriding it keeps a test
/// from ever reaching api.sports-tracker.com.
final suuntoCloudClientFactoryProvider = Provider<SuuntoCloudClient Function()>(
  (ref) => SuuntoCloudClient.new,
);

/// Signals that the fetch step can advance (dives have been downloaded and
/// converted).
final suuntoCloudDivesFetchedProvider = StateProvider<bool>((ref) => false);

/// Outcome of a single `SuuntoCloudAdapter._consolidateDive` call. Mirrors
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

/// Import source adapter for dives pulled from the Suunto cloud
/// (app.suunto.com), via the undocumented Sports-Tracker API.
///
/// Two acquisition steps: sign in (email/password, with a cached-session
/// fast path), then fetch (list + download + convert every scuba/freediving
/// workout). From there this behaves like [DiveComputerAdapter]: dives are
/// converted into [DownloadedDive] so tanks, gas switches, and duplicate/
/// consolidation handling are shared with a real dive-computer download --
/// the only difference is that a single cloud account can span *several*
/// distinct physical computers over the years, so the owning [DiveComputer]
/// is resolved per-dive (by device model + serial number) instead of once
/// per session.
class SuuntoCloudAdapter implements ImportSourceAdapter {
  static final _log = LoggerService.forClass(SuuntoCloudAdapter);

  SuuntoCloudAdapter({
    required DiveImportService importService,
    required DiveComputerRepository computerRepository,
    required DiveRepository diveRepository,
    required DiveConsolidationService consolidationService,
    required String diverId,
    WidgetRef? ref,
  }) : _importService = importService,
       _computerRepository = computerRepository,
       _diveRepository = diveRepository,
       _consolidationService = consolidationService,
       _diverId = diverId,
       _ref = ref;

  final DiveImportService _importService;
  final DiveComputerRepository _computerRepository;
  final DiveRepository _diveRepository;
  final DiveConsolidationService _consolidationService;
  final String _diverId;
  final WidgetRef? _ref;

  List<SuuntoParsedDive> _parsedDives = [];

  /// Resolved/created [DiveComputer] records, keyed by serial number (or by
  /// device model name when no serial was reported).
  final Map<String, DiveComputer> _computersByKey = {};

  /// The authenticated client obtained by the sign-in step, reused by the
  /// fetch step to list and download dives.
  SuuntoCloudClient? _client;

  /// Set by the sign-in step widget once a session has been established
  /// (either from a cached session or a fresh login).
  void setClient(SuuntoCloudClient client) {
    _client = client;
  }

  /// The authenticated client set by the sign-in step. Only meaningful once
  /// the sign-in acquisition step has completed.
  SuuntoCloudClient? get client => _client;

  /// Load the list of fetched+converted dives into this adapter.
  ///
  /// Called internally by the fetch step widget after downloading from the
  /// Suunto cloud.
  void setParsedDives(List<SuuntoParsedDive> dives) {
    _parsedDives = List.unmodifiable(dives);
  }

  // ---------------------------------------------------------------------------
  // ImportSourceAdapter interface
  // ---------------------------------------------------------------------------

  @override
  void resetState() {
    _computersByKey.clear();
    _client = null;
    _parsedDives = [];
    final ref = _ref;
    if (ref == null) return;
    ref.invalidate(suuntoCloudSignedInProvider);
    ref.invalidate(suuntoCloudDivesFetchedProvider);
  }

  @override
  ImportSourceType get sourceType => ImportSourceType.suuntoCloud;

  @override
  String get displayName => 'Suunto Cloud';

  @override
  String get defaultTagName {
    final now = DateTime.now();
    final date =
        '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return 'Suunto Cloud Import $date';
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
  List<WizardStepDef> get acquisitionSteps => [
    WizardStepDef(
      label: 'Sign In',
      icon: Icons.login,
      builder: (context) => SuuntoCloudSignInStep(onSignedIn: setClient),
      canAdvance: suuntoCloudSignedInProvider,
      autoAdvance: true,
    ),
    WizardStepDef(
      label: 'Fetch',
      icon: Icons.cloud_download,
      builder: (context) =>
          SuuntoCloudFetchStep(client: _client, onDivesFetched: setParsedDives),
      canAdvance: suuntoCloudDivesFetchedProvider,
      // Not auto-advance: the fetch step lets the diver move on as soon as
      // the newest page of dives is ready without waiting for the rest of a
      // large account's history, via an explicit Load More button. Auto-
      // advancing on that same canAdvance flip would whisk the diver away
      // the instant it turns true, before they ever see that button.
      autoAdvance: false,
    ),
  ];

  @override
  Future<ImportBundle> buildBundle() async {
    await _ensureComputers();

    final items = _parsedDives.map(_diveToEntityItem).toList();

    return ImportBundle(
      source: ImportSourceInfo(
        type: ImportSourceType.suuntoCloud,
        displayName: displayName,
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
    var skipped = 0;

    for (final index in baseSelections) {
      final action = diveActions[index];
      if (action == DuplicateAction.skip) {
        skipped++;
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
          );
          switch (result.outcome) {
            case _ConsolidateOutcome.consolidated:
              consolidated++;
              importedCountByComputerId[comp.id] =
                  (importedCountByComputerId[comp.id] ?? 0) + 1;
            case _ConsolidateOutcome.keptStandalone:
              // The fold refused, but the download survived as its own dive,
              // so it counts as imported rather than skipped.
              imported++;
              final keptId = result.diveId;
              if (keptId != null) importedDiveIds.add(keptId);
              importedCountByComputerId[comp.id] =
                  (importedCountByComputerId[comp.id] ?? 0) + 1;
            case _ConsolidateOutcome.skippedSameComputer:
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
        }
      } else {
        final diveId = await _importService.importSingleDiveAsNew(
          parsed.dive,
          computerId: comp.id,
          diverId: _diverId,
          descriptorVendor: 'Suunto',
          descriptorProduct: parsed.deviceName,
        );
        imported++;
        importedDiveIds.add(diveId);
        importedCountByComputerId[comp.id] =
            (importedCountByComputerId[comp.id] ?? 0) + 1;
      }

      onProgress?.call(ImportPhase.dives, i + 1, total);
    }

    for (final entry in importedCountByComputerId.entries) {
      await _computerRepository.incrementDiveCount(entry.key, by: entry.value);
      await _computerRepository.updateLastDownload(entry.key);
    }

    scheduleQualityScan(importedDiveIds);

    return UnifiedImportResult(
      importedCounts: {ImportEntityType.dives: imported},
      consolidatedCount: consolidated,
      updatedCount: updated,
      skippedCount: skipped,
      importedDiveIds: importedDiveIds,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers -- dive computer resolution
  // ---------------------------------------------------------------------------

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
    final dive = parsed.dive;
    final localStart = dive.startTime.toLocal();
    final settings = _ref?.read(settingsProvider) ?? const AppSettings();
    final units = UnitFormatter(settings);

    final dateStr = units.formatDate(localStart);
    final timeStr = units.formatTime(localStart);
    final title = '$dateStr — $timeStr';
    final durationMin = dive.duration.inMinutes;
    final tempStr = dive.minTemperature != null
        ? ' · ${units.formatTemperature(dive.minTemperature!, decimals: 1)}'
        : '';
    final subtitle =
        '${units.formatDepth(dive.maxDepth)} max · $durationMin min$tempStr';

    final diveData = IncomingDiveData.fromDownloadedDive(
      dive,
      computer: _computerFor(parsed),
    );

    return EntityItem(title: title, subtitle: subtitle, diveData: diveData);
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
    DiveComputer comp,
  ) async {
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
