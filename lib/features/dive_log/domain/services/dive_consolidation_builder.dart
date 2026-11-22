import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_alignment.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';

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
  const ConsolidationReady({
    required this.primary,
    required this.secondaries,
    this.realignedIds = const {},
    this.clockMismatchIds = const {},
    this.overlapFits = const {},
    this.duplicateIds = const {},
  });
  final Dive primary;

  /// Chronological by entry time; excludes [primary].
  final List<Dive> secondaries;

  /// Secondaries whose clocks are not trusted, so `build` places them by the
  /// alignment mode (best fit without one) instead of by entry time: those
  /// that do not overlap [primary] in time, accepted only because a mode was
  /// given (#552), and every one in [clockMismatchIds].
  final Set<String> realignedIds;

  /// The secondaries in [realignedIds] that do overlap [primary] in time,
  /// but whose depth trace fits the primary's at an offset more than
  /// [DiveConsolidationBuilder.clockTolerance] away from the one their entry
  /// times give. A clock wrong by less than the dive lasted still overlaps,
  /// so overlap alone does not show the clocks agree (#4296).
  final Set<String> clockMismatchIds;

  /// Overlapping secondary id -> where [ProfileAligner] placed its trace,
  /// the fit [clockMismatchIds] was judged by. Kept so `build` does not
  /// repeat the search.
  final Map<String, ProfileAlignmentResult> overlapFits;

  /// The secondaries recorded by the primary's own computer whose trace sits
  /// inside the primary's, sample for sample: the second half of a dive the
  /// computer split in two entries, or a re-download, after the primary was
  /// already combined or imported with that stretch in it. They are folded in
  /// for their source rows (the raw bytes), not as a second computer, so what
  /// the primary already holds is not copied a second time.
  final Set<String> duplicateIds;
}

