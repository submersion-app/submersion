import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dashboard/presentation/home_panels.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';

final _now = DateTime(2026, 11, 20);

ServiceClockStatus _clock({
  required DateTime anchor,
  DateTime? dueDate,
  ServiceClockSeverity severity = ServiceClockSeverity.ok,
  int? divesSince,
  int? divesRemaining,
}) => ServiceClockStatus(
  schedule: ServiceSchedule(
    id: 'schedule',
    equipmentId: 'item',
    serviceKindId: 'kind',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  kind: ServiceKind(
    id: 'kind',
    name: 'Annual service',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
  anchor: anchor,
  dueDate: dueDate,
  divesSinceAnchor: divesSince,
  divesRemaining: divesRemaining,
  severity: severity,
  now: _now,
);

({EquipmentItem item, List<ServiceClockStatus> statuses}) _gear(
  String id,
  List<ServiceClockStatus> statuses,
) => (
  item: EquipmentItem(id: id, name: id, type: EquipmentType.regulator),
  statuses: statuses,
);

void main() {
  group('zeroFilledMonths', () {
    test('gives 12 months ending this month, empty months as zero', () {
      final months = zeroFilledMonths([
        MonthlyDiveCount(year: 2026, month: 1, count: 4),
        MonthlyDiveCount(year: 2025, month: 12, count: 2),
        MonthlyDiveCount(year: 2024, month: 6, count: 9),
      ], _now);
      expect(months.length, 12);
      expect((months.first.year, months.first.month), (2025, 12));
      expect((months.last.year, months.last.month), (2026, 11));
      expect(months.first.count, 2);
      expect(months[1].count, 4);
      expect(months.skip(2).every((m) => m.count == 0), isTrue);
    });
  });

  group('serviceFraction', () {
    test('is the time elapsed through the interval', () {
      final f = serviceFraction(
        _clock(anchor: DateTime(2026, 5, 20), dueDate: DateTime(2027, 5, 20)),
      );
      expect(f, closeTo(0.5, 0.01));
    });

    test('takes the larger of time and dive usage', () {
      final f = serviceFraction(
        _clock(
          anchor: DateTime(2026, 5, 20),
          dueDate: DateTime(2027, 5, 20),
          divesSince: 90,
          divesRemaining: 10,
        ),
      );
      expect(f, closeTo(0.9, 0.001));
    });

    test('overdue is full, and a clock with nothing to measure is empty', () {
      expect(
        serviceFraction(
          _clock(
            anchor: DateTime(2025),
            dueDate: DateTime(2026),
            severity: ServiceClockSeverity.overdue,
          ),
        ),
        1,
      );
      expect(serviceFraction(_clock(anchor: DateTime(2026))), 0);
    });
  });

  group('gearServiceBars', () {
    test('one bar per item, overdue first, then fullest, capped', () {
      final bars = gearServiceBars([
        _gear('bcd', [
          _clock(anchor: DateTime(2026, 8, 20), dueDate: DateTime(2027, 8, 20)),
        ]),
        _gear('reg', [
          _clock(
            anchor: DateTime(2025, 11, 1),
            dueDate: DateTime(2026, 11, 1),
            severity: ServiceClockSeverity.overdue,
          ),
          _clock(anchor: DateTime(2026, 10, 1), dueDate: DateTime(2027, 10, 1)),
        ]),
        _gear('tank', [
          _clock(anchor: DateTime(2026, 2, 20), dueDate: DateTime(2027, 2, 20)),
        ]),
        _gear('none', const []),
      ], max: 2);
      expect(bars.map((b) => b.itemName), ['reg', 'tank']);
      expect(bars.first.fraction, 1);
      expect(bars.first.status.severity, ServiceClockSeverity.overdue);
    });
  });

  group('comingDueItems', () {
    test('mixes sources, soonest first, overdue included, capped', () {
      final items = comingDueItems(
        clocks: [
          _gear('reg', [
            _clock(anchor: DateTime(2026), dueDate: DateTime(2026, 12, 11)),
          ]),
        ],
        insurance: DiverInsurance(
          provider: 'DAN',
          expiryDate: DateTime(2027, 3, 14),
        ),
        certifications: [
          (id: 'c1', name: 'Nitrox', expiry: DateTime(2026, 11, 1)),
        ],
        documents: [
          (
            id: 'd1',
            name: 'Medical',
            expiry: DateTime(2027, 6, 1),
            type: DocumentType.medicalClearance,
          ),
          (
            id: 'd2',
            name: 'Far away',
            expiry: DateTime(2030, 1, 1),
            type: DocumentType.permit,
          ),
        ],
        now: _now,
        max: 3,
      );
      expect(items.map((i) => i.name), ['Nitrox', 'reg', 'DAN']);
      expect(items.first.kind, ComingDueKind.certification);
    });

    test('documents and certifications long expired are left out', () {
      final items = comingDueItems(
        clocks: const [],
        insurance: null,
        certifications: [
          (id: 'old', name: 'First aid 2017', expiry: DateTime(2017, 5, 1)),
          (id: 'new', name: 'Nitrox', expiry: DateTime(2026, 10, 1)),
        ],
        documents: [
          (
            id: 'd',
            name: 'Medical',
            expiry: DateTime(2027, 2, 1),
            type: DocumentType.medicalClearance,
          ),
        ],
        now: _now,
      );
      expect(items.map((i) => i.name), ['Nitrox', 'Medical']);
    });

    test('an insurance record with no provider is left out', () {
      final items = comingDueItems(
        clocks: const [],
        insurance: DiverInsurance(expiryDate: DateTime(2027)),
        certifications: const [],
        documents: const [],
        now: _now,
      );
      expect(items, isEmpty);
    });
  });

  group('downsample', () {
    test('keeps the ends and never exceeds the maximum', () {
      final values = [for (var i = 0; i < 1000; i++) i.toDouble()];
      final out = downsample(values, 120);
      expect(out.length, lessThanOrEqualTo(120));
      expect(out.first, 0);
      expect(out.last, 999);
    });

    test('short lists come back unchanged', () {
      expect(downsample(const [1, 2, 3], 120), [1, 2, 3]);
      expect(downsample(const [], 120), isEmpty);
    });
  });

  group('HomeKeyNumbers.has', () {
    test('a tile with no value is absent', () {
      const n = HomeKeyNumbers(careerDives: 0, careerTimeSeconds: 0);
      expect(n.has(HomeKeyNumber.dives), isTrue);
      expect(n.has(HomeKeyNumber.timeUnder), isTrue);
      expect(n.has(HomeKeyNumber.lastDive), isFalse);
      expect(n.has(HomeKeyNumber.avgSac), isFalse);
      expect(n.has(HomeKeyNumber.nextTrip), isFalse);
      expect(n.has(HomeKeyNumber.species), isFalse);
    });
  });

  group('averageOf', () {
    test('averages, and is null when empty', () {
      expect(averageOf(const [10, 20]), 15);
      expect(averageOf(const []), isNull);
    });
  });
}
