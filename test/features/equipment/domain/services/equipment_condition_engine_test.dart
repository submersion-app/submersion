import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_finding.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/services/equipment_condition_engine.dart';
import 'package:submersion/features/equipment/domain/services/exposure_classifier.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/safety/domain/entities/incident.dart';

void main() {
  const engine = EquipmentConditionEngine();
  final now = DateTime.utc(2026, 9, 9);

  EquipmentItem item(String id, EquipmentType type, {String? parent}) =>
      EquipmentItem(
        id: id,
        name: id,
        type: type,
        parentEquipmentId: parent,
        createdAt: DateTime.utc(2025),
      );

  EquipmentItem cell(String id, int slot, {DateTime? installed}) =>
      EquipmentItem(
        id: id,
        name: id,
        type: EquipmentType.o2Cell,
        parentEquipmentId: 'ccr',
        createdAt: DateTime.utc(2025),
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: id,
            key: EquipmentAttrKeys.cellSlot,
            valueNum: slot.toDouble(),
          ),
          EquipmentAttribute.curated(
            equipmentId: id,
            key: EquipmentAttrKeys.installedDate,
            valueNum: (installed ?? DateTime.utc(2025)).millisecondsSinceEpoch
                .toDouble(),
          ),
        ],
      );

  /// Dive i happens on 2026-01-(i+1); ids are d0, d1, ...
  EquipmentExposureSample sample(
    int i, {
    double? minTemp = 20,
    double? maxDepth = 15,
  }) => EquipmentExposureSample(
    diveId: 'd$i',
    date: DateTime.utc(2026, 1, 1).add(Duration(days: i)),
    durationSeconds: 3000,
    minTemperature: minTemp,
    maxDepth: maxDepth,
    updatedAt: 1,
  );

  DiveSensorSummary summary(
    String diveId, {
    List<CellMetrics> cells = const [],
    List<TransmitterGap> gaps = const [],
  }) => DiveSensorSummary(
    diveId: diveId,
    engineVersion: 1,
    sourceUpdatedAt: 1,
    computedAt: now,
    cellMetrics: cells,
    transmitterGaps: gaps,
  );

  EquipmentObservation issue(
    String id,
    String equipmentId,
    String diveId,
    ObservationTag tag,
  ) => EquipmentObservation(
    id: id,
    equipmentId: equipmentId,
    diveId: diveId,
    observedAt: now,
    status: ObservationStatus.issue,
    issueTags: [tag],
    createdAt: now,
    updatedAt: now,
  );

  ConditionEngineInput input({
    required EquipmentItem item,
    List<EquipmentItem> children = const [],
    List<EquipmentExposureSample> samples = const [],
    Map<String, DiveSensorSummary> summaries = const {},
    List<EquipmentObservation> observations = const [],
    List<Incident> incidents = const [],
    Set<String> serials = const {},
  }) => ConditionEngineInput(
    item: item,
    children: children,
    samples: samples,
    summariesByDive: summaries,
    observations: observations,
    incidents: incidents,
    transmitterSerials: serials,
    thresholds: ExposureThresholds.defaults,
    now: now,
  );

  List<EquipmentFinding> of(
    List<EquipmentFinding> findings,
    ConditionRuleId rule,
  ) => findings.where((f) => f.ruleId == rule).toList();

  group('cell rules on a cell child', () {
    /// [gains] per dive, slot 2, on the CCR's dives.
    ConditionEngineInput cellInput(
      List<num?> gains, {
      List<num?>? p95,
      List<num?>? lowAtHigh,
      List<int>? highSamples,
    }) {
      final samples = [for (var i = 0; i < gains.length; i++) sample(i)];
      final summaries = {
        for (var i = 0; i < gains.length; i++)
          'd$i': summary(
            'd$i',
            cells: [
              CellMetrics(
                slot: 2,
                samples: 100,
                gainMvPerBar: gains[i]?.toDouble(),
                p95DivergenceBar: p95?[i]?.toDouble(),
                highPpO2Samples: highSamples?[i] ?? 0,
                lowAtHighFraction: lowAtHigh?[i]?.toDouble(),
              ),
            ],
          ),
      };
      return input(item: cell('c2', 2), samples: samples, summaries: summaries);
    }

    test('cellOutputDeclining needs 10 dives and a 15 percent drop', () {
      // First five at 50, then 41 (18 percent below).
      final nine = [50.0, 50, 50, 50, 50, 41, 41, 41, 41];
      expect(
        of(
          engine.evaluate(cellInput(nine)),
          ConditionRuleId.cellOutputDeclining,
        ),
        isEmpty,
      );
      final ten = [...nine, 41.0];
      final found = of(
        engine.evaluate(cellInput(ten)),
        ConditionRuleId.cellOutputDeclining,
      ).single;
      expect(found.id, 'cf_c2_cellOutputDeclining');
      expect(found.severity, ConditionSeverity.caution);
      expect(found.value, closeTo(18, 1e-9));
      expect(found.evidence.n, 10);
      expect(found.evidence.values['recentMedian'], 41);
      expect(found.evidence.values['baselineMedian'], 50);
      expect(found.evidence.diveIds, hasLength(10));
      expect(found.evidence.slot, 2);

      // A 14 percent drop does not fire.
      final mild = [50.0, 50, 50, 50, 50, 43, 43, 43, 43, 43];
      expect(
        of(
          engine.evaluate(cellInput(mild)),
          ConditionRuleId.cellOutputDeclining,
        ),
        isEmpty,
      );
    });

    test('same-instant evidence keeps one order whatever the input order', () {
      // The rule splits the dives into cold and warm and joins the two
      // back together. Sorting that by date alone leaves every tie in
      // bucket order, which is not the dive order. The encoded evidence
      // keeps whatever order comes out, and saveReview compares the
      // encoding, so a shifted split would rewrite and re-sync the row.
      List<String> idsFor(List<EquipmentExposureSample> ordered) {
        final found = of(
          engine.evaluate(
            input(
              item: item('reg', EquipmentType.regulator),
              samples: ordered,
              observations: [
                for (var i = 0; i < 6; i += 2)
                  issue('o$i', 'reg', 'd$i', ObservationTag.freeFlow),
              ],
            ),
          ),
          ConditionRuleId.issueColdCorrelated,
        );
        return found.single.evidence.diveIds;
      }

      // Five cold and five warm dives, every one on the same instant,
      // interleaved so the cold group followed by the warm group is not
      // the same order as the dive ids.
      EquipmentExposureSample tiedSample(int i, double temp) =>
          EquipmentExposureSample(
            diveId: 'd$i',
            date: DateTime.utc(2026, 1, 1),
            durationSeconds: 3000,
            minTemperature: temp,
            maxDepth: 15,
            updatedAt: 1,
          );
      final tied = [
        for (var i = 0; i < 10; i++) tiedSample(i, i.isEven ? 4 : 25),
      ];
      // Handed to the engine backwards, the evidence still comes out in
      // one order, decided by the dive id once the dates tie.
      const ascending = [
        'd0',
        'd1',
        'd2',
        'd3',
        'd4',
        'd5',
        'd6',
        'd7',
        'd8',
        'd9',
      ];
      expect(idsFor(tied), ascending);
      expect(idsFor(tied.reversed.toList()), ascending);
    });

    test('the decline baseline stays anchored at install', () {
      // The baseline is deliberately the FIRST five dives since install,
      // not a rolling window: a cell wears out gradually, and a baseline
      // that drifted along with it would subtract the very decline the
      // rule exists to catch. Output here falls 0.6 percent per dive, so
      // the last five sit 15.2 percent below the first five and the rule
      // fires, while against the five dives just before them the gap is
      // only 3.5 percent and a rolling window would say nothing at all.
      final fading = [for (var i = 0; i < 30; i++) 60.0 * (1 - 0.006 * i)];
      final found = of(
        engine.evaluate(cellInput(fading)),
        ConditionRuleId.cellOutputDeclining,
      ).single;
      expect(found.value, greaterThan(15));
      // Every dive since install is the evidence, which is what the
      // sentence claims: "fell N percent across 30 dives since <date>".
      expect(found.evidence.n, 30);
    });

    test('cellOutputLow needs 3 dives with a median under 40', () {
      expect(
        of(engine.evaluate(cellInput([39, 39])), ConditionRuleId.cellOutputLow),
        isEmpty,
      );
      final found = of(
        engine.evaluate(cellInput([50, 39, 38, 39])),
        ConditionRuleId.cellOutputLow,
      ).single;
      expect(found.severity, ConditionSeverity.significant);
      expect(found.value, 39);
      expect(found.evidence.n, 3);
      expect(
        of(
          engine.evaluate(cellInput([40, 40, 40])),
          ConditionRuleId.cellOutputLow,
        ),
        isEmpty,
      );
    });

    test('cellDivergent needs 3 of the last 5 dives above 0.1 bar', () {
      final gains = List<num?>.filled(5, 50);
      final two = [0.05, 0.2, 0.05, 0.2, 0.05];
      expect(
        of(
          engine.evaluate(cellInput(gains, p95: two)),
          ConditionRuleId.cellDivergent,
        ),
        isEmpty,
      );
      final three = [0.05, 0.2, 0.15, 0.2, 0.05];
      final found = of(
        engine.evaluate(cellInput(gains, p95: three)),
        ConditionRuleId.cellDivergent,
      ).single;
      expect(found.value, 0.2);
      expect(found.evidence.values['count'], 3);
      expect(found.evidence.n, 5);
      // Four dives is below the minimum.
      expect(
        of(
          engine.evaluate(cellInput(gains.sublist(1), p95: three.sublist(1))),
          ConditionRuleId.cellDivergent,
        ),
        isEmpty,
      );
    });

    test('cellCurrentLimited needs 2 of the last 5 high dives above 0.5', () {
      final gains = List<num?>.filled(5, 50);
      final high = [10, 10, 10, 10, 10];
      final one = [0.6, 0.1, 0.1, 0.1, 0.1];
      expect(
        of(
          engine.evaluate(cellInput(gains, lowAtHigh: one, highSamples: high)),
          ConditionRuleId.cellCurrentLimited,
        ),
        isEmpty,
      );
      final two = [0.6, 0.1, 0.8, 0.1, 0.1];
      final found = of(
        engine.evaluate(cellInput(gains, lowAtHigh: two, highSamples: high)),
        ConditionRuleId.cellCurrentLimited,
      ).single;
      expect(found.severity, ConditionSeverity.significant);
      expect(found.value, 0.8);
      expect(found.evidence.values['count'], 2);
      // The rule speaks from n = 2: a current-limited cell under-reads high
      // ppO2, which is worth warning about before five such dives exist.
      // Two qualifying dives, both limited, raise it over a window of two.
      final early = of(
        engine.evaluate(
          cellInput(
            List<num?>.filled(2, 50),
            lowAtHigh: [0.6, 0.8],
            highSamples: [10, 10],
          ),
        ),
        ConditionRuleId.cellCurrentLimited,
      ).single;
      expect(early.evidence.n, 2);
      expect(early.evidence.values['count'], 2);
      // One qualifying dive is under the minimum, however bad it reads.
      expect(
        of(
          engine.evaluate(
            cellInput(
              List<num?>.filled(1, 50),
              lowAtHigh: [0.9],
              highSamples: [10],
            ),
          ),
          ConditionRuleId.cellCurrentLimited,
        ),
        isEmpty,
      );

      // A high dive whose fraction could not be assessed still takes its
      // place in "the last 5 that reached 1.2 bar": two old limited dives
      // must not fire the rule once five newer high dives have passed.
      final stale = [0.6, 0.8, null, null, null, null, null];
      expect(
        of(
          engine.evaluate(
            cellInput(
              List<num?>.filled(7, 50),
              lowAtHigh: stale,
              highSamples: List.filled(7, 10),
            ),
          ),
          ConditionRuleId.cellCurrentLimited,
        ),
        isEmpty,
      );
      // Unassessable dives in the window count for nothing either way: two
      // limited among the last five still fire it.
      final mixed = of(
        engine.evaluate(
          cellInput(
            List<num?>.filled(7, 50),
            lowAtHigh: [0.1, 0.1, 0.9, null, 0.7, null, null],
            highSamples: List.filled(7, 10),
          ),
        ),
        ConditionRuleId.cellCurrentLimited,
      ).single;
      expect(mixed.evidence.values['count'], 2);

      // Dives that never reached 1.2 bar are not in the window.
      final noHigh = [0, 0, 0, 0, 0];
      expect(
        of(
          engine.evaluate(
            cellInput(gains, lowAtHigh: two, highSamples: noHigh),
          ),
          ConditionRuleId.cellCurrentLimited,
        ),
        isEmpty,
      );
    });
  });

  test('a cell with no install date owns dives from its creation', () {
    // Every dive reads low, but the cell was created on the seventh: it
    // owns two dives, under the three the low-output rule needs.
    final samples = [for (var i = 0; i < 8; i++) sample(i)];
    final summaries = {
      for (var i = 0; i < 8; i++)
        'd$i': summary(
          'd$i',
          cells: const [CellMetrics(slot: 2, samples: 10, gainMvPerBar: 30)],
        ),
    };
    final uninstalled = EquipmentItem(
      id: 'c2',
      name: 'c2',
      type: EquipmentType.o2Cell,
      parentEquipmentId: 'ccr',
      createdAt: DateTime.utc(2026, 1, 7),
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: 'c2',
          key: EquipmentAttrKeys.cellSlot,
          valueNum: 2,
        ),
      ],
    );
    expect(
      of(
        engine.evaluate(
          input(item: uninstalled, samples: samples, summaries: summaries),
        ),
        ConditionRuleId.cellOutputLow,
      ),
      isEmpty,
    );
  });

  group('cell rules on a rebreather without a child in the slot', () {
    test('the finding attaches to the rebreather with the slot in the id', () {
      final samples = [for (var i = 0; i < 3; i++) sample(i)];
      final summaries = {
        for (var i = 0; i < 3; i++)
          'd$i': summary(
            'd$i',
            cells: const [
              CellMetrics(slot: 1, samples: 10, gainMvPerBar: 30),
              CellMetrics(slot: 3, samples: 10, gainMvPerBar: 55),
            ],
          ),
      };
      final findings = engine.evaluate(
        input(
          item: item('ccr', EquipmentType.rebreather),
          samples: samples,
          summaries: summaries,
        ),
      );
      final low = of(findings, ConditionRuleId.cellOutputLow).single;
      expect(low.id, 'cf_ccr_cellOutputLow_1');
      expect(low.equipmentId, 'ccr');
      expect(low.evidence.slot, 1);
    });

    test('a slot with a child item is left to the child', () {
      final samples = [for (var i = 0; i < 3; i++) sample(i)];
      final summaries = {
        for (var i = 0; i < 3; i++)
          'd$i': summary(
            'd$i',
            cells: const [CellMetrics(slot: 1, samples: 10, gainMvPerBar: 30)],
          ),
      };
      final findings = engine.evaluate(
        input(
          item: item('ccr', EquipmentType.rebreather),
          children: [cell('c1', 1)],
          samples: samples,
          summaries: summaries,
        ),
      );
      expect(of(findings, ConditionRuleId.cellOutputLow), isEmpty);
    });

    test('a child installed after the dives does not claim them', () {
      final samples = [for (var i = 0; i < 3; i++) sample(i)];
      final summaries = {
        for (var i = 0; i < 3; i++)
          'd$i': summary(
            'd$i',
            cells: const [CellMetrics(slot: 1, samples: 10, gainMvPerBar: 30)],
          ),
      };
      final findings = engine.evaluate(
        input(
          item: item('ccr', EquipmentType.rebreather),
          children: [cell('c1', 1, installed: DateTime.utc(2027))],
          samples: samples,
          summaries: summaries,
        ),
      );
      expect(
        of(findings, ConditionRuleId.cellOutputLow).single.id,
        'cf_ccr_cellOutputLow_1',
      );
    });

    group('a retired cell', () {
      // Replacing a part retires it and installs a successor in the slot.
      // The retired cell occupied the slot until the successor's install
      // date; with no successor there is no way to tell when it left.
      final lowOnSlotOne = {
        for (var i = 0; i < 3; i++)
          'd$i': summary(
            'd$i',
            cells: const [CellMetrics(slot: 1, samples: 10, gainMvPerBar: 30)],
          ),
      };
      final samples = [for (var i = 0; i < 3; i++) sample(i)];
      EquipmentItem retired(EquipmentItem c) =>
          c.copyWith(isActive: false, status: EquipmentStatus.retired);

      test('keeps its dives while its successor has none yet', () {
        final findings = engine.evaluate(
          input(
            item: item('ccr', EquipmentType.rebreather),
            children: [
              retired(cell('old', 1, installed: DateTime.utc(2025))),
              cell('new', 1, installed: DateTime.utc(2027)),
            ],
            samples: samples,
            summaries: lowOnSlotOne,
          ),
        );
        // The dives were the retired cell's, not the rebreather's to
        // report about a cell that has already been replaced.
        expect(of(findings, ConditionRuleId.cellOutputLow), isEmpty);
      });

      test('a legacy retired row still flagged active is not fitted', () {
        // Older rows can carry a retired or sold status with isActive
        // left true; the repository treats both statuses as terminal.
        final findings = engine.evaluate(
          input(
            item: item('ccr', EquipmentType.rebreather),
            children: [
              cell(
                'old',
                1,
                installed: DateTime.utc(2025),
              ).copyWith(status: EquipmentStatus.retired),
            ],
            samples: samples,
            summaries: lowOnSlotOne,
          ),
        );
        expect(
          of(findings, ConditionRuleId.cellOutputLow).single.id,
          'cf_ccr_cellOutputLow_1',
        );
      });

      test('a slot replaced twice stays with its cells', () {
        // Each retired cell holds the slot until the NEXT cell went in, not
        // the last one: the middle cell's dives are its own.
        final findings = engine.evaluate(
          input(
            item: item('ccr', EquipmentType.rebreather),
            children: [
              retired(cell('old', 1, installed: DateTime.utc(2025))),
              retired(cell('middle', 1, installed: DateTime.utc(2026, 1, 2))),
              cell('new', 1, installed: DateTime.utc(2027)),
            ],
            samples: samples,
            summaries: lowOnSlotOne,
          ),
        );
        expect(of(findings, ConditionRuleId.cellOutputLow), isEmpty);
      });

      test('with no successor leaves the slot to the rebreather', () {
        // Claiming forever would silence the slot for good once cells
        // are retired without being replaced.
        final findings = engine.evaluate(
          input(
            item: item('ccr', EquipmentType.rebreather),
            children: [retired(cell('old', 1, installed: DateTime.utc(2025)))],
            samples: samples,
            summaries: lowOnSlotOne,
          ),
        );
        expect(
          of(findings, ConditionRuleId.cellOutputLow).single.id,
          'cf_ccr_cellOutputLow_1',
        );
      });
    });
  });

  group('transmitter rules', () {
    ConditionEngineInput gapInput(List<double> fractions) {
      final samples = [for (var i = 0; i < fractions.length; i++) sample(i)];
      final summaries = {
        for (var i = 0; i < fractions.length; i++)
          'd$i': summary(
            'd$i',
            gaps: [
              TransmitterGap(
                tankId: 't',
                transmitterSerial: '180777',
                cadenceSeconds: 10,
                gapSeconds: (fractions[i] * 1000).round(),
                gapCount: fractions[i] > 0 ? 1 : 0,
                longestGapSeconds: (fractions[i] * 1000).round(),
                diveSeconds: 1000,
              ),
              // Another transmitter's tank on the same dive is ignored.
              const TransmitterGap(
                tankId: 'other',
                transmitterSerial: '999',
                cadenceSeconds: 10,
                gapSeconds: 900,
                gapCount: 1,
                longestGapSeconds: 900,
                diveSeconds: 1000,
              ),
            ],
          ),
      };
      return input(
        item: item('tx', EquipmentType.transmitter),
        samples: samples,
        summaries: summaries,
        serials: {'180777'},
      );
    }

    test('transmitterDropoutRising needs 15 dives and a doubling', () {
      final fourteen = [...List.filled(9, 0.03), ...List.filled(5, 0.08)];
      expect(
        of(
          engine.evaluate(gapInput(fourteen)),
          ConditionRuleId.transmitterDropoutRising,
        ),
        isEmpty,
      );
      final fifteen = [...List.filled(10, 0.03), ...List.filled(5, 0.08)];
      final found = of(
        engine.evaluate(gapInput(fifteen)),
        ConditionRuleId.transmitterDropoutRising,
      ).single;
      expect(found.severity, ConditionSeverity.caution);
      expect(found.value, closeTo(0.08, 1e-9));
      expect(found.evidence.values['priorMean'], closeTo(0.03, 1e-9));
      expect(found.evidence.n, 15);
      // Doubled but under the 0.05 floor.
      final quiet = [...List.filled(10, 0.01), ...List.filled(5, 0.03)];
      expect(
        of(
          engine.evaluate(gapInput(quiet)),
          ConditionRuleId.transmitterDropoutRising,
        ),
        isEmpty,
      );
    });

    test('transmitterDropoutHigh needs 3 of the last 5 at or above 0.10', () {
      final two = [0.0, 0.2, 0.0, 0.2, 0.0];
      expect(
        of(
          engine.evaluate(gapInput(two)),
          ConditionRuleId.transmitterDropoutHigh,
        ),
        isEmpty,
      );
      final three = [0.0, 0.2, 0.1, 0.2, 0.0];
      final found = of(
        engine.evaluate(gapInput(three)),
        ConditionRuleId.transmitterDropoutHigh,
      ).single;
      expect(found.severity, ConditionSeverity.significant);
      expect(found.value, closeTo(0.1, 1e-9));
      expect(found.evidence.values['count'], 3);
    });

    test('a dive counts the worst gap among the item\'s serials', () {
      // One transmitter item can feed two tanks (two registry serials); a
      // dive's figure is its worst gap, whichever tank reports it first.
      TransmitterGap gap(String serial, double fraction) => TransmitterGap(
        tankId: serial,
        transmitterSerial: serial,
        cadenceSeconds: 10,
        gapSeconds: (fraction * 1000).round(),
        gapCount: fraction > 0 ? 1 : 0,
        longestGapSeconds: (fraction * 1000).round(),
        diveSeconds: 1000,
      );
      final found = of(
        engine.evaluate(
          input(
            item: item('tx', EquipmentType.transmitter),
            samples: [for (var i = 0; i < 5; i++) sample(i)],
            summaries: {
              for (var i = 0; i < 5; i++)
                'd$i': summary(
                  'd$i',
                  gaps: [gap('180778', 0.2), gap('180777', 0.0)],
                ),
            },
            serials: {'180777', '180778'},
          ),
        ),
        ConditionRuleId.transmitterDropoutHigh,
      ).single;
      expect(found.value, closeTo(0.2, 1e-9));
      expect(found.evidence.values['count'], 5);
    });

    test('a transmitter with no registry serial reads nothing', () {
      final fifteen = [...List.filled(10, 0.03), ...List.filled(5, 0.2)];
      final noSerial = ConditionEngineInput(
        item: item('tx', EquipmentType.transmitter),
        children: const [],
        samples: gapInput(fifteen).samples,
        summariesByDive: gapInput(fifteen).summariesByDive,
        observations: const [],
        incidents: const [],
        transmitterSerials: const {},
        thresholds: ExposureThresholds.defaults,
        now: now,
      );
      expect(engine.evaluate(noSerial), isEmpty);
    });
  });

  group('observation rules', () {
    test('issueRecurring needs 3 of the same tag within the last 20 dives', () {
      final samples = [for (var i = 0; i < 25; i++) sample(i)];
      // Dive d3 is outside the last 20 (d5..d24).
      final two = [
        issue('o1', 'reg', 'd10', ObservationTag.freeFlow),
        issue('o2', 'reg', 'd12', ObservationTag.freeFlow),
        issue('o3', 'reg', 'd3', ObservationTag.freeFlow),
      ];
      expect(
        of(
          engine.evaluate(
            input(
              item: item('reg', EquipmentType.regulator),
              samples: samples,
              observations: two,
            ),
          ),
          ConditionRuleId.issueRecurring,
        ),
        isEmpty,
      );
      final three = [
        ...two,
        issue('o4', 'reg', 'd20', ObservationTag.freeFlow),
        issue('o5', 'reg', 'd21', ObservationTag.leak),
      ];
      final found = of(
        engine.evaluate(
          input(
            item: item('reg', EquipmentType.regulator),
            samples: samples,
            observations: three,
          ),
        ),
        ConditionRuleId.issueRecurring,
      ).single;
      expect(found.id, 'cf_reg_issueRecurring_freeFlow');
      expect(found.value, 3);
      expect(found.evidence.tag, 'freeFlow');
      expect(found.evidence.diveIds, unorderedEquals(['d10', 'd12', 'd20']));
      expect(found.evidence.n, 20);
    });

    test('issueRecurring counts reports, and names each dive once', () {
      // The spec counts observations, and the sentence reads "reported
      // 3 times": three free-flow reports on one dive are three reports.
      final samples = [for (var i = 0; i < 25; i++) sample(i)];
      final found = of(
        engine.evaluate(
          input(
            item: item('reg', EquipmentType.regulator),
            samples: samples,
            observations: [
              issue('o1', 'reg', 'd20', ObservationTag.freeFlow),
              issue('o2', 'reg', 'd20', ObservationTag.freeFlow),
              issue('o3', 'reg', 'd20', ObservationTag.freeFlow),
            ],
          ),
        ),
        ConditionRuleId.issueRecurring,
      ).single;
      expect(found.value, 3);
      expect(found.evidence.values['count'], 3);
      expect(found.evidence.diveIds, ['d20']);
    });

    test('a dive exactly on a threshold sides with the classifier', () {
      // These two comparisons are deliberately bare, unlike the rule
      // boundaries that carry _epsilon: those weigh a COMPUTED median,
      // mean or ratio, where accumulated error can straddle a round
      // number. Here a stored reading meets a diver-set threshold with no
      // arithmetic on either side, and the answer has to be the one
      // ExposureClassifier gives, or the same dive would count as cold for
      // the exposure total and warm for this rule.
      const thresholds = ExposureThresholds.defaults;
      const classifier = ExposureClassifier(thresholds: thresholds);
      final atCold = sample(0, minTemp: thresholds.coldWaterC);
      final atDeep = sample(1, maxDepth: thresholds.deepDiveM);

      // Cold is strictly below the line, deep is at it or beyond.
      expect(classifier.contribution(atCold, ExposureUnit.coldDives), 0);
      expect(classifier.contribution(atDeep, ExposureUnit.deepCycles), 1);

      // The rule agrees: five dives exactly on the cold line are all warm,
      // so a cold correlation has nothing on its cold side to report.
      final onTheLine = [
        for (var i = 0; i < 5; i++) sample(i, minTemp: thresholds.coldWaterC),
        for (var i = 5; i < 10; i++) sample(i, minTemp: 25),
      ];
      expect(
        of(
          engine.evaluate(
            input(
              item: item('reg', EquipmentType.regulator),
              samples: onTheLine,
              observations: [
                for (var i = 0; i < 3; i++)
                  issue('o$i', 'reg', 'd$i', ObservationTag.freeFlow),
              ],
            ),
          ),
          ConditionRuleId.issueColdCorrelated,
        ),
        isEmpty,
      );
    });

    test('issueColdCorrelated needs 5 dives each side and 3 cold issues', () {
      // 5 cold dives (d0..d4 at 4 C), 5 warm (d5..d9 at 25 C).
      final samples = [
        for (var i = 0; i < 5; i++) sample(i, minTemp: 4),
        for (var i = 5; i < 10; i++) sample(i, minTemp: 25),
      ];
      final twoCold = [
        issue('o1', 'reg', 'd0', ObservationTag.freeFlow),
        issue('o2', 'reg', 'd1', ObservationTag.freeFlow),
      ];
      expect(
        of(
          engine.evaluate(
            input(
              item: item('reg', EquipmentType.regulator),
              samples: samples,
              observations: twoCold,
            ),
          ),
          ConditionRuleId.issueColdCorrelated,
        ),
        isEmpty,
      );
      final threeCold = [
        ...twoCold,
        issue('o3', 'reg', 'd2', ObservationTag.freeFlow),
      ];
      final found = of(
        engine.evaluate(
          input(
            item: item('reg', EquipmentType.regulator),
            samples: samples,
            observations: threeCold,
          ),
        ),
        ConditionRuleId.issueColdCorrelated,
      ).single;
      expect(found.severity, ConditionSeverity.info);
      expect(found.evidence.values['coldIssueDives'], 3);
      expect(found.evidence.values['coldDives'], 5);
      expect(found.evidence.values['warmIssueDives'], 0);
      expect(found.evidence.values['warmDives'], 5);
      expect(found.value, greaterThan(0));

      // One warm issue: cold share 0.6, warm 0.2, exactly three times.
      final oneWarm = [
        ...threeCold,
        issue('o4', 'reg', 'd7', ObservationTag.freeFlow),
      ];
      expect(
        of(
          engine.evaluate(
            input(
              item: item('reg', EquipmentType.regulator),
              samples: samples,
              observations: oneWarm,
            ),
          ),
          ConditionRuleId.issueColdCorrelated,
        ).single.value,
        closeTo(3, 1e-9),
      );
      // Two warm issues: 0.6 versus 0.4, under three times.
      final twoWarm = [
        ...oneWarm,
        issue('o5', 'reg', 'd8', ObservationTag.freeFlow),
      ];
      expect(
        of(
          engine.evaluate(
            input(
              item: item('reg', EquipmentType.regulator),
              samples: samples,
              observations: twoWarm,
            ),
          ),
          ConditionRuleId.issueColdCorrelated,
        ),
        isEmpty,
      );
      // Only regulators, BCDs, drysuits and lights are judged.
      expect(
        of(
          engine.evaluate(
            input(
              item: item('fins', EquipmentType.fins),
              samples: samples,
              observations: [
                for (final o in threeCold) o.copyWith(equipmentId: 'fins'),
              ],
            ),
          ),
          ConditionRuleId.issueColdCorrelated,
        ),
        isEmpty,
      );
    });

    test('issueDeepCorrelated uses the deep line', () {
      final samples = [
        for (var i = 0; i < 5; i++) sample(i, maxDepth: 35),
        for (var i = 5; i < 10; i++) sample(i, maxDepth: 12),
      ];
      final threeDeep = [
        issue('o1', 'bcd', 'd0', ObservationTag.inflatorStuck),
        issue('o2', 'bcd', 'd1', ObservationTag.inflatorStuck),
        issue('o3', 'bcd', 'd3', ObservationTag.dumpLeak),
      ];
      final found = of(
        engine.evaluate(
          input(
            item: item('bcd', EquipmentType.bcd),
            samples: samples,
            observations: threeDeep,
          ),
        ),
        ConditionRuleId.issueDeepCorrelated,
      ).single;
      expect(found.evidence.values['deepIssueDives'], 3);
      expect(found.evidence.values['deepDives'], 5);
      expect(found.evidence.values['shallowDives'], 5);
    });
  });

  group('incidentLinked', () {
    Incident incident(String id, IncidentSeverity severity, {String? diveId}) =>
        Incident(
          id: id,
          diveId: diveId,
          equipmentId: 'reg',
          occurredAt: now,
          category: IncidentCategory.equipment,
          severity: severity,
          narrative: 'n',
          createdAt: now,
          updatedAt: now,
        );

    test('minor incidents do not count; moderate and serious do', () {
      expect(
        of(
          engine.evaluate(
            input(
              item: item('reg', EquipmentType.regulator),
              incidents: [incident('i1', IncidentSeverity.minor)],
            ),
          ),
          ConditionRuleId.incidentLinked,
        ),
        isEmpty,
      );
      final found = of(
        engine.evaluate(
          input(
            item: item('reg', EquipmentType.regulator),
            incidents: [
              incident('i1', IncidentSeverity.minor),
              incident('i2', IncidentSeverity.moderate),
              incident('i3', IncidentSeverity.serious),
            ],
          ),
        ),
        ConditionRuleId.incidentLinked,
      ).single;
      expect(found.severity, ConditionSeverity.info);
      expect(found.value, 2);
      expect(found.evidence.n, 2);
      expect(found.engineVersion, EquipmentConditionEngine.engineVersion);
      expect(found.createdAt, now);
    });

    test('incidents on the same instant are ordered by their id', () {
      // Every incident here shares an instant, so only the id decides.
      // The order reaches the stored evidence, and saveReview compares
      // the encoding, so a wobble would rewrite and re-sync the row.
      final found = of(
        engine.evaluate(
          input(
            item: item('reg', EquipmentType.regulator),
            incidents: [
              incident('i3', IncidentSeverity.moderate, diveId: 'd3'),
              incident('i1', IncidentSeverity.moderate, diveId: 'd1'),
              incident('i2', IncidentSeverity.moderate, diveId: 'd2'),
            ],
          ),
        ),
        ConditionRuleId.incidentLinked,
      ).single;
      expect(found.evidence.diveIds, ['d1', 'd2', 'd3']);
    });
  });

  test('an item with nothing behind it yields no findings', () {
    expect(
      engine.evaluate(input(item: item('mask', EquipmentType.mask))),
      isEmpty,
    );
  });
}
