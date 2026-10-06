import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_participant_writers.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_agency.dart';
import 'package:submersion/features/certification_agencies/domain/entities/custom_certification_level.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';

/// Issue #690: UDDF carries a custom agency or level by its name, since its
/// id means nothing to another app. Built-ins keep their enum names.
void main() {
  final t = DateTime(2026);
  final catalog = CertificationCatalog(
    agencies: [
      CustomCertificationAgency(
        id: 'club-x-id',
        diverId: 'a',
        name: 'Club X',
        colorArgb: 0xFF3B82F6,
        createdAt: t,
        updatedAt: t,
      ),
    ],
    levels: [
      CustomCertificationLevel(
        id: 'club-diver-id',
        diverId: 'a',
        agencyId: 'club-x-id',
        name: 'Club Diver',
        isProgression: true,
        createdAt: t,
        updatedAt: t,
      ),
    ],
  );

  XmlDocument write(void Function(XmlBuilder b) body) {
    final builder = XmlBuilder();
    builder.element('root', nest: () => body(builder));
    return builder.buildDocument();
  }

  Certification cert(String id, String agency, String? level) => Certification(
    id: id,
    name: 'Card $id',
    agency: agency,
    level: level,
    createdAt: t,
    updatedAt: t,
  );

  test('certifications export custom names and built-in ids', () {
    final doc = write(
      (b) => UddfExportBuilders.buildApplicationData(
        b,
        certifications: [
          cert('c1', 'club-x-id', 'club-diver-id'),
          cert('c2', 'padi', 'openWater'),
          cert('c3', 'unsyncedAgency', null),
        ],
        certificationCatalog: catalog,
      ),
    );
    final agencies = doc
        .findAllElements('agency')
        .map((e) => e.innerText)
        .toList();
    final levels = doc
        .findAllElements('level')
        .map((e) => e.innerText)
        .toList();
    expect(agencies, ['Club X', 'padi', 'unsyncedAgency']);
    expect(levels, ['Club Diver', 'openWater']);
  });

  test('a buddy exports its custom agency and level by name', () {
    final buddy = Buddy(
      id: 'b1',
      name: 'Ana Reyes',
      certificationAgency: 'club-x-id',
      certificationLevel: 'club-diver-id',
      createdAt: t,
      updatedAt: t,
    );
    final doc = write(
      (b) => UddfParticipantWriters.writeBuddyDeclarations(b, [
        buddy,
      ], certificationCatalog: catalog),
    );
    expect(doc.findAllElements('agency').single.innerText, 'Club X');
    expect(doc.findAllElements('level').single.innerText, 'Club Diver');
  });
}
