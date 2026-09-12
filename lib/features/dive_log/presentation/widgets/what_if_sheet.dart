import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/services/dive_to_plan_converter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Present the "What if..." sheet as a modal bottom sheet.
///
/// Converts [dive] into an unsaved dive plan and opens it in the planner so
/// the diver can vary depth, time and gas and see the effect on deco/gas
/// relative to what they actually did.
Future<void> showWhatIfSheet(BuildContext context, Dive dive) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => WhatIfSheet(dive: dive),
  );
}

class WhatIfSheet extends ConsumerStatefulWidget {
  const WhatIfSheet({super.key, required this.dive});

  final Dive dive;

  @override
  ConsumerState<WhatIfSheet> createState() => _WhatIfSheetState();
}

class _WhatIfSheetState extends ConsumerState<WhatIfSheet> {
  int _levels = 3;
  bool _seedTissues = true;
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final profileAsync = ref.watch(diveProfileProvider(widget.dive.id));
    final precedingAsync = ref.watch(
      _precedingDiveWithin24hProvider(widget.dive.id),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                context.l10n.diveLog_whatIf_title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            profileAsync.when(
              data: (profile) => _WhatIfPreview(
                profile: profile,
                levels: _levels,
                units: units,
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.diveLog_whatIf_engineNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(context.l10n.diveLog_whatIf_detailLabel),
                Expanded(
                  child: Slider(
                    value: _levels.toDouble(),
                    min: 1,
                    max: 5,
                    divisions: 4,
                    label: '$_levels',
                    onChanged: (v) => setState(() => _levels = v.round()),
                  ),
                ),
                Text('$_levels'),
              ],
            ),
            precedingAsync.maybeWhen(
              data: (preceding) => preceding == null
                  ? const SizedBox.shrink()
                  : SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _seedTissues,
                      title: Text(context.l10n.diveLog_whatIf_seedTissues),
                      onChanged: (v) => setState(() => _seedTissues = v),
                    ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : () => _openInPlanner(units),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.l10n.diveLog_whatIf_openInPlanner),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openInPlanner(UnitFormatter units) async {
    setState(() => _loading = true);
    final dive = widget.dive;

    final profile = await ref.read(diveProfileProvider(dive.id).future);
    final gasSwitchesWithTank = await ref.read(
      gasSwitchesProvider(dive.id).future,
    );

    List<TissueCompartment> tissueCompartments = const [];
    Duration? surfaceInterval;
    // Replay this dive as it started. Seeding from THIS dive's end tissues
    // plus "now" would plan a repetitive after it and inflate TTS.
    if (_seedTissues) {
      final preceding = await ref.read(
        _precedingDiveWithin24hProvider(dive.id).future,
      );
      if (preceding != null) {
        final analysis = await ref.read(
          profileAnalysisProvider(preceding.id).future,
        );
        if (analysis != null && analysis.decoStatuses.isNotEmpty) {
          tissueCompartments = analysis.decoStatuses.last.compartments;
        }
        final precedingEnd = (preceding.entryTime ?? preceding.dateTime).add(
          preceding.effectiveRuntime ?? Duration.zero,
        );
        final diveStart = dive.entryTime ?? dive.dateTime;
        var interval = diveStart.difference(precedingEnd);
        if (interval.isNegative) interval = Duration.zero;
        surfaceInterval = interval;
      }
    }

    if (!mounted) return;

    final notifier = ref.read(divePlanNotifierProvider.notifier);
    // Resets to a fresh plan first so the converter can reuse exactly the
    // rates/GF/reserve/SAC defaults a brand-new plan would get (seeded from
    // the diver's live deco settings), rather than inventing its own.
    notifier.newPlan();
    final defaults = ref.read(divePlanNotifierProvider);

    final title = (dive.name?.isNotEmpty ?? false)
        ? dive.name!
        : units.formatDate(dive.entryTime ?? dive.dateTime);

    final gasSwitches = gasSwitchesWithTank.map((g) => g.gasSwitch).toList();
    final converted = const DiveToPlanConverter().convert(
      dive: dive,
      profile: profile,
      gasSwitches: gasSwitches,
      levels: _levels,
      planName: context.l10n.diveLog_whatIf_planName(title),
      defaults: defaults,
      initialTissueState: tissueCompartments.isEmpty
          ? null
          : tissueCompartments,
      surfaceInterval: surfaceInterval,
    );

    notifier.loadPlan(converted);

    if (!mounted) return;
    Navigator.of(context).pop();
    context.push('/planning/dive-planner');
  }
}

/// Preceding dive within 24h of [diveId]'s entry time, for the tissue-seeding
/// switch. Mirrors the lookback `FollowDiveSheet` performs, over the same
/// dive list.
final _precedingDiveWithin24hProvider = FutureProvider.family<Dive?, String>((
  ref,
  diveId,
) async {
  final dive = await ref.watch(diveProvider(diveId).future);
  if (dive == null) return null;
  final dives = await ref.watch(divesProvider.future);
  final entry = dive.entryTime ?? dive.dateTime;

  Dive? best;
  for (final other in dives) {
    if (other.id == diveId) continue;
    final otherEnd = (other.entryTime ?? other.dateTime).add(
      other.effectiveRuntime ?? Duration.zero,
    );
    if (otherEnd.isAfter(entry)) continue;
    if (entry.difference(otherEnd) > const Duration(hours: 24)) continue;
    if (best == null) {
      best = other;
    } else {
      final bestEnd = (best.entryTime ?? best.dateTime).add(
        best.effectiveRuntime ?? Duration.zero,
      );
      if (otherEnd.isAfter(bestEnd)) best = other;
    }
  }
  return best;
});

/// Draws the real profile with the simplified level profile overlaid.
class _WhatIfPreview extends StatelessWidget {
  const _WhatIfPreview({
    required this.profile,
    required this.levels,
    required this.units,
  });

