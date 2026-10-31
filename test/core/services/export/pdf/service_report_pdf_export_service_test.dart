import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/pdf/service_report_pdf_export_service.dart';
import 'package:submersion/core/services/export/pdf/equipment_report_pdf_parts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_unit.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/pdf_roboto.dart';
import '../../../../helpers/pdf_text.dart';

final _now = DateTime(2026, 10, 30);

EquipmentItem _item(String name, {String? serial}) => EquipmentItem(
  id: name,
  name: name,
  type: EquipmentType.regulator,
  serialNumber: serial,
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

ServiceRecord _record(
  String equipmentId, {
  double? cost,
  String currency = 'USD',
  String? provider,
  int year = 2025,
}) => ServiceRecord(
  id: 'r-$equipmentId-$year',
  equipmentId: equipmentId,
  serviceCategory: ServiceCategory.annual,
  serviceDate: DateTime(year, 8, 12),
  cost: cost,
  currency: currency,
  provider: provider,
  createdAt: _now,
  updatedAt: _now,
);

ServiceReport _report(
  List<EquipmentItem> gear, {
  Map<String, List<ServiceClockStatus>> clocks = const {},
  Map<String, List<ServiceRecord>> records = const {},
  ServiceReportOptions options = const ServiceReportOptions(),
  String? scopeLabel,
}) => buildServiceReport(
  gear: gear,
  clocks: clocks,
  records: records,
  kindsById: const {},
  diveCounts: {for (final item in gear) item.id: 312},
  options: options,
  fallbackCurrency: 'USD',
  scopeLabel: scopeLabel,
);

void main() {
  late ServiceReportPdfExportService service;
  const units = UnitFormatter(AppSettings());

  setUpAll(loadPdfRoboto);
  tearDownAll(unloadPdfRoboto);

  setUp(
    () => service = ServiceReportPdfExportService(
      loadTheme: (_) async => pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    ),
  );

  Future<String> text(
    ServiceReport report, {
    ServiceReportOptions options = const ServiceReportOptions(),
  }) async => pdfVisibleText(
    await service.generateBytes(
      report,
      options: options,
      settings: ReportPrintSettings(
        diverName: 'Sam Diver',
        units: units,
        printedAt: _now,
      ),
    ),
  );

  test('page one has the summary, the due table and the trip name', () async {
    final out = await text(
      _report(
        [_item('Apex')],
        clocks: {
          'Apex': [
            _clock(
              'Annual service',
              ServiceClockSeverity.overdue,
              due: DateTime(2026, 8, 12),
            ),
            _clock(
              'Inspection',
              ServiceClockSeverity.dueSoon,
              due: DateTime(2026, 12, 1),
            ),
            _clock('Battery', ServiceClockSeverity.ok, due: DateTime(2028)),
          ],
        },
        scopeLabel: 'Bonaire',
      ),
    );

    expect(out, contains('Service report'));
    expect(out, contains('Sam Diver'));
    expect(out, contains('Bonaire'));
    expect(out, contains('overdue'));
    expect(out, contains('due soon'));
    expect(out, contains('up to date'));
    expect(out, contains('Annual service'));
    expect(out, contains('Overdue'));
    expect(out, contains('Due soon'));
    expect(out, isNot(contains('Battery')));
  });

  test('nothing due prints Everything is up to date.', () async {
    final out = await text(
      _report(
        [_item('Apex')],
        clocks: {
          'Apex': [_clock('Annual', ServiceClockSeverity.ok)],
        },
      ),
    );
    expect(out, contains('Everything is up to date.'));
  });

  test('no clocks at all never claims everything is up to date', () async {
    final out = await text(_report([_item('Apex')]));
    expect(out, isNot(contains('Everything is up to date.')));
  });

  test('Due uses the shared trigger text', () async {
    final out = await text(
      _report(
        [_item('Teric')],
        clocks: {
          'Teric': [
            _clock(
              'Battery',
              ServiceClockSeverity.dueSoon,
              usage: const {
                ExposureUnit.dives: ClockUsage(interval: 300, since: 288),
              },
            ),
          ],
        },
      ),
    );
    expect(out, contains('12'));
    expect(out, contains('left'));
  });

  test('says how many items have no service schedule', () async {
    final out = await text(_report([_item('a'), _item('b')]));
    expect(out, contains('2 items have no service schedule.'));
  });

  test('history pages show date, work, shop and cost', () async {
    final out = await text(
      _report(
        [_item('Apex', serial: 'F-20419')],
        records: {
          'Apex': [_record('Apex', cost: 145, provider: 'Blue Water')],
        },
      ),
    );

    expect(out, contains('F-20419'));
    expect(out, contains('312 dives'));
    expect(out, contains('Blue Water'));
    expect(out, contains('Annual'));
    expect(out, contains(r'$145'));
  });

  test('a blank currency prints in the default currency', () async {
    final out = await text(
      _report(
        [_item('Apex')],
        records: {
          'Apex': [_record('Apex', cost: 145, currency: '')],
        },
      ),
    );
    expect(out, contains(r'$145'));
  });

  test('show costs off removes the Cost column and every amount', () async {
    const options = ServiceReportOptions(showCosts: false);
    final out = await text(
      _report(
        [_item('Apex')],
        records: {
          'Apex': [_record('Apex', cost: 145, provider: 'Blue Water')],
        },
        options: options,
      ),
      options: options,
    );

    expect(out, contains('Blue Water'));
    expect(out, isNot(contains('145')));
    expect(out, isNot(contains('Cost')));
  });

  test('history off prints no history', () async {
    const options = ServiceReportOptions(includeHistory: false);
    final out = await text(
      _report(
        [_item('Apex')],
        records: {
          'Apex': [_record('Apex', provider: 'Blue Water')],
        },
        options: options,
      ),
      options: options,
    );

    expect(out, isNot(contains('Blue Water')));
    expect(out, isNot(contains('No service recorded')));
  });

  test('no records at all prints No service recorded', () async {
    final out = await text(_report([_item('Apex')]));
    expect(out, contains('No service recorded'));
  });

  test('100 items of history flow onto several pages', () async {
    final gear = [for (var i = 0; i < 100; i++) _item('Item $i')];
    final out = await text(
      _report(
        gear,
        records: {
          for (final item in gear)
            item.id: [
              for (var year = 2010; year < 2026; year++)
                _record(item.id, year: year, provider: 'Shop ${item.id}'),
            ],
        },
      ),
    );

    expect(out, contains('Shop Item 99'));
    expect('Work'.allMatches(out).length, greaterThan(50));
  });

  test('an Arabic localization still builds', () async {
    final bytes = await service.generateBytes(
      _report([_item('Apex')]),
      options: const ServiceReportOptions(),
      settings: ReportPrintSettings(
        diverName: null,
        units: units,
        printedAt: _now,
        localization: PdfLocalization.forLanguageCode('ar'),
      ),
    );
    expect(bytes, isNotEmpty);
  });
}
