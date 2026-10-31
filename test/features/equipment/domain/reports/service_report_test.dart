import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';

final _now = DateTime(2026, 10, 30);

EquipmentItem _item(String id, {String? parent}) => EquipmentItem(
  id: id,
  name: id,
  type: EquipmentType.regulator,
  parentEquipmentId: parent,
);

ServiceClockStatus _clock(
  String name,
  ServiceClockSeverity severity, {
  DateTime? due,
  Map<ExposureUnit, ClockUsage> usage = const {},
}) => ServiceClockStatus(
  schedule: ServiceSchedule(
    id: name,
    equipmentId: 'x',
    serviceKindId: name,
    createdAt: _now,
    updatedAt: _now,
  ),
  kind: ServiceKind(id: name, name: name, createdAt: _now, updatedAt: _now),
  anchor: DateTime(2025),
  dueDate: due,
  usageByUnit: usage,
  severity: severity,
  now: _now,
);

ServiceRecord _record(String equipmentId, DateTime date, {String? kindId}) =>
    ServiceRecord(
      id: 'r-$equipmentId-$date',
      equipmentId: equipmentId,
      serviceCategory: ServiceCategory.annual,
      serviceKindId: kindId,
      serviceDate: date,
      createdAt: _now,
      updatedAt: _now,
    );

ServiceReport _build(
  List<EquipmentItem> gear, {
  Map<String, List<ServiceClockStatus>> clocks = const {},
  Map<String, List<ServiceRecord>> records = const {},
  Map<String, ServiceKind> kinds = const {},
  Map<String, int> diveCounts = const {},
  ServiceReportOptions options = const ServiceReportOptions(),
  DateTime? tripEnd,
  String? scopeLabel,
}) => buildServiceReport(
  gear: gear,
  clocks: clocks,
  records: records,
  kindsById: kinds,
  diveCounts: diveCounts,
  options: options,
  tripEnd: tripEnd,
  scopeLabel: scopeLabel,
);