  final List<DiveProfilePoint> profile;
  final int levels;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    if (profile.length < 2) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 140,
      child: CustomPaint(
        painter: _WhatIfPreviewPainter(
          profile: profile,
          levels: levels,
          units: units,
          actualColor: scheme.onSurfaceVariant,
          levelColor: scheme.primary,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _WhatIfPreviewPainter extends CustomPainter {
  _WhatIfPreviewPainter({
    required this.profile,
    required this.levels,
    required this.units,
    required this.actualColor,
    required this.levelColor,
  });

  final List<DiveProfilePoint> profile;
  final int levels;
  final UnitFormatter units;
  final Color actualColor;
  final Color levelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;

    final maxTime = profile.last.timestamp.toDouble();
    var maxDepth = 0.0;
    for (final p in profile) {
      if (p.depth > maxDepth) maxDepth = p.depth;
    }
    if (maxTime <= 0 || maxDepth <= 0) return;

    const labelWidth = 32.0;
    final chartWidth = size.width - labelWidth;

    Offset toOffset(int t, double d) => Offset(
      labelWidth + (t / maxTime) * chartWidth,
      (d / maxDepth) * size.height,
    );

    // Actual profile.
    final actualPaint = Paint()
      ..color = actualColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final actualPath = Path()
      ..moveTo(
        toOffset(profile.first.timestamp, profile.first.depth).dx,
        toOffset(profile.first.timestamp, profile.first.depth).dy,
      );
    for (final p in profile.skip(1)) {
      final o = toOffset(p.timestamp, p.depth);
      actualPath.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(actualPath, actualPaint);

    // Depth axis labels.
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (final fraction in [0.0, 0.5, 1.0]) {
      final depth = maxDepth * fraction;
      textPainter.text = TextSpan(
        text: units.formatDepth(depth, decimals: 0),
        style: TextStyle(color: actualColor, fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(0, (depth / maxDepth) * size.height - textPainter.height / 2),
      );
    }

    // Simplified level overlay, recomputed live as the slider moves.
    final simplified = _simplifyForPreview(profile, levels);
    if (simplified.length >= 2) {
      final levelPaint = Paint()
        ..color = levelColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final levelPath = Path()
        ..moveTo(
          toOffset(
            simplified.first.$1 + profile.first.timestamp,
            simplified.first.$2,
          ).dx,
          toOffset(
            simplified.first.$1 + profile.first.timestamp,
            simplified.first.$2,
          ).dy,
        );
      for (final (t, d) in simplified.skip(1)) {
        final o = toOffset(t + profile.first.timestamp, d);
        levelPath.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(levelPath, levelPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhatIfPreviewPainter oldDelegate) =>
      oldDelegate.levels != levels || oldDelegate.profile != profile;
}

/// The waypoints the converter will actually produce, as (elapsed seconds,
/// depth) pairs relative to the first sample, so the sketch matches the plan.
List<(int, double)> _simplifyForPreview(
  List<DiveProfilePoint> profile,
  int levels,
) {
  if (profile.length < 2) return const [];
  final points = const DiveToPlanConverter().breakpoints(
    profile: profile,
    gasSwitches: const [],
    levels: levels,
  );
  return [for (final p in points) (p.timeSeconds, p.depth)];
}
