import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/data_quality/data/services/quality_repair_executor.dart';
import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/data_quality/domain/detectors/quality_detector_registry.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/repairs/quality_repair_action.dart';
import 'package:submersion/features/data_quality/data/services/profile_repair_service.dart';
import 'package:submersion/features/data_quality/presentation/providers/data_quality_providers.dart';
import 'package:submersion/features/data_quality/presentation/providers/quality_inbox_providers.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_card.dart';
import 'package:submersion/features/data_quality/presentation/widgets/quality_finding_message.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/combine_dives_dialog.dart';
import 'package:submersion/features/dive_log/presentation/widgets/run_dive_consolidation.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

QualityUnitFormatters buildQualityUnitFormatters(WidgetRef ref) {
  final units = UnitFormatter(ref.watch(settingsProvider));
  return QualityUnitFormatters(
    depth: (m) => units.formatDepth(m),
    pressure: (bar) => units.formatPressure(bar),
    temperature: (c) => units.formatTemperature(c),
    // Surface air consumption is a volume rate; honor the volume unit
    // preference (L/min vs cuft/min) rather than the pressure-based SAC mode.
    sac: (lpm) =>
        '${units.convertVolume(lpm).toStringAsFixed(1)} ${units.volumeSymbol}/min',
    date: (d) => units.formatDate(d),
  );
}

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

  Future<void> _runAction(QualityFinding f, QualityRepairAction action) async {
    final executor = QualityRepairExecutor();
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    Future<void> withUndo(Future<RepairUndo?> Function() run) async {
      try {
        final undo = await run();
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.dataQuality_repair_applied),
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
      case ConsolidateDuplicateRepair(
        :final targetDiveId,
        :final secondaryDiveId,
      ):
        await runDiveConsolidation(
          context: context,
          service: ref.read(diveConsolidationServiceProvider),
          targetDiveId: targetDiveId,
          secondaryDiveIds: [secondaryDiveId],
          onConsolidated: () => scheduleQualityScan([targetDiveId]),
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
        final newId = await ref
            .read(diveSplitServiceProvider)
            .split(diveId: diveId, sourceId: sourceId);
        scheduleQualityScan([diveId, newId]);
      case DespikeRepair(:final diveId):
        await withUndo(
          () => executor.applyProfileRepair(
            diveId: diveId,
            findingId: f.id,
            compute: ProfileRepairService.despike,
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
          final open = [
            for (final f in all)
              if (f.status == QualityStatus.open &&
                  categoriesFor(chip).contains(f.category) &&
                  (filterIds == null ||
                      filterIds.contains(f.diveId) ||
                      filterIds.contains(f.relatedDiveId)))
                f,
          ];
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
                            _DiveGroupHeader(diveId: group.diveId),
                            for (final f in group.findings)
                              QualityFindingCard(
                                finding: f,
                                formatters: formatters,
                                onRepair: (a) => _runAction(f, a),
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

class _DiveGroupHeader extends ConsumerWidget {
  const _DiveGroupHeader({required this.diveId});
  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dive = ref.watch(diveProvider(diveId)).value;
    final title = dive?.effectiveName ?? dive?.site?.name ?? diveId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
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
        : suggestedOffset.inHours.toString(),
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
                  final hours = int.tryParse(controller.text.trim()) ?? 0;
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

/// Simple picker listing the dive's other tanks for a series reassignment.
Future<String?> showReassignTankPicker(
  BuildContext context,
  WidgetRef ref, {
  required String diveId,
  required String excludeTankId,
}) async {
  final dive = await ref.read(diveProvider(diveId).future);
  if (dive == null || !context.mounted) return null;
  final candidates = dive.tanks.where((t) => t.id != excludeTankId).toList();
  if (candidates.isEmpty) return null;
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: Text(context.l10n.dataQuality_repairLabel_reassignSeries),
      children: [
        for (final t in candidates)
          SimpleDialogOption(
            onPressed: () => Navigator.of(context).pop(t.id),
            child: Text(t.name ?? 'Tank ${t.order + 1}'),
          ),
      ],
    ),
  );
}
