import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_saturation_chart.dart';

/// Panel showing tissue saturation with header and context information.
///
/// Wraps the [TissueSaturationChart] with a collapsible header,
/// legend, and leading compartment indicator.
class TissueSaturationPanel extends StatelessWidget {
  /// The current decompression status containing tissue compartments
  final DecoStatus? decoStatus;

  /// Label showing when this status was captured (e.g., "At 12:30")
  final String? timestampLabel;

  /// Whether the panel starts expanded
  final bool initiallyExpanded;

  const TissueSaturationPanel({
    super.key,
    this.decoStatus,
    this.timestampLabel,
    this.initiallyExpanded = true,
  });

  @override
  Widget build(BuildContext context) {
    if (decoStatus == null || decoStatus!.compartments.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final status = decoStatus!;
    final leadingComp = status.leadingCompartment;

    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(Icons.blur_linear, color: colorScheme.primary),
        title: Text(
          'Tissue Loading',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(
          timestampLabel != null
              ? '$timestampLabel • Leading: TC${leadingComp.compartmentNumber} (${leadingComp.percentLoading.toStringAsFixed(0)}%)'
              : 'Leading: TC${leadingComp.compartmentNumber} (${leadingComp.percentLoading.toStringAsFixed(0)}%)',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        children: [
          // Chart
          TissueSaturationChart(
            compartments: status.compartments,
            leadingCompartmentNumber: leadingComp.compartmentNumber,
            height: 120,
          ),
          const SizedBox(height: 12),
          // Legend
          const TissueSaturationLegend(),
          const SizedBox(height: 8),
          // Stats row
          _buildStatsRow(context, status),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, DecoStatus status) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(
            label: 'Ceiling',
            value: status.ceilingMeters > 0
                ? '${status.ceilingMeters.toStringAsFixed(0)}m'
                : '-',
            color: status.ceilingMeters > 0
                ? Colors.orange
                : colorScheme.primary,
          ),
          _StatChip(
            label: 'NDL',
            value: status.inDeco ? 'DECO' : status.ndlFormatted,
            color: status.inDeco ? Colors.red : Colors.green,
          ),
          _StatChip(
            label: 'TTS',
            value: status.ttsFormatted,
            color: colorScheme.tertiary,
          ),
          _StatChip(
            label: 'GF',
            value:
                '${(status.gfLow * 100).toInt()}/${(status.gfHigh * 100).toInt()}',
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Compact inline tissue saturation display for use in playback mode.
///
/// Shows a smaller version of the tissue chart that fits within playback UI.
class CompactTissueSaturation extends StatelessWidget {
  /// The current decompression status
  final DecoStatus? decoStatus;

  const CompactTissueSaturation({super.key, this.decoStatus});

  @override
  Widget build(BuildContext context) {
    if (decoStatus == null || decoStatus!.compartments.isEmpty) {
      return const SizedBox.shrink();
    }

    final status = decoStatus!;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.blur_linear, size: 14, color: colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                'Tissue Loading',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colorScheme.primary),
              ),
              const Spacer(),
              Text(
                'TC${status.leadingCompartment.compartmentNumber}: ${status.leadingCompartment.percentLoading.toStringAsFixed(0)}%',
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TissueSaturationChart(
            compartments: status.compartments,
            leadingCompartmentNumber:
                status.leadingCompartment.compartmentNumber,
            height: 60,
            showLabels: false,
          ),
        ],
      ),
    );
  }
}