void main() {
  test('lists overdue then due soon, then by date, and leaves ok out', () {
    final report = _build(
      [_item('a'), _item('b')],
      clocks: {
        'a': [
          _clock('late', ServiceClockSeverity.dueSoon, due: DateTime(2026, 12)),
          _clock('fine', ServiceClockSeverity.ok, due: DateTime(2027)),
        ],
        'b': [
          _clock(
            'early',
            ServiceClockSeverity.dueSoon,
            due: DateTime(2026, 11),
          ),
          _clock('over', ServiceClockSeverity.overdue, due: DateTime(2026, 8)),
        ],
      },
    );

    expect(report.due.map((r) => r.status.kind.name), [
      'over',
      'early',
      'late',
    ]);
  });

  test('a due-soon clock with no date sorts after dated ones', () {
    final report = _build(
      [_item('a')],
      clocks: {
        'a': [
          _clock('usage', ServiceClockSeverity.dueSoon),
          _clock(
            'dated',
            ServiceClockSeverity.dueSoon,
            due: DateTime(2026, 11),
          ),
        ],
      },
    );
    expect(report.due.map((r) => r.status.kind.name), ['dated', 'usage']);
  });

  test('counts clocks, so the summary matches the rows', () {
    final report = _build(
      [_item('a')],
      clocks: {
        'a': [
          _clock('1', ServiceClockSeverity.overdue),
          _clock('2', ServiceClockSeverity.overdue),
          _clock('3', ServiceClockSeverity.dueSoon),
          _clock('4', ServiceClockSeverity.ok),
        ],
      },
    );
    expect(report.overdue, 2);
    expect(report.dueSoon, 1);
    expect(report.upToDate, 1);
    expect(report.due, hasLength(3));
  });

  test('one item lists every clock, ok included', () {
    final report = _build(
      [_item('a')],
      clocks: {
        'a': [_clock('fine', ServiceClockSeverity.ok)],
      },
      options: const ServiceReportOptions(
        scope: ServiceReportScope.item,
        itemId: 'a',
      ),
    );
    expect(report.due.single.severity, ServiceClockSeverity.ok);
  });

  test('a clock due before the trip ends is due soon', () {
    final report = _build(
      [_item('a')],
      clocks: {
        'a': [
          _clock('soon', ServiceClockSeverity.ok, due: DateTime(2027, 1)),
          _clock('after', ServiceClockSeverity.ok, due: DateTime(2027, 6)),
          _clock('over', ServiceClockSeverity.overdue, due: DateTime(2026)),
        ],
      },
      options: const ServiceReportOptions(
        scope: ServiceReportScope.trip,
        tripId: 't',
      ),
      tripEnd: DateTime(2027, 2),
    );

    expect(report.due.map((r) => (r.status.kind.name, r.severity)), [
      ('over', ServiceClockSeverity.overdue),
      ('soon', ServiceClockSeverity.dueSoon),
    ]);
    expect(report.upToDate, 1);
  });

  test('a usage clock is judged as of today, never forecast', () {
    final report = _build(
      [_item('a')],
      clocks: {
        'a': [
          _clock(
            'usage',
            ServiceClockSeverity.ok,
            usage: const {
              ExposureUnit.dives: ClockUsage(interval: 100, since: 90),
            },
          ),
        ],
      },
      options: const ServiceReportOptions(
        scope: ServiceReportScope.trip,
        tripId: 't',
      ),
      tripEnd: DateTime(2027, 2),
    );
    expect(report.due, isEmpty);
    expect(report.upToDate, 1);
  });

  test('a due soon usage clock is listed on a trip report', () {
    final report = _build(
      [_item('a')],
      clocks: {
        'a': [_clock('usage', ServiceClockSeverity.dueSoon)],
      },
      options: const ServiceReportOptions(
        scope: ServiceReportScope.trip,
        tripId: 't',
      ),
      tripEnd: DateTime(2027, 2),
    );
    expect(report.due.single.severity, ServiceClockSeverity.dueSoon);
  });

  test('no-schedule count covers top-level items only', () {
    final report = _build(
      [
        _item('set'),
        _item('hose', parent: 'set'),
        _item('wing'),
        _item('orphan', parent: 'gone'),
      ],
      clocks: {
        'wing': [_clock('x', ServiceClockSeverity.ok)],
      },
    );
    expect(report.noScheduleCount, 2);
  });

  test('history is newest first and skips items with no records', () {
    final report = _build(
      [_item('a'), _item('b')],
      records: {
        'a': [_record('a', DateTime(2024)), _record('a', DateTime(2025))],
      },
      diveCounts: {'a': 312},
    );

    final block = report.history.single;
    expect(block.item.id, 'a');
    expect(block.diveCount, 312);
    expect(block.rows.map((r) => r.record.serviceDate.year), [2025, 2024]);
  });

  test('history puts a part after its parent', () {
    final report = _build(
      [_item('hose', parent: 'set'), _item('set')],
      records: {
        'set': [_record('set', DateTime(2024))],
        'hose': [_record('hose', DateTime(2024))],
      },
    );
    expect(report.history.map((b) => b.item.id), ['set', 'hose']);
  });

  test('history off gives no blocks', () {
    final report = _build(
      [_item('a')],
      records: {
        'a': [_record('a', DateTime(2024))],
      },
      options: const ServiceReportOptions(includeHistory: false),
    );
    expect(report.history, isEmpty);
  });

  test('a history row carries its kind name, null with no kind', () {
    final report = _build(
      [_item('a')],
      records: {
        'a': [
          _record('a', DateTime(2025), kindId: 'k'),
          _record('a', DateTime(2024)),
        ],
      },
      kinds: {
        'k': ServiceKind(
          id: 'k',
          name: 'Annual',
          createdAt: _now,
          updatedAt: _now,
        ),
      },
    );
    expect(report.history.single.rows.map((r) => r.kindName), ['Annual', null]);
  });

  test('carries the trip or item name', () {
    expect(_build([_item('a')], scopeLabel: 'Bonaire').scopeLabel, 'Bonaire');
  });
}
