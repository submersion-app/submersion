import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/dive_sensor_summary_service.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

/// Everything the engine reads for one item. Built by the provider (or the
/// sweep) from the repositories; the engine itself touches nothing else.
class ConditionEngineInput {
  final EquipmentItem item;
  final List<EquipmentItem> children;

  /// The item's exposure samples with their dive ids, any order.
  final List<EquipmentExposureSample> samples;

  /// Sensor summaries for the sample dives that have one.
  final Map<String, DiveSensorSummary> summariesByDive;

  /// The item's own check-ins.
  final List<EquipmentObservation> observations;

  /// Incidents naming the item.
  final List<Incident> incidents;

  /// Registry serials for a transmitter item; empty for every other type.
  final Set<String> transmitterSerials;
  final ExposureThresholds thresholds;
  final DateTime now;

  const ConditionEngineInput({
    required this.item,
    required this.children,
    required this.samples,
    required this.summariesByDive,
    required this.observations,
    required this.incidents,
    required this.transmitterSerials,
    required this.thresholds,
    required this.now,
  });
}

/// One dive's reading for a slot or a serial, in date order.
typedef _Point<T> = ({String diveId, DateTime date, T value});

/// Pure and versioned: the ten spec rules over an item's evidence. Every
/// window is "the last k dives that have the relevant data", never a
/// calendar window, and every rule has a minimum n below which it is
/// silent. Every finding describes dives already logged, never a future
/// state, and carries the numbers it was built from.
class EquipmentConditionEngine {
  static const int engineVersion = 1;

  /// The rules that read the per-dive sensor summaries. Summaries are
  /// device-local, so a device that has not built them yet cannot tell
  /// whether these still fire.
  static const summaryRules = {
    ConditionRuleId.cellOutputDeclining,
    ConditionRuleId.cellOutputLow,
    ConditionRuleId.cellDivergent,
    ConditionRuleId.cellCurrentLimited,
    ConditionRuleId.transmitterDropoutRising,
    ConditionRuleId.transmitterDropoutHigh,
  };

  /// Whether any of [summaryRules] can fire for an item of [type]: the
  /// cell rules for an O2 cell or a rebreather, the dropout rules for a
  /// transmitter. No other item reads the summaries.
  static bool readsSummaries(EquipmentType type) =>
      type == EquipmentType.o2Cell ||
      type == EquipmentType.rebreather ||
      type == EquipmentType.transmitter;

  static const int declineMinDives = 10;
  static const double declineFraction = 0.15;
  static const int lowMinDives = 3;
  static const double lowGainMvPerBar = 40.0;
  static const int divergentWindow = 5;
  static const int divergentMinCount = 3;
  static const double divergentBar = 0.1;
  static const int limitedWindow = 5;
  static const int limitedMinCount = 2;
  static const double limitedFraction = 0.5;
  static const int risingMinDives = 15;
  static const double risingFloor = 0.05;
  static const int highWindow = 5;
  static const int highMinCount = 3;
  static const double highFraction = 0.10;
  static const int recurringWindow = 20;
  static const int recurringMinCount = 3;
  static const int correlationMinSide = 5;
  static const int correlationMinIssueDives = 3;
  static const double correlationRatio = 3.0;
  static const double _epsilon = 1e-9;

  const EquipmentConditionEngine();

