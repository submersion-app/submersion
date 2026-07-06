import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_review_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/instrument_tiles.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_transport_controls.dart';
import 'package:submersion/features/dive_log/presentation/widgets/readout_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The bottom instrument strip of the fullscreen profile view: playback
/// transport plus adaptive dive-computer readout tiles.
class ProfileInstrumentBar extends ConsumerWidget {
  final String diveId;

  /// The profile the chart renders and the analysis was computed over (the
  /// active source's points). Tile values are resolved by index into the
  /// analysis curves, so this must be that same array -- not dive.profile,
  /// which can be a different source sampled at a different rate.
  final List<DiveProfilePoint> profile;
  final ProfileAnalysis? analysis;
  final Map<String, List<TankPressurePoint>>? tankPressures;

  const ProfileInstrumentBar({
    super.key,
    required this.diveId,
    required this.profile,
    required this.analysis,
    required this.tankPressures,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final reviewTimestamp = ref.watch(profileReviewProvider(diveId));

    final candidates = computeCandidateTiles(
      profile: profile,
      analysis: analysis,
      tankPressures: tankPressures,
    );
    final preferred = applyTilePreferences(
      candidates: candidates,
      order: settings.fullscreenTileOrder,
      hidden: settings.fullscreenHiddenTiles,
    );
    final sample = resolveSample(
      profile: profile,
      analysis: analysis,
      tankPressures: tankPressures,
      timestamp: reviewTimestamp ?? 0,
    );
    final tiles = applyDecoSwap(tiles: preferred, inDeco: sample.inDeco);

    final tileWidgets = [
      for (final id in tiles)
        ReadoutTile(
          label: _label(context, id),
          value: reviewTimestamp == null
              ? null
              : _value(context, id, sample, units),
        ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: ProfileTransportControls(
                  diveId: diveId,
                  profile: profile,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: context.l10n.diveLog_instruments_customize,
                visualDensity: VisualDensity.compact,
                onPressed: () =>
                    _showCustomizeSheet(context, ref, candidates: candidates),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Wrap(spacing: 8, runSpacing: 8, children: tileWidgets);
              }
              return SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tileWidgets.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => tileWidgets[i],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _label(BuildContext context, InstrumentTileId id) {
    final l10n = context.l10n;
    return switch (id) {
      InstrumentTileId.depth => l10n.diveLog_legend_label_depth,
      InstrumentTileId.runtime => l10n.diveLog_tooltip_time,
      InstrumentTileId.temperature => l10n.diveLog_legend_label_temp,
      InstrumentTileId.ndl => l10n.diveLog_legend_label_ndl,
      InstrumentTileId.ceiling => l10n.diveLog_legend_label_ceiling,
      InstrumentTileId.tts => l10n.diveLog_legend_label_tts,
      InstrumentTileId.tankPressure => l10n.diveLog_legend_label_pressure,
      InstrumentTileId.ppO2 => l10n.diveLog_legend_label_ppO2,
      InstrumentTileId.gf => l10n.diveLog_legend_label_gfPercent,
      InstrumentTileId.cns => l10n.diveLog_legend_label_cns,
      InstrumentTileId.sac => l10n.diveLog_legend_label_sacRate,
      InstrumentTileId.heartRate => l10n.diveLog_legend_label_heartRate,
      InstrumentTileId.ascentRate => l10n.diveLog_legend_label_ascentRate,
    };
  }

  String? _value(
    BuildContext context,
    InstrumentTileId id,
    InstrumentSample sample,
    UnitFormatter units,
  ) {
    String formatMinSec(int seconds) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return '$m:${s.toString().padLeft(2, '0')}';
    }

    return switch (id) {
      InstrumentTileId.depth =>
        sample.depthMeters == null
            ? null
            : units.formatDepth(sample.depthMeters),
      InstrumentTileId.runtime => formatMinSec(sample.runtimeSeconds),
      InstrumentTileId.temperature =>
        sample.temperatureCelsius == null
            ? null
            : units.formatTemperature(sample.temperatureCelsius),
      InstrumentTileId.ndl => switch (sample.ndlSeconds) {
        null => null,
        final ndl when ndl < 0 => context.l10n.diveLog_playbackStats_deco,
        final ndl when ndl >= 3600 => '>60 min',
        final ndl => formatMinSec(ndl),
      },
      InstrumentTileId.ceiling =>
        sample.ceilingMeters == null
            ? null
            : units.formatDepth(sample.ceilingMeters),
      InstrumentTileId.tts =>
        sample.ttsSeconds == null
            ? null
            : '${(sample.ttsSeconds! / 60).ceil()} min',
      InstrumentTileId.tankPressure =>
        sample.tankPressuresBar.isEmpty
            ? null
            : sample.tankPressuresBar.values
                  .map((p) => units.formatPressure(p))
                  .join(' / '),
      InstrumentTileId.ppO2 =>
        sample.ppO2Bar == null
            ? null
            : '${sample.ppO2Bar!.toStringAsFixed(2)} bar',
      InstrumentTileId.gf =>
        sample.gfPercent == null
            ? null
            : '${sample.gfPercent!.toStringAsFixed(0)}%',
      InstrumentTileId.cns =>
        sample.cnsPercent == null
            ? null
            : '${sample.cnsPercent!.toStringAsFixed(1)}%',
      InstrumentTileId.sac =>
        sample.sacRate == null
            ? null
            : '${units.convertSac(sample.sacRate!).toStringAsFixed(1)} ${units.sacSymbol}',
      InstrumentTileId.heartRate =>
        sample.heartRateBpm == null ? null : '${sample.heartRateBpm} bpm',
      InstrumentTileId.ascentRate =>
        sample.ascentRateMetersPerMin == null
            ? null
            : '${units.formatDepth(sample.ascentRateMetersPerMin, decimals: 0)}/min',
    };
  }

  void _showCustomizeSheet(
    BuildContext context,
    WidgetRef ref, {
    required List<InstrumentTileId> candidates,
  }) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _CustomizeSheet(
        candidates: candidates,
        labelFor: (id) => _label(context, id),
      ),
    );
  }
}

/// Reorderable list of candidate tiles with visibility switches.
class _CustomizeSheet extends ConsumerWidget {
  final List<InstrumentTileId> candidates;
  final String Function(InstrumentTileId) labelFor;

