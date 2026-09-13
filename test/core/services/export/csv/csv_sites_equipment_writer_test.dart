import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';

import 'csv_dives_writer_test.dart' show imperial, rowOf;
import 'csv_test_fixtures.dart';

void main() {
  final units = CsvExportUnits.fromSettings(imperial);

  test('sites: max depth follows the diver', () {
    final r = rowOf(CsvSitesWriter(units).write(goldenSites()), 1);
    expect(r['Max Depth (ft)'], '132.9');
    expect(r['Latitude'], '17.316000');
  });

  test('equipment: dates, weights and attributes follow the diver', () {
    final csv = CsvEquipmentWriter(
      units,
    ).write(goldenEquipment(), componentNames: goldenComponentNames());
    final suit = rowOf(csv, 2);
    expect(suit['Buoyancy (lbs)'], '5.51');
    expect(suit['Dry Weight (lbs)'], '7.17');
    expect(suit['Attributes'], 'suit_style=full');
    expect(rowOf(csv, 1)['Attributes'], 'hose_length=22 in');
    expect(rowOf(csv, 4)['Attributes'], 'speed=98.4 ft/min; burn_time=90 min');
    final first = rowOf(csv, 6);
    expect(first['Purchase Date (MM/DD/YYYY)'], '06/01/2023');
    expect(first['Next Service Due (MM/DD/YYYY)'], '01/10/2026');
    expect(first['Active'], 'No');
    expect(rowOf(csv, 7)['Components'], 'Mk25; Long hose');
  });

  test('no attribute pair puts a converted value under a metric key', () {
    final csv = CsvEquipmentWriter(units).write(goldenEquipment());
    expect(csv, isNot(contains('hose_length_m=')));
    expect(csv, isNot(contains('volume_l=')));
    expect(csv, isNot(contains('speed_mps=')));
  });

  test('site and equipment free text is neutralised against formulas', () {
    final site = goldenSite.copyWith(name: '=cmd', notes: '-deep');
    final siteRow = rowOf(CsvSitesWriter(units).write([site]), 1);
    expect(siteRow['Name'], "'=cmd");
    expect(siteRow['Notes'], "'-deep");

    final item = goldenEquipment()[1].copyWith(
      name: '@suit',
      serialNumber: '-42',
    );
    final itemRow = rowOf(CsvEquipmentWriter(units).write([item]), 1);
    expect(itemRow['Name'], "'@suit");
    expect(itemRow['Serial Number'], "'-42");
  });
}
