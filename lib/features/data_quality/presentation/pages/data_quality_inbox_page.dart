import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/data/services/diver_data_query.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/data_quality/data/services/profile_repair_service.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_inbox_providers.dart';
import 'package:submersion/features/data_quality/presentation/widgets/delete_duplicate_dialog.dart';
import 'package:submersion/features/data_quality/presentation/widgets/dive_identity_label.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_card.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_unit_formatters.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/reassign_tank_picker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/combine_dives_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

QualityUnitFormatters buildQualityUnitFormatters(WidgetRef ref) =>
    qualityUnitFormattersFor(UnitFormatter(ref.watch(settingsProvider)));

typedef _DiveGroup = ({String diveId, List<QualityFinding> findings});

List<_DiveGroup> _groupByDive(List<QualityFinding> findings) {
  // findings arrive ordered by updatedAt (not diveId), so a dive's findings
  // can be interleaved with others. Accumulate by diveId in a map (insertion
  // order = each dive's newest finding) so every dive gets exactly one header.
  final byDive = <String, List<QualityFinding>>{};
  for (final f in findings) {
    (byDive[f.diveId] ??= []).add(f);
  }
  return [
    for (final entry in byDive.entries)
      (diveId: entry.key, findings: entry.value),
  ];
}

class DataQualityInboxPage extends ConsumerStatefulWidget {
  const DataQualityInboxPage({super.key, this.filterDiveId});

  /// Comma-separated set of dive ids to scope the inbox to (deep link from
  /// dive detail with one id, or the import summary with the whole imported
  /// set). When null/empty, all findings are shown.
  final String? filterDiveId;

  @override
  ConsumerState<DataQualityInboxPage> createState() =>
      _DataQualityInboxPageState();
}

class _DataQualityInboxPageState extends ConsumerState<DataQualityInboxPage> {
  /// Material's own SnackBar default, restated because the framework keeps
  /// the constant private.
  static const Duration _defaultUndoWindow = Duration(seconds: 4);

  /// The window a repair that deletes a dive gets instead. Undo is the only
  /// way back from it, and a diver working through a batch of findings has
  /// dismissed the snackbar and moved on well before four seconds are up
  /// (#1729).
  static const Duration _destructiveUndoWindow = Duration(seconds: 10);

  ({int done, int total})? _scanProgress;
  bool _cancelRequested = false;