  const _CustomizeSheet({required this.candidates, required this.labelFor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final ordered = applyTilePreferences(
      candidates: candidates,
      order: settings.fullscreenTileOrder,
      hidden: const [],
    );
    final hidden = settings.fullscreenHiddenTiles.toSet();

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.diveLog_instruments_customize,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
            child: Text(
              context.l10n.diveLog_instruments_customizeHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Flexible(
            child: ReorderableListView(
              shrinkWrap: true,
              buildDefaultDragHandles: true,
              onReorderItem: (oldIndex, newIndex) {
                final items = [...ordered];
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                notifier.setFullscreenTilePreferences(
                  order: mergeTileOrder(
                    reordered: [for (final id in items) id.key],
                    stored: settings.fullscreenTileOrder,
                    candidates: candidates.map((id) => id.key).toSet(),
                  ),
                  hidden: settings.fullscreenHiddenTiles,
                );
              },
              children: [
                for (final id in ordered)
                  SwitchListTile(
                    key: ValueKey(id.key),
                    title: Text(labelFor(id)),
                    value: !hidden.contains(id.key),
                    onChanged: (visible) {
                      final newHidden = {...hidden};
                      if (visible) {
                        newHidden.remove(id.key);
                      } else {
                        newHidden.add(id.key);
                      }
                      notifier.setFullscreenTilePreferences(
                        order: settings.fullscreenTileOrder,
                        hidden: newHidden.toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
