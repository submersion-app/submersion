import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/safety_finding.dart';
import 'package:submersion/features/dive_log/presentation/widgets/eager_tap_gesture_recognizer.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_highlight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_finding_text.dart';
import 'package:submersion/features/dive_log/presentation/widgets/safety_lane_layout.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Chart overlay hosting the safety findings lane (tappable chips below the
/// plot) and the callout card for the selected finding. A widget layer, not
/// an fl_chart element, so taps never enter the chart's gesture arena
/// (PhotoMarkerOverlay precedent). Stateless: selection lives with the
/// caller, which passes [selectedFindingId] and receives toggle requests
/// through [onFindingTap].
class SafetyFindingsOverlay extends StatelessWidget {
  /// Lane findings, pre-filtered (chartSafetyFindings): non-dismissed,
  /// rule-enabled, start-timestamped, sorted by start time.
  final List<SafetyFinding> findings;

  final String? selectedFindingId;

  /// Visible time window in seconds (the chart's zoomed/panned X range).
  final double visibleMinSeconds;
  final double visibleMaxSeconds;

  /// Reserved axis gutters around the plot rect (the chart's _plotInsets).
  final ({double left, double top, double right, double bottom}) insets;

  final double laneHeight;

  /// Distance from the overlay's bottom edge to the lane's bottom edge
  /// (the tick-label + axis-name reservation below the lane).
  final double laneBottomOffset;

  final UnitFormatter units;

  /// Toggle request: the parent selects this finding, or clears when it is
  /// already the selection.
  final void Function(SafetyFinding finding) onFindingTap;

  final void Function(SafetyFinding finding) onFindingDismiss;

  /// Opens the finding's detail view (the safety review section). Null when
  /// no detail surface exists (fullscreen); the callout hides the link.
  final void Function(SafetyFinding finding)? onFindingDetails;

  const SafetyFindingsOverlay({
    super.key,
    required this.findings,
    required this.selectedFindingId,
    required this.visibleMinSeconds,
    required this.visibleMaxSeconds,
    required this.insets,
    required this.laneHeight,
    required this.laneBottomOffset,
    required this.units,
    required this.onFindingTap,
    required this.onFindingDismiss,
    this.onFindingDetails,
  });

  static const double _chipVerticalInset = 3.0;
  static const double _calloutMaxWidth = 280.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth - insets.left - insets.right;
        if (laneWidth <= 0 || findings.isEmpty) {
          return const SizedBox.shrink();
        }
        final placements = layoutSafetyLaneChips(
          ranges: [
            for (final f in findings)
              (
                startSeconds: f.startTimestamp!.toDouble(),
                endSeconds: (f.endTimestamp ?? f.startTimestamp!).toDouble(),
              ),
          ],
          visibleMinSeconds: visibleMinSeconds,
          visibleMaxSeconds: visibleMaxSeconds,
          laneWidth: laneWidth,
        );
        if (placements.isEmpty) return const SizedBox.shrink();

        final laneTop = constraints.maxHeight - laneBottomOffset - laneHeight;

