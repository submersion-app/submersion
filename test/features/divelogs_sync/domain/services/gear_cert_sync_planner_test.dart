import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/divelogs/divelogs_models.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/divelogs_sync/domain/services/gear_cert_sync_planner.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  const planner = GearCertSyncPlanner();
  final now = DateTime.utc(2024);

  EquipmentItem gear(
    String id,
    String name, {
    EquipmentStatus status = EquipmentStatus.active,
    bool isActive = true,
  }) => EquipmentItem(
    id: id,
    name: name,
    type: EquipmentType.regulator,
    status: status,
    isActive: isActive,
  );

  Certification cert(String id, String name, {DateTime? issueDate}) =>
      Certification(
        id: id,
        name: name,
        agency: CertificationAgency.padi,
        issueDate: issueDate,
        createdAt: now,
        updatedAt: now,
      );

  GearCertSyncPlan plan({
    List<DivelogsGearItem> remoteGear = const [],
    List<DivelogsCertification> remoteCerts = const [],
    List<EquipmentItem> localGear = const [],
    List<Certification> localCerts = const [],
  }) => planner.plan(
    remoteGear: remoteGear,
    remoteCerts: remoteCerts,
    localGear: localGear,
    localCerts: localCerts,
  );

  test('gear matches by case-insensitive name', () {
    final result = plan(
      remoteGear: const [DivelogsGearItem(id: '1', name: 'apex xtx50')],
      localGear: [gear('l1', 'Apex XTX50')],
    );
    expect(result.matchedGear, 1);
    expect(result.pushGear, isEmpty);
    expect(result.pullGear, 0);
  });

  test('local-only active gear is pushed, remote-only counted as pull', () {
    final result = plan(
      remoteGear: const [DivelogsGearItem(id: '1', name: 'Remote Only')],
      localGear: [gear('l1', 'Local Only')],
    );
    expect(result.pushGear.map((g) => g.id), ['l1']);
    expect(result.pullGear, 1);
  });

  test('retired local gear matches but is never pushed', () {
    final result = plan(
      localGear: [
        gear('l1', 'Old Reg', status: EquipmentStatus.retired, isActive: false),
      ],
    );
    expect(result.pushGear, isEmpty);
  });

  test('certs match by name plus calendar date when both present', () {
    final result = plan(
      remoteCerts: [
        DivelogsCertification(
          name: 'Open Water',
          date: DateTime.utc(2022, 6, 15),
        ),
      ],
      localCerts: [
        cert('c1', 'open water', issueDate: DateTime.utc(2022, 6, 15)),
      ],
    );
    expect(result.matchedCerts, 1);
    expect(result.pushCerts, isEmpty);
    expect(result.pullCerts, 0);
  });

  test('same cert name with different dates is both push and pull', () {
    final result = plan(
      remoteCerts: [
        DivelogsCertification(
          name: 'Open Water',
          date: DateTime.utc(2020, 1, 1),
        ),
      ],
      localCerts: [
        cert('c1', 'Open Water', issueDate: DateTime.utc(2022, 6, 15)),
      ],
    );
    expect(result.pushCerts, hasLength(1));
    expect(result.pullCerts, 1);
  });

  test('cert without a date on one side matches by name alone', () {
    final result = plan(
      remoteCerts: const [DivelogsCertification(name: 'Open Water')],
      localCerts: [cert('c1', 'Open Water', issueDate: DateTime.utc(2022))],
    );
    expect(result.matchedCerts, 1);
  });

  test('local certs without issueDate are excluded from push and counted', () {
    final result = plan(localCerts: [cert('c1', 'Nitrox')]);
    expect(result.pushCerts, isEmpty);
    expect(result.certsMissingDate, 1);
  });
}
