import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/currency_backup_data.dart';
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_currency_repository.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/domain/entities/currency_pref.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_import/data/services/uddf_entity_importer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/tank_pressure_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_set_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/test_database.dart';

/// Restoring certification currency from a UDDF full backup (issue #2267).
/// Custom rules restore with no selection step, as custom dive roles do;
/// prefs and events ride along with the certifications the import creates,
/// as service records ride along with equipment.
const _diverId = 'restorer';
final _then = DateTime(2026, 9, 22);

ImportRepositories _repositories({bool withCurrency = true}) =>
    ImportRepositories(
      tripRepository: TripRepository(),
      equipmentRepository: EquipmentRepository(),
      equipmentSetRepository: EquipmentSetRepository(),
      buddyRepository: BuddyRepository(),
      diveCenterRepository: DiveCenterRepository(),
      certificationRepository: CertificationRepository(),
      tagRepository: TagRepository(),
      diveTypeRepository: DiveTypeRepository(),
      siteRepository: SiteRepository(),
      diveRepository: DiveRepository(),
      tankPressureRepository: TankPressureRepository(),
      courseRepository: CourseRepository(),
      certificationCurrencyRepository: withCurrency
          ? CertificationCurrencyRepository()
          : null,
    );

final _sourceCert = Certification(
  id: 'src-cert',
  name: 'Full Cave',
  agency: CertificationAgency.tdi.name,
  level: CertificationLevel.cave.name,
  createdAt: _then,
  updatedAt: _then,
);

final _customRule = CurrencyRule(
  id: 'custom-1',
  diverId: 'someone-else',
  name: 'Club cave check-out',
  clockKind: CurrencyClockKind.activity,
  levels: const [CertificationLevel.cave],
  lapseDays: 180,
  leadDays: 30,
  countedDiveTypeIds: const ['cave'],
  supersedesRuleId: 'cave_currency',
  createdAt: _then,
  updatedAt: _then,
);

final _pref = CurrencyPref(
  id: 'src-pref',
  certificationId: 'src-cert',
  ruleId: 'custom-1',
  lapseDaysOverride: 240,
  muted: true,
  createdAt: _then,
  updatedAt: _then,
);

final _event = CurrencyEvent(
  id: 'src-event',
  certificationId: 'src-cert',
  ruleId: 'custom-1',
  eventType: CurrencyEventType.revalidation,
  eventDate: DateTime(2026, 5, 1),
  provider: 'Cenote school',
  createdAt: _then,
  updatedAt: _then,
);

Future<dynamic> _parse({List<CurrencyRule>? rules}) {
  final builder = XmlBuilder();
  builder.element(
    'uddf',
    attributes: {'version': '3.2.1'},
    nest: () {
      UddfExportBuilders.buildApplicationData(
        builder,
        certifications: [_sourceCert],
        currency: CurrencyBackupData(
          rules: rules ?? [_customRule],
          prefs: [_pref],
          events: [_event],
        ),
      );
    },
  );
  return UddfFullImportService().importAllDataFromUddf(
    builder.buildDocument().toXmlString(),
  );
}