  Future<void> _runFullScan() async {
    setState(() {
      _scanProgress = (done: 0, total: 0);
      _cancelRequested = false;
    });
    final service = ref.read(qualityScanServiceProvider);
    final store = ref.read(qualityScanStateStoreProvider);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final summary = await service.scanLibrary(
        onProgress: (done, total) {
          if (mounted) {
            setState(() => _scanProgress = (done: done, total: total));
          }
        },
        isCancelled: () => _cancelRequested,
      );
      await store.recordFullScan(DateTime.now(), qualityDetectorVersions());
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            summary.detectorErrors > 0
                ? '${l10n.dataQuality_scan_done(summary.findingsProduced)} '
                      '${l10n.dataQuality_scan_errors(summary.detectorErrors)}'
                : l10n.dataQuality_scan_done(summary.findingsProduced),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanProgress = null);
    }
  }

  /// [identityOf] names a dive the way the page's headers do; it comes from
  /// build, where the identity lookup is already watched, so a confirmation
  /// can name both dives of a pair without a second read.
  Future<void> _runAction(
    QualityFinding f,
    QualityRepairAction action, {
    required DiveIdentityLabel? Function(String? diveId) identityOf,
  }) async {
    final executor = QualityRepairExecutor();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    Future<void> withUndo(
      Future<RepairResult> Function() run, {
      Duration undoWindow = _defaultUndoWindow,
    }) async {
      try {
        final result = await run();
        final undo = result.undo;
        messenger.showSnackBar(
          SnackBar(
            duration: undoWindow,
            content: Text(
              result.changed
                  ? l10n.dataQuality_repair_applied
                  : l10n.dataQuality_repair_noChange,
            ),
            action: undo == null
                ? null
                : SnackBarAction(
                    label: l10n.dataQuality_action_undo,
                    onPressed: () => unawaited(undo()),
                  ),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('${l10n.dataQuality_repair_failed}: $e')),
        );
      }
    }

    switch (action) {
      case TimeShiftRepair(:final suggestedOffset, :final offerImportWide):
        final choice = await showTimeShiftSheet(
          context,
          suggestedOffset: suggestedOffset,
          offerImportWide: offerImportWide,
        );
        if (choice == null) return;
        final ids = choice.importWide
            ? await executor.divesInSameImport(f.diveId)
            : [f.diveId];
        await withUndo(
          () => executor.shiftTimes(
            diveIds: ids,
            offset: choice.offset,
            findingId: f.id,
          ),
        );
      case ConsolidateDuplicateRepair(:final diveIds):
        // The dialog owns the survivor choice, and runDiveConsolidation
        // queues the rescan once apply has resolved. Queueing one here on
        // return would scan the pre-merge rows: the dialog pops before the
        // merge completes.
        await showCombineDivesDialog(
          context: context,
          diveIds: diveIds,
          consolidateOnly: true,
        );
      case DeleteDuplicateRepair(:final keepDiveId, :final deleteDiveId):
        // Destructive, so it names both dives, says what the copy it deletes
        // carries, and waits for an explicit yes before the executor writes
        // anything. The counts are read here rather than in build: one dive,
        // once, on the tap that could lose it.
        final carries = await DiverDataQuery().forDive(deleteDiveId);
        if (!mounted) return;
        final confirmed = await showDeleteDuplicateDialog(
          context,
          keep: identityOf(keepDiveId),
          delete: identityOf(deleteDiveId),
          carries: carries,
        );
        if (confirmed != true) return;
        await withUndo(
          () => executor.deleteDuplicate(
            keepDiveId: keepDiveId,
            deleteDiveId: deleteDiveId,
            findingId: f.id,
          ),
          undoWindow: _destructiveUndoWindow,
        );
      case CombineSplitRepair(:final diveIds):
        await showCombineDivesDialog(context: context, diveIds: diveIds);
        scheduleQualityScan(diveIds);
      case SetPrimarySourceRepair(:final diveId, :final sourceId):
        await withUndo(
          () => executor.setPrimarySource(
            diveId: diveId,
            sourceId: sourceId,
            findingId: f.id,
          ),
        );
      case SplitSourceRepair(:final diveId, :final sourceId):
        // Split does not return a RepairResult, so withUndo cannot wrap it.
        // It still has to report a failure: it refuses a source that no
        // longer belongs to the dive, and a dive whose stored series this
        // build cannot decode. Left unwrapped, the tap did nothing visible
        // and the finding stayed open forever.
        try {
          final newId = await ref
              .read(diveSplitServiceProvider)
              .split(diveId: diveId, sourceId: sourceId);
          scheduleQualityScan([diveId, newId]);
        } catch (e) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.diveLog_sources_splitFailed)),
          );
        }
      case DespikeRepair(:final diveId):
        await withUndo(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: ProfileRepairService.despike,
          ),
        );
      case SmoothRatesRepair(:final diveId):
        await withUndo(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: ProfileRepairService.smoothImpossibleRates,
          ),
        );
      case ClampNegativeDepthsRepair(:final diveId):
        await withUndo(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: ProfileRepairService.clampNegativeDepths,
          ),
        );
      case FillGapsRepair(:final diveId):
        await withUndo(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: ProfileRepairService.fillGaps,
          ),
        );
      case SmoothTemperatureRepair(:final diveId):
        await withUndo(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: ProfileRepairService.smoothTemperature,
          ),
        );
      case ConvertTemperatureRepair(:final diveId, :final kelvinScale):
        await withUndo(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: (points) => ProfileRepairService.convertTemperature(
              points,
              kelvinScale: kelvinScale,
            ),
          ),
        );
      case ConvertWaterTempRepair(:final diveId, :final kelvinScale):
        await withUndo(
          () => executor.convertWaterTemp(
            diveId: diveId,
            kelvinScale: kelvinScale,
            findingId: f.id,
          ),
        );
      case RecomputeMetricsRepair(:final diveId):
        await withUndo(
          () => executor.recomputeMetrics(diveId: diveId, findingId: f.id),
        );
      case SwapTankRecordPressuresRepair(
        :final diveId,
        :final tankId,
        :final startBar,
        :final endBar,
      ):
        await withUndo(
          () => executor.swapTankRecordPressures(
            diveId: diveId,
            tankId: tankId,
            newStartBar: startBar,
            newEndBar: endBar,
            findingId: f.id,
          ),
        );
      case SetTankRecordFromSeriesRepair(
        :final diveId,
        :final tankId,
        :final seriesBar,
        :final endpoint,
      ):
        await withUndo(
          () => executor.setTankRecordEndpoint(
            diveId: diveId,
            tankId: tankId,
            endpoint: endpoint,
            bar: seriesBar,
            findingId: f.id,
          ),
        );
      case SwapPressureSeriesRepair(
        :final diveId,
        :final tankIdA,
        :final tankIdB,
      ):
        await withUndo(
          () => executor.swapPressureSeries(
            diveId: diveId,
            tankIdA: tankIdA,
            tankIdB: tankIdB,
            findingId: f.id,
          ),
        );
      case ReassignPressureSeriesRepair(:final diveId, :final fromTankId):
        final toTankId = await showReassignTankPicker(
          context,
          ref,
          diveId: diveId,
          excludeTankId: fromTankId,
        );
        if (toTankId == null) return;
        await withUndo(
          () => executor.reassignPressureSeries(
            diveId: diveId,
            fromTankId: fromTankId,
            toTankId: toTankId,
            findingId: f.id,
          ),
        );
      case CompareSourcesRepair(:final diveId):
        if (context.mounted) context.push('/dives/$diveId');
      case AssignTransmitterRepair(:final serial):
        if (context.mounted) {
          context.push(
            Uri(
              path: '/transmitters/new',
              queryParameters: {'serial': serial},
            ).toString(),
          );
        }
      case GoToDiveRepair(:final diveId):
        if (context.mounted) context.push('/dives/$diveId');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final chip = ref.watch(qualityInboxChipProvider);
    final findingsAsync = ref.watch(qualityFindingsStreamProvider);
    final store = ref.watch(qualityScanStateStoreProvider);
    final formatters = buildQualityUnitFormatters(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dataQuality_inbox_title),
        actions: [
          if (_scanProgress == null)
            IconButton(
              icon: const Icon(Icons.radar),
              tooltip: l10n.dataQuality_scan_start,
              onPressed: _runFullScan,
            ),
        ],
      ),
      body: findingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          // `filterDiveId` is a comma-separated set of dive ids (a single id
          // from dive-detail, the whole imported set from the import summary),
          // so the review deep-link never hides other flagged dives in scope.
          final filterIds =
              (widget.filterDiveId == null || widget.filterDiveId!.isEmpty)
              ? null
              : widget.filterDiveId!.split(',').toSet();
          // Everything this page could ever show: open, and within the dive
          // filter. The chip is applied separately below, deliberately -- it
          // changes as the diver taps, while the dive filter is fixed for the
          // life of the page.
          final scoped = [
            for (final f in all)
              if (f.status == QualityStatus.open &&
                  (filterIds == null ||
                      filterIds.contains(f.diveId) ||
                      filterIds.contains(f.relatedDiveId)))
                f,
          ];
          final open = [
            for (final f in scoped)
              if (categoriesFor(chip).contains(f.category)) f,
          ];
          // Keyed off the scoped set, not the visible one: narrowing by the
          // fixed dive filter keeps a deep link (from the import summary, say)
          // from loading identities for the whole library, while keeping the
          // chip out of the key so switching chips reuses one cached lookup.
          final divesAsync = ref.watch(
            qualityFindingDivesProvider(qualityFindingDivesKey(scoped)),
          );
          // `.value` rather than the `valueOrNull` extension: both keep the
          // previous map across a self-invalidate (a refresh skips the loading
          // branch), but only `.value` keeps it across a genuine reload or a
          // failed read. The names map has a dependency that really does
          // change -- switching the active diver reloads the saved-computer
          // list -- and blinking the identities out is worse than showing the
          // last good ones for a frame.
          final dives = divesAsync.value;
          // Reading the names costs a diver lookup plus a computers-table
          // read, so only pay it when some finding actually names a computer.
          final computerNames = scoped.any((f) => f.computerId != null)
              ? ref.watch(qualityComputerNamesProvider).value ?? const {}
              : const <String, String>{};
          // Only the identity lines wait on that lookup; the findings
          // themselves render immediately from the stream that already
          // resolved.
          DiveIdentityLabel? identity(String? diveId) =>
              (dives == null || diveId == null)
              ? null
              : buildDiveIdentityLabel(
                  summary: dives[diveId],
                  l10n: l10n,
                  formatters: formatters,
                );
          return Column(
            children: [
              if (_scanProgress != null)
                _ScanProgressBar(
                  progress: _scanProgress!,
                  onCancel: () => setState(() => _cancelRequested = true),
                ),
              if (_scanProgress == null && store.hasNewDetectorVersions)
                MaterialBanner(
                  content: Text(l10n.dataQuality_banner_newChecks),
                  actions: [
                    TextButton(
                      onPressed: _runFullScan,
                      child: Text(l10n.dataQuality_banner_rescan),
                    ),
                  ],
                ),
              _ChipRow(chip: chip, findings: all),
              Expanded(
                child: open.isEmpty
                    ? _EmptyState(
                        lastScanAt: store.lastFullScanAt,
                        onScan: _runFullScan,
                      )
                    : ListView(
                        children: [
                          for (final group in _groupByDive(open)) ...[
                            _DiveGroupHeader(
                              label: identity(group.diveId),
                              loading: divesAsync.isLoading,
                              onTap: () =>
                                  context.push('/dives/${group.diveId}'),
                            ),
                            for (final f in group.findings)
                              QualityFindingCard(
                                finding: f,
                                formatters: formatters,
                                relatedDive: identity(f.relatedDiveId),
                                computerName: computerNames[f.computerId],
                                onRepair: (a) =>
                                    _runAction(f, a, identityOf: identity),
                                onDismiss: () => ref
                                    .read(qualityFindingsRepositoryProvider)
                                    .setStatus(f.id, QualityStatus.dismissed),
                                onGoToDive: (id) => context.push('/dives/$id'),
                              ),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ScanProgressBar extends StatelessWidget {
  const _ScanProgressBar({required this.progress, required this.onCancel});
  final ({int done, int total}) progress;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dataQuality_scan_progress(progress.done, progress.total),
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress.total == 0
                      ? null
                      : progress.done / progress.total,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            child: Text(l10n.dataQuality_scan_cancel),
          ),
        ],
      ),
    );
  }
}

class _ChipRow extends ConsumerWidget {
  const _ChipRow({required this.chip, required this.findings});
  final QualityChip chip;
  final List<QualityFinding> findings;

  int _count(QualityChip c) => findings
      .where(
        (f) =>
            f.status == QualityStatus.open &&
            categoriesFor(c).contains(f.category),
      )
      .length;

  String _label(BuildContext context, QualityChip c) {
    final l10n = context.l10n;
    return switch (c) {
      QualityChip.all => l10n.dataQuality_chip_all,
      QualityChip.time => l10n.dataQuality_chip_time,
      QualityChip.profile => l10n.dataQuality_chip_profile,
      QualityChip.gas => l10n.dataQuality_chip_gas,
      QualityChip.tanks => l10n.dataQuality_chip_tanks,
      QualityChip.duplicates => l10n.dataQuality_chip_duplicates,
      QualityChip.sources => l10n.dataQuality_chip_sources,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (final c in QualityChip.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(
                  c == QualityChip.all
                      ? _label(context, c)
                      : '${_label(context, c)} (${_count(c)})',
                ),
                selected: chip == c,
                onSelected: (_) =>
                    ref.read(qualityInboxChipProvider.notifier).state = c,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.lastScanAt, required this.onScan});
  final DateTime? lastScanAt;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 80,
            color: scheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.dataQuality_empty_title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              l10n.dataQuality_empty_subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            lastScanAt == null
                ? l10n.dataQuality_neverScanned
                : l10n.dataQuality_lastScan(
                    UnitFormatter(
                      ref.watch(settingsProvider),
                    ).formatDateTime(lastScanAt, l10n: l10n),
                  ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onScan,
            icon: const Icon(Icons.radar),
            label: Text(l10n.dataQuality_scan_start),
          ),
        ],
      ),
    );
  }
}

