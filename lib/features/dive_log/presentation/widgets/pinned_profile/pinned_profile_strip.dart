import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_tracking_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/mini_profile_picker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_geometry.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/pinned_strip_values.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_metric_colors.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Height of the curve above the strip's values row.
const double _curveHeight = 40;

/// The thin, scrubbable dive profile pinned at the top of dive details once
/// the full profile card scrolls away (issue #4423).
///
/// It reads and writes the same shared cursor as the full chart,
/// [profileTrackingIndexProvider], so every card that follows the chart
/// follows the strip too. Like the full chart, lifting a finger or moving the
/// mouse away clears the cursor.
class PinnedProfileStrip extends ConsumerStatefulWidget {
  const PinnedProfileStrip({super.key, required this.dive});

  final Dive dive;

  @override
  ConsumerState<PinnedProfileStrip> createState() => _PinnedProfileStripState();
}

class _PinnedProfileStripState extends ConsumerState<PinnedProfileStrip> {
  /// Whether the hint speaks to touch. Starts from the platform and follows
  /// whichever kind of pointer last reached the strip.
  late bool _touch = switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android || TargetPlatform.fuchsia =>
      true,
    _ => false,
  };

  String get _diveId => widget.dive.id;

  void _write(int? index) {
    final notifier = ref.read(profileTrackingIndexProvider(_diveId).notifier);
    if (notifier.state != index) notifier.state = index;
  }

  void _scrubTo(double dx, double width, List<DiveProfilePoint> profile) {
    if (profile.length < 2 || width <= 0) return;
    final first = profile.first.timestamp;
    final span = profile.last.timestamp - first;
    final seconds = first + (dx / width).clamp(0.0, 1.0) * span;
    _write(indexForTimestamp(profile, seconds.round()));
  }

  void _noteKind(PointerDeviceKind kind) {
    final touch = kind == PointerDeviceKind.touch ||
        kind == PointerDeviceKind.stylus ||
        kind == PointerDeviceKind.invertedStylus;
    if (touch != _touch) setState(() => _touch = touch);
  }

  @override
  Widget build(BuildContext context) {
    final profile = watchChartProfile(ref, widget.dive);
    final cursor = ref.watch(profileTrackingIndexProvider(_diveId));
    final sourceId = ref.watch(activeDiveSourceProvider(_diveId));
    final analysis = ref
        .watch(sourceProfileAnalysisProvider((diveId: _diveId, sourceId: sourceId)))
        .value;
    final units = ref.watch(unitFormatterProvider);
    final values = pinnedStripValuesAt(
      chartProfile: profile,
      analysis: analysis,
      cursorIndex: cursor,
    );
    final colors = Theme.of(context).colorScheme;
    final selectedSeconds =
        cursor != null && cursor >= 0 && cursor < profile.length
        ? profile[cursor].timestamp
        : null;

    return Semantics(
      container: true,
      label: context.l10n.diveLog_pinnedStrip_semantics,
      child: Material(
        color: colors.surface,
        elevation: 2,
        child: SizedBox(
          height: kPinnedStripHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Listener(
                onPointerDown: (e) => _noteKind(e.kind),
                onPointerHover: (e) => _noteKind(e.kind),
                child: MouseRegion(
                  onHover: (e) => _scrubTo(e.localPosition.dx, width, profile),
                  onExit: (_) => _write(null),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) =>
                        _scrubTo(d.localPosition.dx, width, profile),
                    onTapUp: (_) => _write(null),
                    onTapCancel: () => _write(null),
                    onHorizontalDragStart: (d) =>
                        _scrubTo(d.localPosition.dx, width, profile),
                    onHorizontalDragUpdate: (d) =>
                        _scrubTo(d.localPosition.dx, width, profile),
                    onHorizontalDragEnd: (_) => _write(null),
                    onHorizontalDragCancel: () => _write(null),
                    child: Column(
                      children: [
                        SizedBox(
                          height: _curveHeight,
                          width: width,
                          child: CustomPaint(
                            painter: MiniProfilePainter(
                              profile: profile,
                              selectedSeconds: selectedSeconds,
                              curveColor: ProfileMetricColors.depth,
                              fillColor: ProfileMetricColors.depth.withValues(
                                alpha: 0.18,
                              ),
                              markerColor: colors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: values == null
                              ? _Hint(touch: _touch)
                              : _ValuesRow(values: values, units: units),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.touch});

  final bool touch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(
        touch
            ? context.l10n.diveLog_pinnedStrip_hintDrag
            : context.l10n.diveLog_pinnedStrip_hintHover,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _ValuesRow extends StatelessWidget {
  const _ValuesRow({required this.values, required this.units});

  final PinnedStripValues values;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Row(
      children: [
        for (final text in formatPinnedStripValues(values, units, context.l10n))
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          ),
      ],
    );
  }
}
