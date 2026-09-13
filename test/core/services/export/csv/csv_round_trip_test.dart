import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_component_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/import_wizard/data/adapters/universal_adapter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/parser_registry.dart';
import 'package:submersion/features/universal_import/data/services/format_detector.dart';

import '../../../../helpers/test_database.dart';
import '../uddf/uddf_raw_data_round_trip_test.dart'
    show buildRepositories, createTestDiver;
import 'csv_dives_writer_test.dart' show imperial;
import 'csv_test_fixtures.dart';

const _metricDiver = AppSettings(
  dateFormat: DateFormatPreference.ddmmyyyy,
  timeFormat: TimeFormat.twentyFourHour,
);

/// Issue #1813 acceptance: a CSV exported in either mode, by an imperial or
/// a metric diver, re-imports with the same stored values, within the
/// precision the file wrote.
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() async => tearDownTestDatabase());

  final cases = <String, CsvExportUnits>{
    'Metric mode': CsvExportUnits.metric,
    'My units, imperial diver': CsvExportUnits.fromSettings(imperial),
    'My units, metric diver': CsvExportUnits.fromSettings(_metricDiver),
  };

  Future<String> importCsv(String csv, ImportFormat expected) async {
    final bytes = Uint8List.fromList(utf8.encode(csv));
    expect(const FormatDetector().detect(bytes).format, expected);
    final payload = await parserForFormat(expected).parse(bytes);
    expect(payload.warnings, isEmpty);
    final data = UniversalAdapter.payloadToUddfResult(payload);
    final diverId = await createTestDiver();
    await UddfEntityImporter().import(
      data: data,
      selections: UddfImportSelections.selectAll(data),
      repositories: buildRepositories(),
      diverId: diverId,
      retainSourceDiveNumbers: true,
    );
    return diverId;
  }

  void near(double? got, double? want, double tolerance, String what) {
    if (want == null) {
      expect(got, isNull, reason: what);
      return;
    }
    expect(got, isNotNull, reason: what);
    expect(got!, closeTo(want, tolerance), reason: what);
  }

  for (final MapEntry(key: label, value: units) in cases.entries) {
    group(label, () {
      test('sites come back', () async {
        final diverId = await importCsv(
          CsvSitesWriter(units).write(goldenSites()),
          ImportFormat.submersionSitesCsv,
        );
        final sites = await SiteRepository().getAllSites(diverId: diverId);
        final blue = sites.firstWhere((s) => s.name == 'Blue Hole');
        expect(blue.country, goldenSite.country);
        expect(blue.region, goldenSite.region);
        expect(blue.location!.latitude, goldenSite.location!.latitude);
        expect(blue.location!.longitude, goldenSite.location!.longitude);
        near(blue.maxDepth, goldenSite.maxDepth, 0.06, 'maxDepth');
        expect(blue.waterType, goldenSite.waterType);
        expect(blue.entryMethod, goldenSite.entryMethod);
        expect(blue.rating, goldenSite.rating);
        expect(blue.description, goldenSite.description);
        expect(blue.notes, goldenSite.notes.replaceAll('\n', ' '));
        expect(sites.map((s) => s.name), contains('House Reef'));
      });

      test('equipment comes back', () async {
        final diverId = await importCsv(
          CsvEquipmentWriter(
            units,
          ).write(roundTripEquipment(), componentNames: goldenComponentNames()),
          ImportFormat.submersionEquipmentCsv,
        );
        final stored = {
          for (final e in await EquipmentRepository().getAllEquipment(
            diverId: diverId,
          ))
            e.name: e,
        };
        for (final original in roundTripEquipment()) {
          final back = stored[original.name]!;
          final what = original.name;
          expect(back.type, original.type, reason: what);
          expect(back.brand, original.brand, reason: what);
          expect(back.model, original.model, reason: what);
          expect(back.serialNumber, original.serialNumber, reason: what);
          expect(back.isActive, original.isActive, reason: what);
          expect(back.purchaseDate, original.purchaseDate, reason: what);
          expect(back.lastServiceDate, original.lastServiceDate, reason: what);
          expect(
            back.serviceIntervalDays,
            original.serviceIntervalDays,
            reason: what,
          );
          expect(back.notes, original.notes.replaceAll('\n', ' '));
          for (final attr in original.attributes) {
            final match = back.attributes
                .where((a) => a.key == attr.key && a.isCustom == attr.isCustom)
                .single;
            final attrWhat = '$what ${attr.key}';
            expect(match.valueText, attr.valueText, reason: attrWhat);
            near(
              match.valueNum,
              attr.valueNum,
              (attr.valueNum ?? 0).abs() * 0.01,
              attrWhat,
            );
          }
        }
        final parts = await EquipmentComponentRepository().getComponents(
          stored['Primary reg']!.id,
        );
        expect(parts.map((p) => p.componentEquipmentId), [
          stored['Mk25']!.id,
          stored['Long hose']!.id,
        ]);
      });

      test('dives come back', () async {
        await importCsv(
          CsvDivesWriter(units).write(goldenDives()),
          ImportFormat.submersionDivesCsv,
        );
        final repo = DiveRepository();
        final all = await repo.getAllDives();
        expect(all, hasLength(2));
        for (final original in goldenDives()) {
          final summary = all.firstWhere(
            (d) => d.diveNumber == original.diveNumber,
          );
          final back = (await repo.getDiveById(summary.id))!;
          expect(back.dateTime, original.dateTime);
          expect(back.name, original.name);
          expect(back.bottomTime, original.bottomTime);
          expect(back.runtime, original.runtime ?? original.bottomTime);
          expect(back.diveTypeIds.toSet(), original.diveTypeIds.toSet());
          expect(back.buddy, original.buddy);
          expect(back.diveMaster, original.diveMaster);
          expect(back.rating, original.rating);
          expect(back.notes, original.notes.replaceAll('\n', ' '));
          expect(back.visibility, original.visibility);
          expect(back.diveComputerModel, original.diveComputerModel);
          expect(back.diveComputerSerial, original.diveComputerSerial);
          expect(back.diveComputerFirmware, original.diveComputerFirmware);
          expect(back.windDirection, original.windDirection);
          expect(back.cloudCover, original.cloudCover);
          expect(back.precipitation, original.precipitation);
          expect(back.humidity, original.humidity);
          expect(back.weatherDescription, original.weatherDescription);
          expect(
            {for (final f in back.customFields) f.key: f.value},
            {for (final f in original.customFields) f.key: f.value},
          );
          near(back.maxDepth, original.maxDepth, 0.06, 'maxDepth');
          near(back.avgDepth, original.avgDepth, 0.06, 'avgDepth');
          near(back.waterTemp, original.waterTemp, 0.6, 'waterTemp');
          near(back.airTemp, original.airTemp, 0.6, 'airTemp');
          near(back.visibilityMeters, original.visibilityMeters, 0.06, 'vis');
          near(back.windSpeed, original.windSpeed, 0.06, 'windSpeed');
          if (original.tanks.isNotEmpty) {
            final want = original.tanks.first;
            final got = back.tanks.first;
            near(got.volume, want.volume, units.isMetric ? 0.5 : 0.06, 'vol');
            near(got.startPressure, want.startPressure, 0.06, 'start');
            near(got.endPressure, want.endPressure, 0.06, 'end');
            expect(got.gasMix.o2, want.gasMix.o2);
            // Metric mode never wrote a working pressure.
            if (!units.isMetric) {
              near(got.workingPressure, want.workingPressure, 0.06, 'wp');
            }
          }
          if (original.site != null) {
            expect(back.site?.name, original.site!.name);
            expect(back.site?.region, original.site!.region);
            expect(back.site?.country, original.site!.country);
          }
        }
      });
    });
  }

  test('text that looks like a formula survives the round trip', () async {
    // The export neutralises = + - @ with a leading quote (CSV injection);
    // the importer must hand the diver back exactly what they typed.
    final site = goldenSite.copyWith(name: '=Reef', notes: '-deep wall');
    var diverId = await importCsv(
      CsvSitesWriter(CsvExportUnits.metric).write([site]),
      ImportFormat.submersionSitesCsv,
    );
    final storedSite = (await SiteRepository().getAllSites(
      diverId: diverId,
    )).single;
    expect(storedSite.name, '=Reef');
    expect(storedSite.notes, '-deep wall');

    await tearDownTestDatabase();
    await setUpTestDatabase();
    final item = goldenEquipment()[1].copyWith(
      name: '@Suit',
      serialNumber: '+42',
    );
    diverId = await importCsv(
      CsvEquipmentWriter(CsvExportUnits.metric).write([item]),
      ImportFormat.submersionEquipmentCsv,
    );
    final storedItem = (await EquipmentRepository().getAllEquipment(
      diverId: diverId,
    )).single;
    expect(storedItem.name, '@Suit');
    expect(storedItem.serialNumber, '+42');

    await tearDownTestDatabase();
    await setUpTestDatabase();
    final dive = goldenDives().first.copyWith(
      name: '=HYPERLINK("x")',
      buddy: '-Ana',
    );
    await importCsv(
      CsvDivesWriter(CsvExportUnits.metric).write([dive]),
      ImportFormat.submersionDivesCsv,
    );
    final stored = (await DiveRepository().getAllDives()).single;
    expect(stored.name, '=HYPERLINK("x")');
    expect(stored.buddy, '-Ana');
  });

  test('ambiguous list text and custom keys survive the round trip', () async {
    // Copilot review on #1847: a "; " inside a value or a part name, and a
    // custom attribute sharing a curated key, used to break on re-import.
    const part = EquipmentItem(
      id: 'p',
      name: 'Hose; long',
      type: EquipmentType.hose,
    );
    final suit = goldenEquipment()[1].copyWith(
      attributes: [
        ...goldenEquipment()[1].attributes,
        EquipmentAttribute.curated(
          equipmentId: 'e-suit',
          key: 'retailer',
          valueText: 'Shop; Two',
        ),
        const EquipmentAttribute(
          id: 'custom-size',
          equipmentId: 'e-suit',
          key: 'size',
          isCustom: true,
          valueText: 'XL',
        ),
      ],
    );
    const reg = EquipmentItem(
      id: 'r',
      name: 'Reg',
      type: EquipmentType.regulator,
    );
    final diverId = await importCsv(
      CsvEquipmentWriter(CsvExportUnits.metric).write(
        [part, suit, reg],
        componentNames: {
          'r': ['Hose; long'],
        },
      ),
      ImportFormat.submersionEquipmentCsv,
    );
    final stored = {
      for (final e in await EquipmentRepository().getAllEquipment(
        diverId: diverId,
      ))
        e.name: e,
    };
    expect(stored.keys, containsAll(['Hose; long', 'Suit', 'Reg']));
    final storedSuit = stored['Suit']!;
    expect(storedSuit.attrText('retailer'), 'Shop; Two');
    expect(storedSuit.size, 'L');
    expect(
      storedSuit.attributes
          .where((a) => a.isCustom && a.key == 'size')
          .single
          .valueText,
      'XL',
    );
    final parts = await EquipmentComponentRepository().getComponents(
      stored['Reg']!.id,
    );
    expect(parts.single.componentEquipmentId, stored['Hose; long']!.id);
  });
}