/// Names the dive a group of findings belongs to.
///
/// Reads as a dive the diver can recognize (number, site, when, how deep and
/// how long) rather than as the dive's uuid, which is what it showed before:
/// the old fallback chain ended at the raw id, and a downloaded dive with no
/// custom name and no assigned site reached that end every time.
class _DiveGroupHeader extends StatelessWidget {
  const _DiveGroupHeader({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  /// Null while the identities are still being read. Rendering the "dive is
  /// gone" copy in that gap would accuse the log of losing a dive that is
  /// merely a frame away.
  final DiveIdentityLabel? label;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final stats = label?.stats;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label?.headline ??
                  (loading
                      ? context.l10n.common_label_loading
                      // Not loading and still no identity means the lookup
                      // itself failed. Say we cannot name the dive rather
                      // than leaving a blank line above its findings.
                      : context.l10n.dataQuality_dive_unknown),
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            if (stats != null)
              Text(
                stats,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Modal sheet for entering a time-shift offset (pre-filled with the detected
/// value) plus an optional "apply to the whole import" toggle.
Future<({Duration offset, bool importWide})?> showTimeShiftSheet(
  BuildContext context, {
  required Duration suggestedOffset,
  required bool offerImportWide,
}) {
  final controller = TextEditingController(
    text: suggestedOffset == Duration.zero
        ? ''
        : formatDecimalForInput(suggestedOffset.inHours.toDouble()),
  );
  var importWide = false;
  return showModalBottomSheet<({Duration offset, bool importWide})>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;
      return StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: l10n.dataQuality_repairLabel_shiftTime('h'),
                ),
              ),
              if (offerImportWide)
                CheckboxListTile(
                  value: importWide,
                  onChanged: (v) =>
                      setSheetState(() => importWide = v ?? false),
                  title: Text(l10n.dataQuality_repairLabel_shiftImport),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  final hours = parseUserInt(controller.text) ?? 0;
                  Navigator.of(context).pop((
                    offset: Duration(hours: hours),
                    importWide: importWide,
                  ));
                },
                child: Text(MaterialLocalizations.of(context).okButtonLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
}
