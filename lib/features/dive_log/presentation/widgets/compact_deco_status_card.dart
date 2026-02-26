import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact card displaying decompression status metrics.
///
/// Shows the header (deco/no-deco badge), key metrics (NDL/Ceiling, TTS,
/// GF99, SurfGF), and a bottom row with GF settings and deco stops.
///
/// This is the "data" half of the original CompactDecoPanel, separated from
/// the tissue visualization which now lives in [CompactTissueLoadingCard].
class CompactDecoStatusCard extends StatelessWidget {
  /// Current decompression status
  final DecoStatus status;

  /// Optional subtitle text (e.g. "at 3:42") shown when cursor is active
  final String? subtitle;

  const CompactDecoStatusCard({super.key, required this.status, this.subtitle});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(context, colorScheme, textTheme),
            const SizedBox(height: 8),
            _buildMetricsRow(context, colorScheme, textTheme),
            const SizedBox(height: 6),
            _buildBottomRow(context, colorScheme, textTheme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(
            status.inDeco ? Icons.warning : Icons.check_circle,
            size: 16,
            color: status.inDeco ? Colors.orange : Colors.green,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          context.l10n.diveLog_detail_section_decoStatus,
          style: textTheme.titleSmall,
        ),
        const Spacer(),
        Semantics(
          label: status.inDeco
              ? context.l10n.diveLog_deco_semantics_required
              : context.l10n.diveLog_deco_semantics_notRequired,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: status.inDeco
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status.inDeco
                  ? context.l10n.diveLog_deco_badge_deco
                  : context.l10n.diveLog_deco_badge_noDeco,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: status.inDeco ? Colors.orange : Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricsRow(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        // Time (only when a point is selected)
        if (subtitle != null)
          Expanded(
            child: _buildCompactMetric(
              context,
              value: subtitle!,
              label: context.l10n.diveLog_deco_label_time,
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
          ),

        // NDL or Ceiling
        Expanded(
          child: _buildCompactMetric(
            context,
            value: status.inDeco
                ? '${status.ceilingMeters.toStringAsFixed(1)}m'
                : status.ndlFormatted,
            label: status.inDeco
                ? context.l10n.diveLog_deco_label_ceiling
                : context.l10n.diveLog_deco_label_ndl,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),

        // TTS
        Expanded(
          child: _buildCompactMetric(
            context,
            value: status.ttsFormatted,
            label: context.l10n.diveLog_deco_label_tts,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),

        // GF99
        Expanded(
          child: _buildCompactMetric(
            context,
            value: '${status.gf99.toStringAsFixed(0)}%',
            label: context.l10n.diveLog_deco_label_gf99,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),

        // SurfGF
        Expanded(
          child: _buildCompactMetric(
            context,
            value: '${status.surfGf.toStringAsFixed(0)}%',
            label: context.l10n.diveLog_deco_label_surfGf,
            textTheme: textTheme,
            colorScheme: colorScheme,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactMetric(
    BuildContext context, {
    required String value,
    required String label,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomRow(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final gfLabel =
        'GF: ${(status.gfLow * 100).toInt()}/${(status.gfHigh * 100).toInt()}';

    return Semantics(
      label:
          'Gradient factors: low ${(status.gfLow * 100).toInt()}, high ${(status.gfHigh * 100).toInt()}'
          '${status.decoStops.isNotEmpty ? '. ${context.l10n.diveLog_deco_sectionDecoStops}: ${status.decoStops.map((s) => '${s.durationFormatted} at ${s.depthFormatted()}').join(', ')}' : ''}',
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 0.5,
              ),
            ),
            child: Text(
              gfLabel,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
          ),
          if (status.decoStops.isNotEmpty) ...[
            Text(
              '${context.l10n.diveLog_deco_sectionDecoStops}:',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            ...status.decoStops.map(
              (stop) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  '${stop.durationFormatted} @ ${stop.depthFormatted()}',
                  style: textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