void main() {
  late CertificationCurrencyRepository currency;

  setUp(() async {
    await setUpTestDatabase();
    currency = CertificationCurrencyRepository();
    await DiverRepository().createDiver(
      Diver(
        id: _diverId,
        name: 'Restorer',
        isDefault: true,
        createdAt: _then,
        updatedAt: _then,
      ),
    );
  });

  tearDown(tearDownTestDatabase);

  Future<Certification> restoredCert() async =>
      (await CertificationRepository().getAllCertifications(
        diverId: _diverId,
      )).single;

  test('a selected certification brings its prefs and events', () async {
    final data = await _parse();
    await UddfEntityImporter().import(
      data: data,
      selections: const UddfImportSelections(certifications: {0}),
      repositories: _repositories(),
      diverId: _diverId,
    );

    final cert = await restoredCert();
    final pref = (await currency.getPrefs(cert.id)).single;
    expect(pref.ruleId, 'custom-1');
    expect(pref.lapseDaysOverride, 240);
    expect(pref.muted, isTrue);
    expect(pref.countedDiveTypeIds, isNull, reason: 'inherit survives');
    final event = (await currency.getEvents(cert.id)).single;
    expect(event.eventType, CurrencyEventType.revalidation);
    expect(event.eventDate, DateTime(2026, 5, 1));
    expect(event.provider, 'Cenote school');
  });

  test(
    'a custom rule restores as the importing diver\'s, keeping its id',
    () async {
      final data = await _parse();
      await UddfEntityImporter().import(
        data: data,
        selections: const UddfImportSelections(certifications: {0}),
        repositories: _repositories(),
        diverId: _diverId,
      );

      final rule = (await currency.getRules()).singleWhere(
        (r) => r.id == 'custom-1',
      );
      expect(rule.isBuiltIn, isFalse);
      expect(rule.diverId, _diverId);
      expect(rule.name, 'Club cave check-out');
      expect(rule.countedDiveTypeIds, ['cave']);
      expect(rule.supersedesRuleId, 'cave_currency');
    },
  );

  test('a rule already here is reused, not duplicated', () async {
    await currency.createRule(_customRule.copyWith(diverId: _diverId));
    final data = await _parse();
    await UddfEntityImporter().import(
      data: data,
      selections: const UddfImportSelections(certifications: {0}),
      repositories: _repositories(),
      diverId: _diverId,
    );

    expect((await currency.getRules()).where((r) => !r.isBuiltIn).length, 1);
    final cert = await restoredCert();
    expect((await currency.getPrefs(cert.id)).single.ruleId, 'custom-1');
  });

  test('another diver\'s rule under the same id is not taken over', () async {
    await DiverRepository().createDiver(
      Diver(id: 'other', name: 'Other', createdAt: _then, updatedAt: _then),
    );
    await currency.createRule(_customRule.copyWith(diverId: 'other'));
    final data = await _parse();
    await UddfEntityImporter().import(
      data: data,
      selections: const UddfImportSelections(certifications: {0}),
      repositories: _repositories(),
      diverId: _diverId,
    );

    final custom = (await currency.getRules()).where((r) => !r.isBuiltIn);
    expect(custom.length, 2);
    final mine = custom.singleWhere((r) => r.diverId == _diverId);
    expect(mine.id, isNot('custom-1'));
    final cert = await restoredCert();
    expect(
      (await currency.getPrefs(cert.id)).single.ruleId,
      mine.id,
      reason: 'the pref follows its rule to the copy',
    );
  });

  test(
    'a custom rule colliding with a built-in id lands under a new id',
    () async {
      // A file's rules are always custom; a colliding id must not silently
      // become the seeded rule and lose the file's own definition.
      final data = await _parse(
        rules: [_customRule.copyWith(id: 'cave_currency')],
      );
      final colliding = {
        ...(data.currencyPrefs as List<Map<String, dynamic>>).single,
        'ruleId': 'cave_currency',
      };
      final restored = UddfFullImportServiceShim.withPrefs(data, [colliding]);
      await UddfEntityImporter().import(
        data: restored,
        selections: const UddfImportSelections(certifications: {0}),
        repositories: _repositories(),
        diverId: _diverId,
      );

      final custom = (await currency.getRules()).where((r) => !r.isBuiltIn);
      final copy = custom.single;
      expect(copy.id, isNot('cave_currency'));
      expect(copy.name, 'Club cave check-out');
      expect(copy.lapseDays, 180);
      final builtIn = (await currency.getRules()).singleWhere(
        (r) => r.id == 'cave_currency',
      );
      expect(builtIn.lapseDays, 365, reason: 'the seeded rule is untouched');
      final cert = await restoredCert();
      expect(
        (await currency.getPrefs(cert.id)).single.ruleId,
        copy.id,
        reason: 'the pref follows the file rule, not the built-in',
      );
    },
  );

  test('an unselected certification brings nothing', () async {
    final data = await _parse();
    await UddfEntityImporter().import(
      data: data,
      selections: const UddfImportSelections(),
      repositories: _repositories(),
      diverId: _diverId,
    );
    expect(await currency.getAllPrefs(), isEmpty);
    expect(await currency.getAllEvents(), isEmpty);
  });

  test('without the repository the import still succeeds', () async {
    final data = await _parse();
    await UddfEntityImporter().import(
      data: data,
      selections: const UddfImportSelections(certifications: {0}),
      repositories: _repositories(withCurrency: false),
      diverId: _diverId,
    );
    expect(
      (await CertificationRepository().getAllCertifications(
        diverId: _diverId,
      )).length,
      1,
    );
    expect(await currency.getAllPrefs(), isEmpty);
  });
}

/// Swaps the parsed prefs of a full-backup result, keeping everything else.
abstract final class UddfFullImportServiceShim {
  static UddfImportResult withPrefs(
    UddfImportResult data,
    List<Map<String, dynamic>> prefs,
  ) => UddfImportResult(
    certifications: data.certifications,
    currencyRules: data.currencyRules,
    currencyPrefs: prefs,
    currencyEvents: data.currencyEvents,
  );
}
