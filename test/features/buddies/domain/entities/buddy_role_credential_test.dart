import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy_role_credential.dart';

void main() {
  final created = DateTime(2024, 1, 1);
  final updated = DateTime(2024, 6, 1);

  BuddyRoleCredential make({
    String? credentialNumber,
    CertificationAgency? agency,
  }) {
    return BuddyRoleCredential(
      id: 'role-1',
      buddyId: 'buddy-1',
      role: BuddyRole.instructor,
      credentialNumber: credentialNumber,
      agency: agency,
      notes: 'note',
      createdAt: created,
      updatedAt: updated,
    );
  }

  group('displayLabel', () {
    test('agency and number', () {
      expect(
        make(
          credentialNumber: '12345',
          agency: CertificationAgency.padi,
        ).displayLabel,
        'Instructor - PADI #12345',
      );
    });

    test('agency only', () {
      expect(
        make(agency: CertificationAgency.ssi).displayLabel,
        'Instructor - SSI',
      );
    });

    test('number only', () {
      expect(make(credentialNumber: '9').displayLabel, 'Instructor - #9');
    });

    test('neither (and empty number counts as absent)', () {
      expect(make().displayLabel, 'Instructor');
      expect(make(credentialNumber: '').displayLabel, 'Instructor');
    });
  });

  group('copyWith', () {
    test('replaces every provided field', () {
      final other = make().copyWith(
        id: 'role-2',
        buddyId: 'buddy-2',
        role: BuddyRole.diveMaster,
        credentialNumber: '777',
        agency: CertificationAgency.tdi,
        notes: 'changed',
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2023, 2, 2),
      );
      expect(other.id, 'role-2');
      expect(other.buddyId, 'buddy-2');
      expect(other.role, BuddyRole.diveMaster);
      expect(other.credentialNumber, '777');
      expect(other.agency, CertificationAgency.tdi);
      expect(other.notes, 'changed');
      expect(other.createdAt, DateTime(2023, 1, 1));
      expect(other.updatedAt, DateTime(2023, 2, 2));
    });

    test('without arguments keeps every field (value equality)', () {
      final original = make(
        credentialNumber: '12345',
        agency: CertificationAgency.padi,
      );
      expect(original.copyWith(), original);
      expect(original.copyWith(notes: 'other'), isNot(original));
    });

    test('can clear nullable fields by passing null', () {
      final original = make(
        credentialNumber: '12345',
        agency: CertificationAgency.padi,
      );
      final cleared = original.copyWith(credentialNumber: null, agency: null);
      expect(cleared.credentialNumber, isNull);
      expect(cleared.agency, isNull);
      // Non-nullable fields are untouched.
      expect(cleared.role, original.role);
      expect(cleared.id, original.id);
    });

    test('omitting a nullable field keeps its current value', () {
      final original = make(credentialNumber: '12345');
      // Only agency omitted here; credentialNumber explicitly changed.
      final updated = original.copyWith(credentialNumber: '999');
      expect(updated.credentialNumber, '999');
    });
  });
}
