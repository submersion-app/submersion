import 'package:flutter/material.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Card displaying oxygen toxicity information (CNS% and OTU).
class O2ToxicityCard extends StatelessWidget {
  /// Oxygen exposure data
  final O2Exposure exposure;

  /// Whether to show detailed breakdown
  final bool showDetails;

  /// Whether to show the header row (title + warning badge)
  final bool showHeader;

  /// Whether to wrap content in a Card
  final bool useCard;

  /// Weekly OTU rolling total (7-day window, null if not yet loaded)
  final double? weeklyOtu;

  /// Unit preferences, so the max-ppO2 depth renders in m or ft.
  ///
  /// Passed rather than read from a provider: this widget is a plain
  /// StatelessWidget and adding a provider dependency would require every
  /// consumer test to supply a ProviderScope.
  final UnitFormatter units;

  const O2ToxicityCard({
    super.key,
    required this.exposure,
    required this.units,
    this.showDetails = true,
    this.showHeader = true,
    this.useCard = true,
    this.weeklyOtu,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        if (showHeader) ...[
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.air, size: 20, color: colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.diveLog_o2tox_title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (exposure.cnsWarning || exposure.ppO2Warning)
                Semantics(
                  label: exposure.cnsCritical || exposure.ppO2Critical
                      ? context.l10n.diveLog_o2tox_semantics_criticalWarning
                      : context.l10n.diveLog_o2tox_semantics_warning,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: exposure.cnsCritical || exposure.ppO2Critical
                          ? colorScheme.error
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      exposure.cnsCritical || exposure.ppO2Critical
                          ? context.l10n.diveLog_detail_badge_critical
                          : context.l10n.diveLog_detail_badge_warning,
                      style: textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // CNS Progress
        _buildCnsProgress(context),
        const SizedBox(height: 16),

        // OTU Display
        _buildOtuDisplay(context),

        // Detailed breakdown
        if (showDetails) ...[
          const Divider(height: 24),
          _buildDetailsSection(context),
        ],
      ],
    );

    if (!useCard) {
      return Padding(padding: const EdgeInsets.all(16), child: content);
    }

    return Card(
      child: Padding(padding: const EdgeInsets.all(16), child: content),
    );
  }

  Widget _buildCnsProgress(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Determine color based on CNS level
    Color getProgressColor() {
      if (exposure.cnsEnd >= 100) return colorScheme.error;
      if (exposure.cnsEnd >= 80) return Colors.orange;
      if (exposure.cnsEnd >= 50) return Colors.amber;
      return Colors.green;
    }

    return Semantics(
      label: statLabel(
        name: context.l10n.diveLog_o2tox_cnsOxygenClock,
        value: exposure.cnsFormatted,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_o2tox_cnsOxygenClock,
                style: textTheme.bodyMedium,
              ),
              Text(
                exposure.cnsFormatted,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: getProgressColor(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: context.l10n.o2Toxicity_cnsProgressSemantics(
              exposure.cnsEnd.toStringAsFixed(0),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (exposure.cnsEnd / 100).clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(getProgressColor()),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_o2tox_startPercent(
                  exposure.cnsStart.toStringAsFixed(0),
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                context.l10n.diveLog_o2tox_deltaDive(
                  exposure.cnsDelta.toStringAsFixed(1),
                ),
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtuDisplay(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Color otuLimitColor(double pct) {
      if (pct >= 100) return colorScheme.error;
      if (pct >= 80) return Colors.orange;
      if (pct >= 50) return Colors.amber;
      return Colors.green;
    }

    final dailyPct = exposure.otuDailyPercentOfLimit;
    final weeklyTotal = weeklyOtu ?? exposure.otu;
    final weeklyPct = (weeklyTotal / O2Exposure.weeklyOtuLimit) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_o2tox_oxygenToleranceUnits,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),

        // This Dive
        _buildOtuRow(
          context,
          label: context.l10n.o2Toxicity_thisDive,
          value: exposure.otu,
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 6),

        // Daily cumulative with progress bar
        _buildOtuProgressRow(
          context,
          label: context.l10n.o2Toxicity_daily,
          value: exposure.otuDaily,
          limit: O2Exposure.dailyOtuLimit,
          percent: dailyPct,
          color: otuLimitColor(dailyPct),
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 6),

        // Weekly rolling with progress bar
        _buildOtuProgressRow(
          context,
          label: context.l10n.o2Toxicity_weekly,
          value: weeklyTotal,
          limit: O2Exposure.weeklyOtuLimit,
          percent: weeklyPct,
          color: otuLimitColor(weeklyPct),
          textTheme: textTheme,
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildOtuRow(
    BuildContext context, {
    required String label,
    required double value,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return Semantics(
      label: context.l10n.o2Toxicity_otuValueSemantics(
        label,
        value.toStringAsFixed(0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '${value.toStringAsFixed(0)} OTU',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOtuProgressRow(
    BuildContext context, {
    required String label,
    required double value,
    required double limit,
    required double percent,
    required Color color,
    required TextTheme textTheme,
    required ColorScheme colorScheme,
  }) {
    return Semantics(
      label: context.l10n.o2Toxicity_otuSemantics(
        label,
        value.toStringAsFixed(0),
        limit.toStringAsFixed(0),
        percent.toStringAsFixed(0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '${value.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} OTU '
                '(${percent.toStringAsFixed(0)}%)',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_o2tox_details,
          style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        _buildDetailRow(
          context,
          context.l10n.diveLog_o2tox_label_maxPpO2,
          exposure.maxPpO2Formatted,
          icon: Icons.trending_up,
          valueColor: exposure.ppO2Critical
              ? colorScheme.error
              : exposure.ppO2Warning
              ? Colors.orange
              : null,
        ),
        _buildDetailRow(
          context,
          context.l10n.diveLog_o2tox_label_maxPpO2Depth,
          units.formatDepth(exposure.maxPpO2Depth, decimals: 1),
          icon: Icons.vertical_align_bottom,
        ),
        if (exposure.timeAboveWarning > 0)
          _buildDetailRow(
            context,
            context.l10n.diveLog_o2tox_label_timeAbove14,
            _formatDuration(context.l10n, exposure.timeAboveWarning),
            icon: Icons.timer,
            valueColor: Colors.orange,
          ),
        if (exposure.timeAboveCritical > 0)
          _buildDetailRow(
            context,
            context.l10n.diveLog_o2tox_label_timeAbove16,
            _formatDuration(context.l10n, exposure.timeAboveCritical),
            icon: Icons.warning,
            valueColor: colorScheme.error,
          ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    Color? valueColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            if (icon != null) ...[
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(AppLocalizations l10n, int seconds) {
    if (seconds < 60) return l10n.formatter_duration_seconds('$seconds');
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return l10n.formatter_duration_minutes('$minutes');
    return l10n.formatter_duration_minutesSeconds('$minutes', '$secs');
  }
}

/// Compact panel showing all O2 toxicity data in a condensed card format.
///
/// Designed to fit alongside the dive profile chart (~150px height).
class CompactO2ToxicityPanel extends StatelessWidget {
  /// Oxygen exposure data
  final O2Exposure exposure;

  /// Currently selected ppO2 value from the dive profile cursor
  final double? selectedPpO2;

  /// Currently selected CNS% value from the dive profile cursor
  final double? selectedCns;

  /// Currently selected OTU value from the dive profile cursor
  final double? selectedOtu;

  /// Optional subtitle text (e.g. "@3:42")
  final String? subtitle;

  /// Weekly OTU rolling total (7-day window, null if not yet loaded)
  final double? weeklyOtu;

  /// Whether to wrap content in a Card
  final bool useCard;

  const CompactO2ToxicityPanel({
    super.key,
    required this.exposure,
    this.selectedPpO2,
    this.selectedCns,
    this.selectedOtu,
    this.subtitle,
    this.weeklyOtu,
    this.useCard = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        _buildHeader(context, colorScheme, textTheme),
        const SizedBox(height: 8),

        // CNS progress section
        _buildCnsProgress(context, colorScheme, textTheme),
        const SizedBox(height: 6),

        // OTU progress bars (Daily + Weekly)
        _buildOtuProgress(context, colorScheme, textTheme),
        const SizedBox(height: 4),

        // ppO2 metrics row
        _buildPpO2Row(context, colorScheme, textTheme),

        // Time above thresholds (only if > 0)
        if (exposure.timeAboveWarning > 0 ||
            exposure.timeAboveCritical > 0) ...[
          const SizedBox(height: 4),
          _buildTimeAboveThresholds(context, colorScheme, textTheme),
        ],
      ],
    );

    if (!useCard) return content;

    return Card(
      child: Padding(padding: const EdgeInsets.all(12), child: content),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final isCritical = exposure.cnsCritical || exposure.ppO2Critical;
    final isWarning = exposure.cnsWarning || exposure.ppO2Warning;

    return Row(
      children: [
        ExcludeSemantics(
          child: Icon(Icons.air, size: 16, color: colorScheme.primary),
        ),
        const SizedBox(width: 6),
        Text(
          context.l10n.diveLog_detail_section_oxygenToxicity,
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
        if (isWarning) ...[
          const SizedBox(width: 6),
          Semantics(
            label: isCritical
                ? context.l10n.diveLog_o2tox_semantics_criticalWarning
                : context.l10n.diveLog_o2tox_semantics_warning,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isCritical ? colorScheme.error : Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                isCritical
                    ? context.l10n.diveLog_detail_badge_critical
                    : context.l10n.diveLog_detail_badge_warning,
                style: textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCnsProgress(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    Color getCnsColor(double cns) {
      if (cns >= 100) return colorScheme.error;
      if (cns >= 80) return Colors.orange;
      if (cns >= 50) return Colors.amber;
      return Colors.green;
    }

    final endColor = getCnsColor(exposure.cnsEnd);

    // CNS added from start to the selected cursor point
    final selectedDelta = selectedCns != null
        ? selectedCns! - exposure.cnsStart
        : null;

    // Display: "12% / 18%" when hovering (current / max), just "18%" otherwise
    final cnsDisplay = selectedCns != null
        ? '${selectedCns!.toStringAsFixed(0)}% / ${exposure.cnsEnd.toStringAsFixed(0)}%'
        : exposure.cnsFormatted;
    final cnsDisplayColor = getCnsColor(
      selectedCns != null ? selectedCns! : exposure.cnsEnd,
    );

    return Semantics(
      label: statLabel(
        name: context.l10n.diveLog_o2tox_cnsOxygenClock,
        value: cnsDisplay,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_o2tox_cnsOxygenClock,
                style: textTheme.bodyMedium,
              ),
              Text(
                cnsDisplay,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cnsDisplayColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _buildStackedCnsBar(
            colorScheme: colorScheme,
            endColor: endColor,
            selectedDelta: selectedDelta,
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.diveLog_o2tox_startPercent(
                  exposure.cnsStart.toStringAsFixed(0),
                ),
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                context.l10n.diveLog_o2tox_deltaDive(
                  exposure.cnsDelta.toStringAsFixed(1),
                ),
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the stacked CNS bar with up to four layers:
  ///   1. Background track (full width)
  ///   2. Green bar: total CNS at end of dive
  ///   3. Primary overlay: CNS added during dive up to cursor point
  ///   4. Start segment: residual CNS from prior dives (always visible)
  Widget _buildStackedCnsBar({
    required ColorScheme colorScheme,
    required Color endColor,
    required double? selectedDelta,
  }) {
    const barHeight = 20.0;
    const barRadius = BorderRadius.all(Radius.circular(6));

    final endFraction = (exposure.cnsEnd / 100).clamp(0.0, 1.0);
    final startFraction = (exposure.cnsStart / 100).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: barRadius,
      child: SizedBox(
        height: barHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;

            return Stack(
              children: [
                // Background track
                Container(
                  width: totalWidth,
                  height: barHeight,
                  color: colorScheme.surfaceContainerHighest,
                ),
                // Green bar: total CNS at end of dive
                Container(
                  width: totalWidth * endFraction,
                  height: barHeight,
                  color: endColor,
                ),
                // Primary overlay: CNS added during dive up to cursor point
                if (selectedDelta != null && selectedDelta > 0)
                  Positioned(
                    left: totalWidth * startFraction,
                    child: Container(
                      width:
                          totalWidth *
                          (selectedDelta / 100).clamp(0.0, 1.0 - startFraction),
                      height: barHeight,
                      color: colorScheme.primary,
                    ),
                  ),
                // Start segment: residual CNS from prior dives (always on top)
                if (startFraction > 0)
                  Container(
                    width: totalWidth * startFraction,
                    height: barHeight,
                    color: Colors.blueGrey,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildOtuProgress(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    // Daily data
    final dailyTotal = exposure.otuDaily;
    final dailyPct = exposure.otuDailyPercentOfLimit;
    final dailyColor = _getOtuLimitColor(dailyPct, colorScheme);

    // Weekly data
    final weeklyTotal = weeklyOtu ?? exposure.otu;
    final weeklyPrior = (weeklyTotal - exposure.otu).clamp(
      0.0,
      double.infinity,
    );
    final weeklyPct = (weeklyTotal / O2Exposure.weeklyOtuLimit) * 100;
    final weeklyColor = _getOtuLimitColor(weeklyPct, colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_o2tox_oxygenToleranceUnits,
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),

        // Daily OTU bar
        _buildOtuBarSection(
          l10n: context.l10n,
          colorScheme: colorScheme,
          textTheme: textTheme,
          label: context.l10n.o2Toxicity_daily,
          total: dailyTotal,
          limit: O2Exposure.dailyOtuLimit,
          prior: exposure.otuStart,
          thisDive: exposure.otu,
          percent: dailyPct,
          color: dailyColor,
          priorLabel: context.l10n.o2Toxicity_start(
            exposure.otuStart.toStringAsFixed(0),
          ),
        ),
        const SizedBox(height: 8),

        // Weekly OTU bar
        _buildOtuBarSection(
          l10n: context.l10n,
          colorScheme: colorScheme,
          textTheme: textTheme,
          label: context.l10n.o2Toxicity_weekly,
          total: weeklyTotal,
          limit: O2Exposure.weeklyOtuLimit,
          prior: weeklyPrior,
          thisDive: exposure.otu,
          percent: weeklyPct,
          color: weeklyColor,
          priorLabel: context.l10n.o2Toxicity_prior(
            weeklyPrior.toStringAsFixed(0),
          ),
        ),
      ],
    );
  }

  Widget _buildOtuBarSection({
    required AppLocalizations l10n,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
    required String label,
    required double total,
    required double limit,
    required double prior,
    required double thisDive,
    required double percent,
    required Color color,
    required String priorLabel,
  }) {
    // Header value: "cursor / total / limit" or "total / limit"
    final String headerValue;
    if (selectedOtu != null) {
      headerValue =
          '${selectedOtu!.toStringAsFixed(0)} / '
          '${total.toStringAsFixed(0)} / '
          '${limit.toStringAsFixed(0)} OTU';
    } else {
      headerValue =
          '${total.toStringAsFixed(0)} / ${limit.toStringAsFixed(0)} OTU';
    }

    return Semantics(
      label: l10n.o2Toxicity_otuSemantics(
        label,
        total.toStringAsFixed(0),
        limit.toStringAsFixed(0),
        percent.toStringAsFixed(0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: textTheme.bodySmall),
              Text(
                headerValue,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Stacked bar
          _buildStackedOtuBar(
            colorScheme: colorScheme,
            endColor: color,
            totalFraction: (total / limit).clamp(0.0, 1.0),
            priorFraction: (prior / limit).clamp(0.0, 1.0),
            selectedDelta: selectedOtu,
            limit: limit,
          ),
          const SizedBox(height: 2),

          // Footer row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                priorLabel,
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                l10n.o2Toxicity_addedThisDive(thisDive.toStringAsFixed(0)),
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the stacked OTU bar with up to four layers:
  ///   1. Background track (full width = limit)
  ///   2. Colored bar: total OTU as fraction of limit
  ///   3. Primary overlay: OTU at cursor point during this dive
  ///   4. Prior segment: OTU from prior dives (always visible)
  Widget _buildStackedOtuBar({
    required ColorScheme colorScheme,
    required Color endColor,
    required double totalFraction,
    required double priorFraction,
    required double? selectedDelta,
    required double limit,
  }) {
    const barHeight = 16.0;
    const barRadius = BorderRadius.all(Radius.circular(5));

    return ClipRRect(
      borderRadius: barRadius,
      child: SizedBox(
        height: barHeight,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;

            return Stack(
              children: [
                // Background track
                Container(
                  width: totalWidth,
                  height: barHeight,
                  color: colorScheme.surfaceContainerHighest,
                ),
                // Colored bar: total OTU as fraction of limit
                Container(
                  width: totalWidth * totalFraction,
                  height: barHeight,
                  color: endColor,
                ),
                // Primary overlay: OTU at cursor point
                if (selectedDelta != null && selectedDelta > 0)
                  Positioned(
                    left: totalWidth * priorFraction,
                    child: Container(
                      width:
                          totalWidth *
                          (selectedDelta / limit).clamp(
                            0.0,
                            1.0 - priorFraction,
                          ),
                      height: barHeight,
                      color: colorScheme.primary,
                    ),
                  ),
                // Prior segment: OTU from prior dives (always on top)
                if (priorFraction > 0)
                  Container(
                    width: totalWidth * priorFraction,
                    height: barHeight,
                    color: Colors.blueGrey,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPpO2Row(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      children: [
        // ppO2 at selected point
        if (selectedPpO2 != null)
          Expanded(
            child: _buildCompactMetric(
              context,
              value: '${selectedPpO2!.toStringAsFixed(2)} bar',
              label: context.l10n.diveLog_legend_label_ppO2,
              textTheme: textTheme,
              colorScheme: colorScheme,
            ),
          ),

        // Max ppO2
        Expanded(
          child: _buildCompactMetric(
            context,
            value: exposure.maxPpO2Formatted,
            label: context.l10n.diveLog_o2tox_label_maxPpO2,
            textTheme: textTheme,
            colorScheme: colorScheme,
            valueColor: _getPpO2Color(colorScheme),
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
    Color? valueColor,
  }) {
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Column(
          children: [
            Text(
              value,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getOtuLimitColor(double percent, ColorScheme colorScheme) {
    if (percent >= 100) return colorScheme.error;
    if (percent >= 80) return Colors.orange;
    if (percent >= 50) return Colors.amber;
    return Colors.green;
  }

  Widget _buildTimeAboveThresholds(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final parts = <InlineSpan>[];

    if (exposure.timeAboveWarning > 0) {
      parts.add(
        TextSpan(
          text:
              '${context.l10n.diveLog_o2tox_label_timeAbove14}: '
              '${_formatDuration(context.l10n, exposure.timeAboveWarning)}',
          style: textTheme.labelSmall?.copyWith(color: Colors.orange),
        ),
      );
    }

    if (exposure.timeAboveCritical > 0) {
      if (parts.isNotEmpty) {
        parts.add(TextSpan(text: '  ', style: textTheme.labelSmall));
      }
      parts.add(
        TextSpan(
          text:
              '${context.l10n.diveLog_o2tox_label_timeAbove16}: '
              '${_formatDuration(context.l10n, exposure.timeAboveCritical)}',
          style: textTheme.labelSmall?.copyWith(color: colorScheme.error),
        ),
      );
    }

    return Text.rich(TextSpan(children: parts));
  }

  Color _getPpO2Color(ColorScheme colorScheme) {
    if (exposure.ppO2Critical) return colorScheme.error;
    if (exposure.ppO2Warning) return Colors.orange;
    return colorScheme.onSurfaceVariant;
  }

  String _formatDuration(AppLocalizations l10n, int seconds) {
    if (seconds < 60) return l10n.formatter_duration_seconds('$seconds');
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (secs == 0) return l10n.formatter_duration_minutes('$minutes');
    return l10n.formatter_duration_minutesSeconds('$minutes', '$secs');
  }
}

/// Compact version of O2 toxicity display for inline use.
class O2ToxicityBadge extends StatelessWidget {
  final O2Exposure exposure;

  const O2ToxicityBadge({super.key, required this.exposure});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color getBadgeColor() {
      if (exposure.cnsCritical) return colorScheme.error;
      if (exposure.cnsWarning) return Colors.orange;
      return Colors.green;
    }

    return Semantics(
      label: context.l10n.diveLog_o2tox_semantics_cnsBadge(
        exposure.cnsFormatted,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: getBadgeColor().withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBadgeColor()),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.air, size: 14, color: getBadgeColor()),
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.diveLog_o2tox_cnsBadgeLabel(exposure.cnsFormatted),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: getBadgeColor(),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