  List<EquipmentFinding> evaluate(ConditionEngineInput input) {
    final samples = [...input.samples]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.diveId.compareTo(b.diveId);
      });
    return [
      ..._cellRules(input, samples),
      ..._transmitterRules(input, samples),
      ..._issueRecurring(input, samples),
      ..._correlation(input, samples, cold: true),
      ..._correlation(input, samples, cold: false),
      ..._incidentLinked(input),
    ];
  }

  // ---------------------------------------------------------------- cells

  List<EquipmentFinding> _cellRules(
    ConditionEngineInput input,
    List<EquipmentExposureSample> samples,
  ) {
    final item = input.item;
    if (item.type == EquipmentType.o2Cell) {
      final slot = item.cellSlot;
      if (slot == null) return const [];
      final installed = item.parentDivesFrom;
      final own = installed == null
          ? samples
          : [
              for (final s in samples)
                if (!s.date.isBefore(installed)) s,
            ];
      return _slotRules(input, own, slot, ownerId: item.id, idSlot: null);
    }
    if (item.type != EquipmentType.rebreather) return const [];

    final slots = <int>{};
    for (final s in samples) {
      final summary = input.summariesByDive[s.diveId];
      if (summary == null) continue;
      for (final c in summary.cellMetrics) {
        slots.add(c.slot);
      }
    }
    final findings = <EquipmentFinding>[];
    for (final slot in slots.toList()..sort()) {
      final newest = _newestDateWithSlot(input, samples, slot);
      final claimed =
          newest != null && _slotOccupied(input.children, slot, newest);
      if (claimed) continue;
      findings.addAll(
        _slotRules(input, samples, slot, ownerId: item.id, idSlot: slot),
      );
    }
    return findings;
  }

  /// Whether a cell child occupied [slot] on [when]. A fitted cell does
  /// from its install date on. A retired one did from its install date
  /// until the next cell in the slot went in; with no successor there is
  /// no telling when it left, so it claims nothing rather than silencing
  /// the slot on the rebreather for good.
  static bool _slotOccupied(
    List<EquipmentItem> children,
    int slot,
    DateTime when,
  ) {
    final cells = [
      for (final c in children)
        if (c.type == EquipmentType.o2Cell &&
            c.cellSlot == slot &&
            c.parentDivesFrom != null)
          c,
    ];
    for (final c in cells) {
      final from = c.parentDivesFrom!;
      if (when.isBefore(from)) continue;
      if (c.isFitted) return true;
      DateTime? until;
      for (final other in cells) {
        final start = other.parentDivesFrom!;
        if (identical(other, c) || !start.isAfter(from)) continue;
        if (until == null || start.isBefore(until)) until = start;
      }
      if (until != null && when.isBefore(until)) return true;
    }
    return false;
  }

  DateTime? _newestDateWithSlot(
    ConditionEngineInput input,
    List<EquipmentExposureSample> samples,
    int slot,
  ) {
    DateTime? newest;
    for (final s in samples) {
      final metrics = _metricsFor(input, s.diveId, slot);
      if (metrics != null) newest = s.date;
    }
    return newest;
  }

  CellMetrics? _metricsFor(
    ConditionEngineInput input,
    String diveId,
    int slot,
  ) {
    final summary = input.summariesByDive[diveId];
    if (summary == null) return null;
    for (final c in summary.cellMetrics) {
      if (c.slot == slot) return c;
    }
    return null;
  }

  List<EquipmentFinding> _slotRules(
    ConditionEngineInput input,
    List<EquipmentExposureSample> samples,
    int slot, {
    required String ownerId,
    required int? idSlot,
  }) {
    final gains = <_Point<double>>[];
    final p95s = <_Point<double>>[];
    // Every dive that reached 1.2 bar, with its fraction or null when the
    // summary could not assess one (no low-ppO2 peer agreement).
    final high = <_Point<double?>>[];
    for (final s in samples) {
      final m = _metricsFor(input, s.diveId, slot);
      if (m == null) continue;
      final gain = m.gainMvPerBar;
      if (gain != null) {
        gains.add((diveId: s.diveId, date: s.date, value: gain));
      }
      final p95 = m.p95DivergenceBar;
      if (p95 != null) p95s.add((diveId: s.diveId, date: s.date, value: p95));
      if (m.highPpO2Samples > 0) {
        high.add((diveId: s.diveId, date: s.date, value: m.lowAtHighFraction));
      }
    }
    final findings = <EquipmentFinding>[];

    EquipmentFinding make(
      ConditionRuleId rule,
      List<_Point<double>> window,
      double value,
      Map<String, double> values,
    ) => _finding(
      input,
      rule,
      ownerId,
      value: value,
      evidence: FindingEvidence(
        n: window.length,
        windowStart: window.first.date,
        windowEnd: window.last.date,
        diveIds: [for (final p in window) p.diveId],
        values: values,
        slot: slot,
      ),
      idSlot: idSlot,
    );

    if (gains.length >= declineMinDives) {
      final baseline = DiveSensorSummaryService.median([
        for (final p in gains.take(5)) p.value,
      ]);
      final recent = DiveSensorSummaryService.median([
        for (final p in _lastN(gains, 5)) p.value,
      ]);
      if (baseline > 0 &&
          recent <= (1 - declineFraction) * baseline + _epsilon) {
        findings.add(
          make(
            ConditionRuleId.cellOutputDeclining,
            gains,
            100 * (1 - recent / baseline),
            {'recentMedian': recent, 'baselineMedian': baseline},
          ),
        );
      }
    }
    if (gains.length >= lowMinDives) {
      final window = _lastN(gains, lowMinDives);
      final recent = DiveSensorSummaryService.median([
        for (final p in window) p.value,
      ]);
      if (recent < lowGainMvPerBar - _epsilon) {
        findings.add(
          make(ConditionRuleId.cellOutputLow, window, recent, {
            'recentMedian': recent,
          }),
        );
      }
    }
    if (p95s.length >= divergentWindow) {
      final window = _lastN(p95s, divergentWindow);
      final above = [
        for (final p in window)
          if (p.value > divergentBar + _epsilon) p,
      ];
      if (above.length >= divergentMinCount) {
        final worst = above.map((p) => p.value).reduce((a, b) => a > b ? a : b);
        findings.add(
          make(ConditionRuleId.cellDivergent, window, worst, {
            'worstP95': worst,
            'count': above.length.toDouble(),
          }),
        );
      }
    }
    // The last 5 dives that reached 1.2 bar, or as many as there are. A
    // dive whose fraction could not be assessed keeps its place (it is one
    // of the last five) but counts for nothing, so two old readings cannot
    // speak for a window of newer dives. From n = 2 assessed: unlike
    // cellDivergent this does not wait for a full window, since a
    // current-limited cell under-reads high ppO2, the one reading a diver
    // must be able to trust.
    final window = [
      for (final p in _lastN(high, limitedWindow))
        if (p.value case final v?) (diveId: p.diveId, date: p.date, value: v),
    ];
    if (window.length >= limitedMinCount) {
      final above = [
        for (final p in window)
          if (p.value > limitedFraction + _epsilon) p,
      ];
      if (above.length >= limitedMinCount) {
        final worst = above.map((p) => p.value).reduce((a, b) => a > b ? a : b);
        findings.add(
          make(ConditionRuleId.cellCurrentLimited, window, worst, {
            'worstFraction': worst,
            'count': above.length.toDouble(),
          }),
        );
      }
    }
    return findings;
  }

  // --------------------------------------------------------- transmitters

  List<EquipmentFinding> _transmitterRules(
    ConditionEngineInput input,
    List<EquipmentExposureSample> samples,
  ) {
    if (input.item.type != EquipmentType.transmitter) return const [];
    if (input.transmitterSerials.isEmpty) return const [];
    final fractions = <_Point<double>>[];
    for (final s in samples) {
      final summary = input.summariesByDive[s.diveId];
      if (summary == null) continue;
      double? worst;
      for (final g in summary.transmitterGaps) {
        final serial = normalizeTransmitterSerial(g.transmitterSerial);
        if (serial == null || !input.transmitterSerials.contains(serial)) {
          continue;
        }
        final f = g.gapFraction;
        if (worst == null || f > worst) worst = f;
      }
      if (worst != null) {
        fractions.add((diveId: s.diveId, date: s.date, value: worst));
      }
    }
    final findings = <EquipmentFinding>[];

    EquipmentFinding make(
      ConditionRuleId rule,
      List<_Point<double>> window,
      double value,
      Map<String, double> values,
    ) => _finding(
      input,
      rule,
      input.item.id,
      value: value,
      evidence: FindingEvidence(
        n: window.length,
        windowStart: window.first.date,
        windowEnd: window.last.date,
        diveIds: [for (final p in window) p.diveId],
        values: values,
      ),
    );

    if (fractions.length >= risingMinDives) {
      final window = _lastN(fractions, risingMinDives);
      final recent = _mean([for (final p in _lastN(window, 5)) p.value]);
      final prior = _mean([
        for (final p in window.sublist(0, window.length - 5)) p.value,
      ]);
      if (recent >= 2 * prior - _epsilon && recent >= risingFloor - _epsilon) {
        findings.add(
          make(ConditionRuleId.transmitterDropoutRising, window, recent, {
            'recentMean': recent,
            'priorMean': prior,
          }),
        );
      }
    }
    if (fractions.length >= highWindow) {
      final window = _lastN(fractions, highWindow);
      final count = window
          .where((p) => p.value >= highFraction - _epsilon)
          .length;
      if (count >= highMinCount) {
        final mean = _mean([for (final p in window) p.value]);
        findings.add(
          make(ConditionRuleId.transmitterDropoutHigh, window, mean, {
            'recentMean': mean,
            'count': count.toDouble(),
          }),
        );
      }
    }
    return findings;
  }

  // --------------------------------------------------------- observations

  List<EquipmentFinding> _issueRecurring(
    ConditionEngineInput input,
    List<EquipmentExposureSample> samples,
  ) {
    if (samples.isEmpty) return const [];
    final window = _lastN(samples, recurringWindow);
    final windowIds = {for (final s in window) s.diveId};
    // Counted per report, as the spec and the sentence ("reported 3
    // times") both say: several reports on one dive each count. The dive
    // ids are only for the evidence, where each dive is named once.
    final reportsByTag = <ObservationTag, int>{};
    final divesByTag = <ObservationTag, Set<String>>{};
    for (final o in input.observations) {
      final diveId = o.diveId;
      if (!o.isIssue || diveId == null || !windowIds.contains(diveId)) {
        continue;
      }
      for (final tag in o.issueTags) {
        reportsByTag[tag] = (reportsByTag[tag] ?? 0) + 1;
        divesByTag.putIfAbsent(tag, () => {}).add(diveId);
      }
    }
    final findings = <EquipmentFinding>[];
    for (final tag in ObservationTag.values) {
      final reports = reportsByTag[tag] ?? 0;
      if (reports < recurringMinCount) continue;
      final dives = divesByTag[tag]!;
      findings.add(
        _finding(
          input,
          ConditionRuleId.issueRecurring,
          input.item.id,
          value: reports.toDouble(),
          evidence: FindingEvidence(
            n: window.length,
            windowStart: window.first.date,
            windowEnd: window.last.date,
            diveIds: [
              for (final s in window)
                if (dives.contains(s.diveId)) s.diveId,
            ],
            values: {'count': reports.toDouble()},
            tag: tag.dbValue,
          ),
          idTag: tag.dbValue,
        ),
      );
    }
    return findings;
  }

  static const _correlatedTypes = {
    EquipmentType.regulator,
    EquipmentType.bcd,
    EquipmentType.drysuit,
    EquipmentType.light,
  };

  List<EquipmentFinding> _correlation(
    ConditionEngineInput input,
    List<EquipmentExposureSample> samples, {
    required bool cold,
  }) {
    if (!_correlatedTypes.contains(input.item.type)) return const [];
    final issueDives = {
      for (final o in input.observations)
        if (o.isIssue && o.diveId != null) o.diveId!,
    };
    final inside = <EquipmentExposureSample>[];
    final outside = <EquipmentExposureSample>[];
    for (final s in samples) {
      final bool? isInside;
      if (cold) {
        final t = s.minTemperature;
        isInside = t == null ? null : t < input.thresholds.coldWaterC;
      } else {
        final d = s.maxDepth;
        isInside = d == null ? null : d >= input.thresholds.deepDiveM;
      }
      if (isInside == null) continue;
      (isInside ? inside : outside).add(s);
    }
    if (inside.length < correlationMinSide ||
        outside.length < correlationMinSide) {
      return const [];
    }
    final insideIssue = inside
        .where((s) => issueDives.contains(s.diveId))
        .length;
    final outsideIssue = outside
        .where((s) => issueDives.contains(s.diveId))
        .length;
    if (insideIssue < correlationMinIssueDives) return const [];
    final insideShare = insideIssue / inside.length;
    final outsideShare = outsideIssue / outside.length;
    if (insideShare < correlationRatio * outsideShare - _epsilon) {
      return const [];
    }
    final floor = 1 / outside.length;
    final ratio = insideShare / (outsideShare > floor ? outsideShare : floor);
    // The dive id breaks the tie, as it does for the top-level sample
    // sort. Without it the two buckets stay glued together in the
    // encoded evidence, so an item whose cold/warm split shifts rewrites
    // and re-syncs the row without its evidence having changed.
    final all = [...inside, ...outside]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.diveId.compareTo(b.diveId);
      });
    final prefixIn = cold ? 'cold' : 'deep';
    final prefixOut = cold ? 'warm' : 'shallow';
    return [
      _finding(
        input,
        cold
            ? ConditionRuleId.issueColdCorrelated
            : ConditionRuleId.issueDeepCorrelated,
        input.item.id,
        value: ratio > 99 ? 99 : ratio,
        evidence: FindingEvidence(
          n: all.length,
          windowStart: all.first.date,
          windowEnd: all.last.date,
          diveIds: [for (final s in all) s.diveId],
          values: {
            '${prefixIn}IssueDives': insideIssue.toDouble(),
            '${prefixIn}Dives': inside.length.toDouble(),
            '${prefixOut}IssueDives': outsideIssue.toDouble(),
            '${prefixOut}Dives': outside.length.toDouble(),
          },
        ),
      ),
    ];
  }

  // ------------------------------------------------------------ incidents

  List<EquipmentFinding> _incidentLinked(ConditionEngineInput input) {
    final linked =
        [
          for (final i in input.incidents)
            if (i.equipmentId == input.item.id &&
                i.severity != IncidentSeverity.minor)
              i,
        ]..sort((a, b) {
          final byDate = a.occurredAt.compareTo(b.occurredAt);
          return byDate != 0 ? byDate : a.id.compareTo(b.id);
        });
    if (linked.isEmpty) return const [];
    return [
      _finding(
        input,
        ConditionRuleId.incidentLinked,
        input.item.id,
        value: linked.length.toDouble(),
        evidence: FindingEvidence(
          n: linked.length,
          windowStart: linked.first.occurredAt,
          windowEnd: linked.last.occurredAt,
          diveIds: [for (final i in linked) ?i.diveId],
          values: {'count': linked.length.toDouble()},
        ),
      ),
    ];
  }

  // -------------------------------------------------------------- helpers

  EquipmentFinding _finding(
    ConditionEngineInput input,
    ConditionRuleId rule,
    String ownerId, {
    required double value,
    required FindingEvidence evidence,
    int? idSlot,
    String? idTag,
  }) => EquipmentFinding(
    id: conditionFindingId(ownerId, rule, slot: idSlot, tag: idTag),
    equipmentId: ownerId,
    ruleId: rule,
    severity: rule.severity,
    value: value,
    evidence: evidence,
    evidenceFingerprint: evidenceFingerprint(evidence),
    engineVersion: engineVersion,
    createdAt: input.now,
  );

  static List<T> _lastN<T>(List<T> list, int n) =>
      list.length <= n ? list : list.sublist(list.length - n);

  static double _mean(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
}
