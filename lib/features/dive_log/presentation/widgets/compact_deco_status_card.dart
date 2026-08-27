import 'package:flutter/material.dart';

import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/entities/gradient_factor_source.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact card displaying decompression status metrics.
///
/// Shows the header (deco/no-deco badge), key metrics (NDL/Ceiling, TTS,
/// GF99, SurfGF), and a bottom row with the gradient factors and deco stops.
///
/// This is the "data" half of the original CompactDecoPanel, separated from
/// the tissue visualization which now lives in [CompactTissueLoadingCard].
class CompactDecoStatusCard extends StatelessWidget {
  /// Current decompression status
  final DecoStatus status;

  /// Where the gradient factors on show came from (#1047).
  ///
  /// [status] carries the pair the engine ran with but not its provenance, and
  /// most dive computers report no gradient factors at all -- so an unlabelled
  /// chip reads as the computer's configuration when it is usually the diver's
  /// own setting. Null keeps the plain chip, for callers that have no dive in
  /// hand to attribute it to.
  final GradientFactorSource? gfSource;

  /// Optional time label (e.g. "at 3:42") shown next to the title on hover
  final String? subtitle;

  const CompactDecoStatusCard({
    super.key,
    required this.status,
    this.gfSource,
    this.subtitle,
  });

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
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Text(
            '@ $subtitle',
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
    // Prefer the resolved source: it knows the origin, and its integers are
    // the ones the engine was configured with. Fall back to the per-sample
    // status for callers that pass no source.
    final low = gfSource?.low ?? (status.gfLow * 100).toInt();
    final high = gfSource?.high ?? (status.gfHigh * 100).toInt();
    final algorithm = gfSource != null && gfSource!.recordedNonGfAlgorithm
        ? _algorithmLabel(gfSource!.recordedAlgorithm!)
        : null;

    final String gfLabel;
    final String? gfTooltip;
    if (algorithm != null) {
      gfLabel = context.l10n.diveLog_deco_gf_chipRecordedAlgorithm(
        algorithm,
        low,
        high,
      );
      gfTooltip = context.l10n.diveLog_deco_gf_tooltipRecordedAlgorithm(
        algorithm,
      );
    } else if (gfSource?.isFromDiverSettings ?? false) {
      gfLabel = context.l10n.diveLog_deco_gf_chipFromSettings(low, high);
      gfTooltip = context.l10n.diveLog_deco_gf_tooltipFromSettings;
    } else {
      gfLabel = context.l10n.diveLog_deco_gf_chip(low, high);
      gfTooltip = null;
    }

    final gfChip = Container(
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
    );

    return Semantics(
      // Spelled out rather than reusing the chip's compact label, whose
      // separators do not read aloud well. Localized, so a non-English app
      // does not stitch an English lead-in onto a translated qualifier. The
      // qualifier is the tooltip's own sentence, so a screen reader learns
      // the provenance too.
      label:
          '${context.l10n.diveLog_deco_gf_semantics(low, high)}'
          '${gfTooltip != null ? '. $gfTooltip' : ''}'
          '${status.decoStops.isNotEmpty ? '. ${context.l10n.diveLog_deco_sectionDecoStops}: ${status.decoStops.map((s) => '${s.durationFormatted} at ${s.depthFormatted()}').join(', ')}' : ''}',
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (gfTooltip != null)
            Tooltip(message: gfTooltip, child: gfChip)
          else
            gfChip,
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

  /// Display form of a recorded deco model.
  ///
  /// Only reached for the models [GradientFactorSource.recordedNonGfAlgorithm]
  /// recognizes, so this covers that whitelist; anything unexpected is shown
  /// as recorded rather than mangled.
  static String _algorithmLabel(String algorithm) {
    return switch (algorithm.trim().toLowerCase()) {
      'vpm' => 'VPM',
      'vpmb' || 'vpm-b' => 'VPM-B',
      'rgbm' => 'RGBM',
      'dciem' => 'DCIEM',
      _ => algorithm.trim(),
    };
  }
}
