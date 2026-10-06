import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/certification_agencies/data/repositories/custom_certification_repository.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

import '../../../../helpers/test_database.dart';
import 'wizard_import_harness.dart';

const _diverId = 'diver-1';
final _now = DateTime(2026);

Diver _diver() =>
    Diver(id: _diverId, name: 'Test Diver', createdAt: _now, updatedAt: _now);

/// Issue #690: a certification under a custom agency survives a UDDF export
/// and re-import through the wizard. The export writes the agency's name;
/// the import must find (or create once) the custom agency by that name,
/// never fall back to PADI.
void main() {
  Future<ImportPayload> parse(String xml) =>
      UddfImportParser().parse(Uint8List.fromList(utf8.encode(xml)));

  /// Creates a custom agency, a custom level under it and a certification
  /// using both, and exports them the way the export providers do.
  Future<String> exportCustomCard() async {
    await DiverRepository().createDiver(_diver());
    final custom = CustomCertificationRepository();
    final agency = await custom.createAgency(
      diverId: _diverId,
      name: 'Lakeshore Dive Club',
      isShared: false,
    );
    final level = await custom.createLevel(
      diverId: _diverId,
      agencyId: agency.id,
      name: 'Club Diver',
      isProgression: true,
      isShared: false,
    );
    final cert = await CertificationRepository().createCertification(
      Certification(
        id: '',
        diverId: _diverId,
        name: 'Club card',
        agency: agency.id,
        level: level.id,
        createdAt: _now,
        updatedAt: _now,
      ),
    );
    return UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      certifications: [cert],
      certificationCatalog: CertificationCatalog(
        agencies: await custom.getAllAgencies(),
        levels: await custom.getAllLevels(),
      ),
    );
  }

  Future<List<Certification>> certs() =>
      CertificationRepository().getAllCertifications(diverId: _diverId);

  testWidgets('re-importing onto the same database resolves the existing '
      'agency and level', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final xml = (await tester.runAsync(exportCustomCard))!;
    expect(xml, contains('Lakeshore Dive Club'));

    final payload = (await tester.runAsync(() => parse(xml)))!;
    final result = await importThroughWizard(
      tester,
      payload: payload,
      diver: _diver(),
    );
    expect(result.errorMessage, isNull);

    final (agencies, levels, all) = (await tester.runAsync(() async {
      final custom = CustomCertificationRepository();
      return (
        await custom.getAllAgencies(),
        await custom.getAllLevels(),
        await certs(),
      );
    }))!;
    expect(agencies, hasLength(1), reason: 'no duplicate agency');
    expect(all, hasLength(2));
    for (final c in all) {
      expect(c.agency, agencies.single.id, reason: 'never PADI');
      expect(c.level, levels.single.id);
    }
  });

  testWidgets('a fresh database recreates the agency once across two imports', (
    tester,
  ) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final xml = (await tester.runAsync(exportCustomCard))!;

    await tester.runAsync(() async {
      await tearDownTestDatabase();
      await setUpTestDatabase();
      await DiverRepository().createDiver(_diver());
    });
    final payload = (await tester.runAsync(() => parse(xml)))!;
    for (var i = 0; i < 2; i++) {
      final result = await importThroughWizard(
        tester,
        payload: payload,
        diver: _diver(),
      );
      expect(result.errorMessage, isNull);
    }

    final (agencies, all) = (await tester.runAsync(() async {
      return (
        await CustomCertificationRepository().getAllAgencies(),
        await certs(),
      );
    }))!;
    expect(agencies.single.name, 'Lakeshore Dive Club');
    expect(all, isNotEmpty);
    for (final c in all) {
      expect(c.agency, agencies.single.id, reason: 'never PADI');
    }
  });
}