/// Everything the consolidation service needs to persist the merge.
class DiveConsolidationPlan {
  const DiveConsolidationPlan({
    required this.primary,
    required this.secondaries,
    required this.offsetsSeconds,
    required this.tankMerges,
    required this.previewSeries,
    this.alignments = const {},
    this.duplicateIds = const {},
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

  /// Realigned secondary id -> where the alignment placed it and how well
  /// its profile matches the primary's. Empty without an alignment mode.
  final Map<String, ProfileAlignmentResult> alignments;

  /// Secondaries that are an exact copy of a stretch of the primary, made by
  /// the primary's own computer; see [ConsolidationReady.duplicateIds].
  final Set<String> duplicateIds;
}

class DiveConsolidationBuilder {
  const DiveConsolidationBuilder();

  /// How far apart, in percent, two cylinders' O2 and He may be and still
  /// be the same gas: the tolerance the fold pairs cylinders by.
  static const double gasTolerancePct = 0.5;
  static const double _pressureToleranceBar = 5.0;

  /// How far a strong profile fit may sit from the entry-time offset before
  /// the two computers' clocks are judged to disagree. Wide enough for clocks
  /// set by hand a few minutes apart.
  static const Duration clockTolerance = Duration(minutes: 5);

  /// How much of a same-computer secondary has to lie inside the primary's
  /// span, and how closely its depths have to follow the primary's there, for
  /// it to count as a copy of that stretch. Far stricter than
  /// [ProfileAlignmentResult.isStrongMatch], which accepts two computers
  /// reading the same dive: one computer's own samples reappear unchanged.
  static const double duplicateMinOverlap = 0.98;
  static const double duplicateMaxRmsMeters = 0.25;

  /// How far a copy's first or last sample may stray outside the primary's span.
  static const int duplicateEdgeSeconds = 10;

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

  /// Whether [dive] records how long it lasted: a runtime (or anything
  /// [Dive.effectiveRuntime] derives one from) or a profile sample after the
  /// start. A dive logged with neither has an unknown length, not a zero one.
  bool _hasLength(Dive dive) =>
      dive.effectiveRuntime != null ||
      dive.profile.any((point) => point.timestamp > 0);

  /// Whether [a] and [b] were in the water at the same time.
  ///
  /// A dive with no runtime and no profile has no length of its own, so it
  /// is given the other dive's: its re-import, which DiveMatcher pairs with
  /// it when the two start up to minutes apart, must still fold into it
  /// (#1809). A recorded zero runtime is a length and is kept. Two dives
  /// starting at the same instant always overlap, which covers a pair that
  /// both lack a length.
  bool _overlaps(Dive a, Dive b) {
    final aExtent = _extent(a);
    final bExtent = _extent(b);
    final aStart = a.effectiveEntryTime;
    final aEnd = aStart.add(_hasLength(a) ? aExtent : bExtent);
    final bStart = b.effectiveEntryTime;
    final bEnd = bStart.add(_hasLength(b) ? bExtent : aExtent);
    if (aStart.isAtSameMomentAs(bStart)) return true;
    return aStart.isBefore(bEnd) && bStart.isBefore(aEnd);
  }

  /// Whether [secondary], which overlaps [primary] in time, is the same dive
  /// on a computer whose clock is wrong: its depth trace [fit] matches the
  /// primary's strongly, at an offset more than [clockTolerance] away from
  /// the one the entry times give, and the trace does not also fit where the
  /// clock puts it. A record that logged only part of the primary (one half
  /// of a combined dive) can match a look-alike stretch near lined-up starts
  /// while its clock already places it right. A weak fit, or none, leaves
  /// the clocks trusted.
  bool _clockDisagrees(
    Dive primary,
    Dive secondary,
    ProfileAlignmentResult fit,
  ) {
    if (!fit.isStrongMatch) return false;
    final byClock = secondary.effectiveEntryTime
        .difference(primary.effectiveEntryTime)
        .inSeconds;
    if ((fit.offsetSeconds - byClock).abs() <= clockTolerance.inSeconds) {
      return false;
    }
    return !const ProfileAligner()
        .scoreAt(primary.profile, secondary.profile, byClock)
        .isStrongMatch;
  }

  /// Whether [a] and [b] came from one physical computer, judged by serial and
  /// by the linked computer since either can be missing. The service
  /// re-checks the computerId FK on the raw rows before writing.
  bool _sameComputer(Dive a, Dive b) {
    final aSerial = a.diveComputerSerial;
    final bSerial = b.diveComputerSerial;
    if (aSerial != null && aSerial.isNotEmpty && aSerial == bSerial) {
      return true;
    }
    final aId = a.computerId;
    return aId != null && aId == b.computerId;
  }

  /// Whether [secondary] is a copy of a stretch of [primary]: its trace,
  /// placed where the two entry times put it, lies inside the primary's and
  /// follows it within [duplicateMaxRmsMeters]. The clock offset is the right
  /// placement because both came from one clock; an offset search would only
  /// add ways to match by accident.
  bool _isContainedDuplicate(Dive primary, Dive secondary) {
    final byClock = secondary.effectiveEntryTime
        .difference(primary.effectiveEntryTime)
        .inSeconds;
    final fit = const ProfileAligner().scoreAt(
      primary.profile,
      secondary.profile,
      byClock,
    );
    final rms = fit.rmsDepthError;
    if (fit.usedFallback ||
        rms == null ||
        fit.overlapFraction < duplicateMinOverlap ||
        rms > duplicateMaxRmsMeters) {
      return false;
    }
    // The fit is measured against the shorter trace, so it holds just as well
    // when the primary is the one inside the secondary. Only the copy may sit
    // inside the primary's span, never the other way round.
    int first(Dive d) =>
        d.profile.map((p) => p.timestamp).reduce((a, b) => a < b ? a : b);
    int last(Dive d) =>
        d.profile.map((p) => p.timestamp).reduce((a, b) => a > b ? a : b);
    return first(secondary) + byClock >=
            first(primary) - duplicateEdgeSeconds &&
        last(secondary) + byClock <= last(primary) + duplicateEdgeSeconds;
  }

  /// [alignment] null rejects a secondary that does not overlap the primary
  /// in time. With a mode, that secondary is accepted and listed in
  /// [ConsolidationReady.realignedIds] for `build` to align. An overlapping
  /// secondary whose clock disagrees with the primary's is listed there with
  /// or without a mode, and in [ConsolidationReady.clockMismatchIds].
  DiveConsolidationClassification classify(
    List<Dive> dives, {
    String? primaryDiveId,
    ConsolidationAlignment? alignment,
  }) {
    if (dives.length < 2) {
      return const ConsolidationInvalid(ConsolidationInvalidReason.tooFewDives);
    }
    if (dives.map((d) => d.diverId).toSet().length > 1) {
      return const ConsolidationInvalid(ConsolidationInvalidReason.mixedDivers);
    }
    final sorted = [...dives]
      ..sort((a, b) => a.effectiveEntryTime.compareTo(b.effectiveEntryTime));
    // The primary's timeline is the one that survives, so the default is the
    // earliest dive that happened: a plan is a guess at those times, and the
    // no-fly clock runs from the end they give (issue #3924).
    final earliest =
        sorted.where((d) => !d.isPlanned).firstOrNull ?? sorted.first;
    // Two records that start together, a whole dive and a copy of its first
    // stretch, default to the longer: only the copy can sit inside the other.
    final fallback = sorted
        .where(
          (d) =>
              d.isPlanned == earliest.isPlanned &&
              d.effectiveEntryTime.isAtSameMomentAs(
                earliest.effectiveEntryTime,
              ),
        )
        .reduce((a, b) => _extent(b) > _extent(a) ? b : a);
    final primary = primaryDiveId == null
        ? fallback
        : sorted.firstWhere(
            (d) => d.id == primaryDiveId,
            orElse: () => fallback,
          );
    final secondaries = [
      for (final d in sorted)
        if (d.id != primary.id) d,
    ];
    // Two records from the same physical computer are a re-download or a
    // dive it split in two, not a second computer, so they are not folded in
    // as one. The exception is a record that is nothing but a copy of a
    // stretch of the primary: a half the primary already contains, imported
    // again on its own. That folds in for its raw bytes and adds nothing else
    // (#1913's duplicates from before the import started recognising them).
    // Two copies that overlap each other are the same stretch downloaded
    // twice: the service compares each copy only with what the target held
    // before the fold, so both would add whatever the target lacked.
    final duplicates = <String>{};
    final duplicateDives = <Dive>[];
    for (final s in secondaries) {
      if (_sameComputer(primary, s)) {
        if (!_isContainedDuplicate(primary, s) ||
            duplicateDives.any((d) => _overlaps(d, s))) {
          return const ConsolidationInvalid(
            ConsolidationInvalidReason.sameComputer,
          );
        }
        duplicates.add(s.id);
        duplicateDives.add(s);
      } else if (secondaries.any((o) => o.id != s.id && _sameComputer(o, s))) {
        return const ConsolidationInvalid(
          ConsolidationInvalidReason.sameComputer,
        );
      }
    }
    final realigned = <String>{};
    final clockMismatch = <String>{};
    final overlapFits = <String, ProfileAlignmentResult>{};
    for (final s in secondaries) {
      if (_overlaps(primary, s)) {
        final fit = overlapFits[s.id] = const ProfileAligner().align(
          primary.profile,
          s.profile,
        );
        if (_clockDisagrees(primary, s, fit)) {
          realigned.add(s.id);
          clockMismatch.add(s.id);
        }
        continue;
      }
      if (alignment == null) {
        return const ConsolidationInvalid(
          ConsolidationInvalidReason.notOverlapping,
        );
      }
      realigned.add(s.id);
    }
    return ConsolidationReady(
      primary: primary,
      secondaries: secondaries,
      realignedIds: realigned,
      clockMismatchIds: clockMismatch,
      overlapFits: overlapFits,
      duplicateIds: duplicates,
    );
  }

  /// Whether two tanks are the same physical cylinder, judged by their
  /// air-integration transmitter serials.
  ///
  /// Returns true when both carry the same serial, false when both carry a
  /// serial and they differ, and null when either side lacks one so the
  /// caller must fall back to the gas-mix heuristic. The serial is read from
  /// the transmitter itself, so it identifies the cylinder regardless of
  /// which gas each computer had programmed for it: two computers paired to
  /// one transmitter with 31% on one and 32% on the other still logged the
  /// same tank.
  bool? _serialIdentity(DiveTank primary, DiveTank secondary) {
    final a = normalizeTransmitterSerial(primary.transmitterSerial);
    final b = normalizeTransmitterSerial(secondary.transmitterSerial);
    if (a == null || b == null) return null;
    return a == b;
  }

  /// [comparePressures] false pairs by gas alone: for a copy of a stretch of
  /// the primary, whose cylinder starts at the pressure the split left it at,
  /// not the fill the primary records.
  bool _tankMatches(
    DiveTank primary,
    DiveTank secondary, {
    bool comparePressures = true,
  }) {
    final bySerial = _serialIdentity(primary, secondary);
    if (bySerial != null) return bySerial;
    // Without a serial, a suit inflation bottle is only ever the same
    // cylinder as another suit bottle: an air bottle must not fold into air
    // back gas (issue #4243), where its pressure would count toward SAC.
    if (primary.role.isBreathingGas != secondary.role.isBreathingGas) {
      return false;
    }
    final o2Close =
        (primary.gasMix.o2 - secondary.gasMix.o2).abs() <= gasTolerancePct;
    final heClose =
        (primary.gasMix.he - secondary.gasMix.he).abs() <= gasTolerancePct;
    if (!o2Close || !heClose) return false;
    if (!comparePressures) return true;
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

  /// The primary cylinder that [tank] of a same-computer copy is, among
  /// those not yet [claimed], or null when none can be told for sure.
  ///
  /// The copy's pressures need not equal the primary's (a second half starts
  /// at the pressure the split left it at), but each must lie within the
  /// primary cylinder's own fill-to-end range. Several cylinders of one gas
  /// that all fit are told apart by position, since one computer lists its
  /// cylinders in one order; failing that, the copy's cylinder stays its own
  /// rather than taking one at a guess with another cylinder's pressures.
  DiveTank? _copyTankMatch(
    List<DiveTank> primaryTanks,
    DiveTank tank,
    Set<String> claimed,
  ) {
    final fits = [
      for (final p in primaryTanks)
        if (!claimed.contains(p.id) &&
            _tankMatches(p, tank, comparePressures: false) &&
            _withinRange(p, tank.startPressure) &&
            _withinRange(p, tank.endPressure))
          p,
    ];
    if (fits.length == 1) return fits.single;
    return fits.where((p) => p.order == tank.order).singleOrNull;
  }

  /// Whether [reading] could be a pressure [primary] passed through: no more
  /// than its fill, no less than where it ended. A side the primary does not
  /// report bounds nothing.
  bool _withinRange(DiveTank primary, double? reading) {
    if (reading == null) return true;
    final start = primary.startPressure;
    final end = primary.endPressure;
    if (start != null && reading > start + _pressureToleranceBar) return false;
    if (end != null && reading < end - _pressureToleranceBar) return false;
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

  /// [classified] is [classify]'s result for these same arguments when the
  /// caller already has it, so the profile fits it holds are not searched
  /// for again.
  DiveConsolidationPlan build(
    List<Dive> dives, {
    String? primaryDiveId,
    ConsolidationAlignment? alignment,
    DiveConsolidationClassification? classified,
  }) {
    final classification =
        classified ??
        classify(dives, primaryDiveId: primaryDiveId, alignment: alignment);
    if (classification is! ConsolidationReady) {
      throw ArgumentError(
        'build() requires a consolidatable selection; got $classification',
      );
    }
    final primary = classification.primary;
    final secondaries = classification.secondaries;

    // A realigned secondary's clock disagrees with the primary's, so its
    // entry time would reproduce that error. The best-fit score is kept
    // under "starts" too, so the same-dive hint does not change when the user
    // flips the toggle. Only a clock mismatch is realigned without a mode,
    // and its fit is a strong one, so best fit is the default.
    final alignments = <String, ProfileAlignmentResult>{
      for (final s in secondaries)
        if (classification.realignedIds.contains(s.id))
          s.id: _aligned(
            primary,
            s,
            alignment ?? ConsolidationAlignment.bestFit,
            fit: classification.overlapFits[s.id],
          ),
    };
    final offsets = <String, int>{
      primary.id: 0,
      for (final s in secondaries)
        s.id:
            alignments[s.id]?.offsetSeconds ??
            s.effectiveEntryTime
                .difference(primary.effectiveEntryTime)
                .inSeconds,
    };

    // Each secondary claims primary tanks independently: three computers on
    // one transmitter all merge into the same primary tank. Within a single
    // secondary a claim is exclusive, so two of its tanks on the same mix
    // stay two cylinders.
    //
    // Two passes per secondary: transmitter serials first, so a tank whose
    // serial names a specific primary tank claims that one before a
    // serial-less primary tank on the same mix can take it; then the gas-mix
    // heuristic for what is left.
    final tankMerges = <String, String>{};
    for (final s in secondaries) {
      final claimedPrimaryTanks = <String>{};
      for (final tank in s.tanks) {
        for (final pTank in primary.tanks) {
          if (claimedPrimaryTanks.contains(pTank.id)) continue;
          if (_serialIdentity(pTank, tank) == true) {
            tankMerges[tank.id] = pTank.id;
            claimedPrimaryTanks.add(pTank.id);
            break;
          }
        }
      }
      final isCopy = classification.duplicateIds.contains(s.id);
      for (final tank in s.tanks) {
        if (tankMerges.containsKey(tank.id)) continue;
        final pTank = isCopy
            ? _copyTankMatch(primary.tanks, tank, claimedPrimaryTanks)
            : primary.tanks
                  .where(
                    (p) =>
                        !claimedPrimaryTanks.contains(p.id) &&
                        _tankMatches(p, tank),
                  )
                  .firstOrNull;
        if (pTank != null) {
          tankMerges[tank.id] = pTank.id;
          claimedPrimaryTanks.add(pTank.id);
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
      alignments: alignments,
      duplicateIds: classification.duplicateIds,
    );
  }

  ProfileAlignmentResult _aligned(
    Dive primary,
    Dive secondary,
    ConsolidationAlignment alignment, {
    ProfileAlignmentResult? fit,
  }) {
    final placed =
        fit ?? const ProfileAligner().align(primary.profile, secondary.profile);
    return switch (alignment) {
      ConsolidationAlignment.bestFit => placed,
      ConsolidationAlignment.starts => placed.copyWith(offsetSeconds: 0),
    };
  }
}
