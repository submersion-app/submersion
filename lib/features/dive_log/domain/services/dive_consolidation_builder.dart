import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Why a consolidation was rejected outright.
enum ConsolidationInvalidReason {
  tooFewDives,
  mixedDivers,
  sameComputer,
  notOverlapping,
}

sealed class DiveConsolidationClassification {
  const DiveConsolidationClassification();
}

class ConsolidationInvalid extends DiveConsolidationClassification {
  const ConsolidationInvalid(this.reason);
  final ConsolidationInvalidReason reason;

  @override
  String toString() => 'ConsolidationInvalid(${reason.name})';
}

/// A selection ready to be consolidated: the same physical dive recorded by
/// multiple dive computers.
class ConsolidationReady extends DiveConsolidationClassification {
  const ConsolidationReady({required this.primary, required this.secondaries});
  final Dive primary;

  /// Chronological by entry time; excludes [primary].
  final List<Dive> secondaries;
}

/// Everything the consolidation service needs to persist the merge.
class DiveConsolidationPlan {
  const DiveConsolidationPlan({
    required this.primary,
    required this.secondaries,
    required this.offsetsSeconds,
    required this.tankMerges,
    required this.previewSeries,
  });

  final Dive primary;
  final List<Dive> secondaries;

  /// Source dive id -> seconds to ADD to that source's child timestamps to
  /// land on the primary's timeline. primary maps to 0; values may be
  /// negative (secondary started before the primary).
  final Map<String, int> offsetsSeconds;

  /// Secondary tank id -> primary tank id it merges into (dedup). Absent
  /// keys are kept as additional attributed tanks.
  final Map<String, String> tankMerges;

  /// Dive id -> depth series shifted onto the primary timeline (preview).
  final Map<String, List<DiveProfilePoint>> previewSeries;
}

class DiveConsolidationBuilder {
  const DiveConsolidationBuilder();

  static const double _gasTolerancePct = 0.5;
  static const double _pressureToleranceBar = 5.0;

  /// The segment's occupied span: declared runtime or last profile sample,
  /// whichever is later (same rule as DiveMergeBuilder._segmentExtent).
  Duration _extent(Dive dive) {
    var extent = dive.effectiveRuntime ?? Duration.zero;
    for (final point in dive.profile) {
      if (point.timestamp > extent.inSeconds) {
        extent = Duration(seconds: point.timestamp);
      }
    }
    return extent;
  }

  bool _overlaps(Dive a, Dive b) {
    final aStart = a.effectiveEntryTime;
    final aEnd = aStart.add(_extent(a));
    final bStart = b.effectiveEntryTime;
    final bEnd = bStart.add(_extent(b));
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  DiveConsolidationClassification classify(
    List<Dive> dives, {
    String? primaryDiveId,
  }) {
    if (dives.length < 2) {
      return const ConsolidationInvalid(ConsolidationInvalidReason.tooFewDives);
    }
    if (dives.map((d) => d.diverId).toSet().length > 1) {
      return const ConsolidationInvalid(ConsolidationInvalidReason.mixedDivers);
    }
    // Two records from the same physical computer are a re-download, not a
    // second computer. Serial is the only computer identity on the domain
    // entity; the service re-checks the computerId FK on the raw rows.
    final serials = <String>{};
    for (final d in dives) {
      final serial = d.diveComputerSerial;
      if (serial != null && serial.isNotEmpty && !serials.add(serial)) {
        return const ConsolidationInvalid(
          ConsolidationInvalidReason.sameComputer,
        );
      }
    }
    final sorted = [...dives]
      ..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));
    final primary = primaryDiveId == null
        ? sorted.first
        : sorted.firstWhere(
            (d) => d.id == primaryDiveId,
            orElse: () => sorted.first,
          );
    final secondaries = [
      for (final d in sorted)
        if (d.id != primary.id) d,
    ];
    for (final s in secondaries) {
      if (!_overlaps(primary, s)) {
        return const ConsolidationInvalid(
          ConsolidationInvalidReason.notOverlapping,
        );
      }
    }
    return ConsolidationReady(primary: primary, secondaries: secondaries);
  }

  bool _tankMatches(DiveTank primary, DiveTank secondary) {
    final o2Close =
        (primary.gasMix.o2 - secondary.gasMix.o2).abs() <= _gasTolerancePct;
    final heClose =
        (primary.gasMix.he - secondary.gasMix.he).abs() <= _gasTolerancePct;
    if (!o2Close || !heClose) return false;
    // Pressures rarely agree across computers (different logging cadence,
    // missing air-integration, etc.), so gas mix alone identifies the same
    // physical tank. Each pressure that IS reported on both sides must still
    // agree, so two genuinely different tanks sharing a gas mix (twin
    // identical cylinders, a stage on the same mix) are not merged.
    //
    // Checked pair by pair rather than all-or-nothing: requiring all four
    // values before comparing any of them means one missing reading discards
    // the evidence the other pair provides, and a tank 87 bar apart at the
    // end merges because its start pressure happens to be absent.
    if (!_pressuresAgree(primary.startPressure, secondary.startPressure)) {
      return false;
    }
    if (!_pressuresAgree(primary.endPressure, secondary.endPressure)) {
      return false;
    }
    return true;
  }

  /// Whether a pair of pressure readings is compatible.
  ///
  /// A reading missing on either side carries no evidence either way, so it
  /// cannot block a merge; two present readings must agree within tolerance.
  bool _pressuresAgree(double? primary, double? secondary) {
    if (primary == null || secondary == null) return true;
    return (primary - secondary).abs() <= _pressureToleranceBar;
  }

  DiveConsolidationPlan build(List<Dive> dives, {String? primaryDiveId}) {
    final classification = classify(dives, primaryDiveId: primaryDiveId);
    if (classification is! ConsolidationReady) {
      throw ArgumentError(
        'build() requires a consolidatable selection; got $classification',
      );
    }
    final primary = classification.primary;
    final secondaries = classification.secondaries;

    final offsets = <String, int>{
      primary.id: 0,
      for (final s in secondaries)
        s.id: s.effectiveEntryTime
            .difference(primary.effectiveEntryTime)
            .inSeconds,
    };

    final tankMerges = <String, String>{};
    final claimedPrimaryTanks = <String>{};
    for (final s in secondaries) {
      for (final tank in s.tanks) {
        for (final pTank in primary.tanks) {
          if (claimedPrimaryTanks.contains(pTank.id)) continue;
          if (_tankMatches(pTank, tank)) {
            tankMerges[tank.id] = pTank.id;
            claimedPrimaryTanks.add(pTank.id);
            break;
          }
        }
      }
    }

    final preview = <String, List<DiveProfilePoint>>{
      for (final d in [primary, ...secondaries])
        d.id: [
          for (final p in d.profile)
            DiveProfilePoint(
              timestamp: p.timestamp + (offsets[d.id] ?? 0),
              depth: p.depth,
            ),
        ],
    };

    return DiveConsolidationPlan(
      primary: primary,
      secondaries: secondaries,
      offsetsSeconds: offsets,
      tankMerges: tankMerges,
      previewSeries: preview,
    );
  }
}