        SafetyLaneChipPlacement? selectedPlacement;
        if (selectedFindingId != null) {
          for (final p in placements) {
            if (p.memberIndexes.any(
              (i) => findings[i].id == selectedFindingId,
            )) {
              selectedPlacement = p;
              break;
            }
          }
        }

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Lane background strip.
            Positioned(
              left: insets.left,
              top: laneTop,
              width: laneWidth,
              height: laneHeight,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < placements.length; i++)
              Positioned(
                key: ValueKey('safetyLaneChip-$i'),
                left: insets.left + placements[i].left,
                top: laneTop,
                width: placements[i].width,
                height: laneHeight,
                child: _buildChip(context, placements[i]),
              ),
            if (selectedPlacement != null)
              _buildCallout(context, constraints, laneWidth),
          ],
        );
      },
    );
  }

  /// [GestureDetector.onTap] equivalent backed by [EagerTapGestureRecognizer]
  /// so chip taps land immediately despite the chart's double-tap-to-zoom
  /// recognizer holding the arena (see PhotoMarkerOverlay).
  Widget _eagerTap({required VoidCallback onTap, required Widget child}) {
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        EagerTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<EagerTapGestureRecognizer>(
              () => EagerTapGestureRecognizer(debugOwner: this),
              (recognizer) => recognizer.onTap = onTap,
            ),
      },
      child: child,
    );
  }

  void _handleTap(List<SafetyFinding> members) {
    final selectedIdx = members.indexWhere((f) => f.id == selectedFindingId);
    if (selectedIdx == -1) {
      onFindingTap(members.first);
    } else if (selectedIdx < members.length - 1) {
      onFindingTap(members[selectedIdx + 1]);
    } else {
      // Last member selected: report it again so the parent toggle clears.
      onFindingTap(members.last);
    }
  }

  IconData _iconFor(SafetySeverity severity) {
    return switch (severity) {
      SafetySeverity.info => Icons.info_outline,
      SafetySeverity.caution => Icons.report_problem_outlined,
      SafetySeverity.significant => Icons.report_problem_outlined,
    };
  }

  Widget _buildChip(BuildContext context, SafetyLaneChipPlacement placement) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final members = [for (final i in placement.memberIndexes) findings[i]];
    // Most severe member colors the chip; enum order is info < caution <
    // significant.
    final severity = members
        .map((f) => f.severity)
        .reduce((a, b) => a.index >= b.index ? a : b);
    final severityColor = safetySeverityColor(severity, colorScheme);
    final isSelected =
        selectedFindingId != null &&
        members.any((f) => f.id == selectedFindingId);
    final dimmed = selectedFindingId != null && !isSelected;

    final semanticsLabel = members.length == 1
        ? safetyFindingTitle(members.single, l10n, units)
        : l10n.safetyReview_findingGroupSemantics(members.length);

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: _eagerTap(
        onTap: () => _handleTap(members),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: _chipVerticalInset),
          child: Container(
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: dimmed ? 0.45 : 0.9),
              borderRadius: BorderRadius.circular(
                (laneHeight - 2 * _chipVerticalInset) / 2,
              ),
              border: isSelected
                  ? Border.all(color: severityColor, width: 2)
                  : null,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _iconFor(severity),
                      size: 12,
                      color: colorScheme.surface,
                    ),
                    if (placement.width > 60 && members.length == 1) ...[
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          safetyFindingShortLabel(members.single, l10n),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colorScheme.surface,
                                fontWeight: FontWeight.w600,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
                if (members.length > 1)
                  Positioned(
                    top: -7,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${members.length}',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallout(
    BuildContext context,
    BoxConstraints constraints,
    double laneWidth,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final finding = findings.firstWhere((f) => f.id == selectedFindingId);
    final severityColor = safetySeverityColor(finding.severity, colorScheme);

    // Re-derive the selected placement's center for anchoring; build() only
    // calls this when a placement matched, so firstWhere cannot miss.
    final placements = layoutSafetyLaneChips(
      ranges: [
        for (final f in findings)
          (
            startSeconds: f.startTimestamp!.toDouble(),
            endSeconds: (f.endTimestamp ?? f.startTimestamp!).toDouble(),
          ),
      ],
      visibleMinSeconds: visibleMinSeconds,
      visibleMaxSeconds: visibleMaxSeconds,
      laneWidth: laneWidth,
    );
    final placement = placements.firstWhere(
      (p) => p.memberIndexes.any((i) => findings[i].id == selectedFindingId),
    );

    final cardWidth = math.min(_calloutMaxWidth, laneWidth);
    final chipCenter = insets.left + placement.left + placement.width / 2;
    final minLeft = insets.left;
    final maxLeft = math.max(insets.left + laneWidth - cardWidth, minLeft);
    final left = (chipCenter - cardWidth / 2).clamp(minLeft, maxLeft);

    return Positioned(
      key: const ValueKey('safetyFindingCallout'),
      left: left,
      width: cardWidth,
      bottom: laneBottomOffset + laneHeight + 6,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        color: colorScheme.surfaceContainerHigh,
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      _iconFor(finding.severity),
                      size: 16,
                      color: severityColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        safetyFindingTitle(finding, l10n, units),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.safetyReview_clearHighlight,
                    onPressed: () => onFindingTap(finding),
                  ),
                ],
              ),
              Row(
                children: [
                  if (onFindingDetails != null)
                    TextButton(
                      onPressed: () => onFindingDetails!(finding),
                      child: Text(l10n.safetyReview_details),
                    ),
                  TextButton(
                    onPressed: () => onFindingDismiss(finding),
                    child: Text(l10n.safetyReview_dismiss),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
