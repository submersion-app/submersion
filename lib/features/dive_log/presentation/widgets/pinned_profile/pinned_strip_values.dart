import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// What the pinned strip's last slot shows at the cursor: the no-deco limit,
/// the current stop once in deco, or nothing known.
///
/// Read from the same `DecoStatus` the deco status card reads, so the strip
/// always agrees with that card (issue #4423).
sealed class DecoSlot {
  const DecoSlot();
}

class NdlSlot extends DecoSlot {
  const NdlSlot(this.ndlSeconds);

  final int ndlSeconds;
}

class StopSlot extends DecoSlot {
  const StopSlot({required this.depthMeters, required this.durationSeconds});

  final double depthMeters;
  final int durationSeconds;
}

class UnknownDecoSlot extends DecoSlot {
  const UnknownDecoSlot();
}

/// The values the pinned profile strip shows at one cursor position, in
/// metric and unformatted.
class PinnedStripValues {
  const PinnedStripValues({
    required this.runtimeSeconds,
    required this.depthMeters,
    required this.ppO2Bar,
    required this.deco,
  });

  final int runtimeSeconds;
  final double? depthMeters;
  final double? ppO2Bar;
  final DecoSlot deco;
}

/// The strip's values at [cursorIndex], or null when there is no cursor.
///
/// [cursorIndex] indexes [chartProfile], the series the chart draws (the
/// active source's own points, #543), and the analysis curves are read at the
/// same index. A value is read straight from that index rather than looked up
/// by time, so two samples sharing a timestamp cannot swap.
PinnedStripValues? pinnedStripValuesAt({
  required List<DiveProfilePoint> chartProfile,
  required ProfileAnalysis? analysis,
  required int? cursorIndex,
}) {
  final i = cursorIndex;
  if (i == null || i < 0 || i >= chartProfile.length) return null;
  final point = chartProfile[i];

  T? curveAt<T>(List<T>? curve) =>
      (curve != null && i < curve.length) ? curve[i] : null;

  return PinnedStripValues(
    runtimeSeconds: point.timestamp,
    depthMeters: point.depth,
    ppO2Bar: curveAt(analysis?.ppO2Curve) ?? point.ppO2,
    deco: _decoSlotAt(analysis, i),
  );
}

DecoSlot _decoSlotAt(ProfileAnalysis? analysis, int index) {
  final statuses = analysis?.decoStatuses;
  if (statuses == null || index >= statuses.length) {
    return const UnknownDecoSlot();
  }
  final status = statuses[index];
  if (!status.inDeco) return NdlSlot(status.ndlSeconds);
  if (status.decoStops.isEmpty) return const UnknownDecoSlot();
  final stop = status.decoStops.first;
  return StopSlot(
    depthMeters: stop.depthMeters,
    durationSeconds: stop.durationSeconds,
  );
}

const _missing = '--';

/// The four slot strings, in order: time, depth, ppO2, NDL or stop.
List<String> formatPinnedStripValues(
  PinnedStripValues values,
  UnitFormatter units,
  AppLocalizations l10n,
) {
  final ppO2 = values.ppO2Bar;
  return [
    formatMinutesSeconds(values.runtimeSeconds),
    units.formatDepth(values.depthMeters),
    l10n.diveLog_pinnedStrip_ppO2(
      ppO2 == null ? _missing : ppO2.toStringAsFixed(2),
    ),
    switch (values.deco) {
      // Past 99 minutes is the analysis's "no limit" range (999 at the
      // surface), so it reads as more than 99 rather than a literal figure.
      NdlSlot(:final ndlSeconds) => l10n.diveLog_pinnedStrip_ndl(
        ndlSeconds > 99 * 60 ? '>99' : '${ndlSeconds ~/ 60}',
      ),
      // Rounded up, as the deco status card's stop chips are.
      StopSlot(:final depthMeters, :final durationSeconds) =>
        l10n.diveLog_pinnedStrip_stop(
          units.formatDepth(depthMeters, decimals: 0),
          '${(durationSeconds / 60).ceil()}',
        ),
      UnknownDecoSlot() => _missing,
    },
  ];
}
