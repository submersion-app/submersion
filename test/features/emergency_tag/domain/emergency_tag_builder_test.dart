import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/domain/services/emergency_tag_builder.dart';

void main() {
  final written = DateTime(2026, 11, 27);
  final diver = Diver(
    id: 'd1',
    name: ' Sam Diver ',
    birthYear: 1984,
    allergies: 'Penicillin',
    medications: '  ',
    bloodType: 'O+',
    medicalNotes: 'Asthma as a child',
    emergencyContact: const EmergencyContact(
      name: 'Alex Diver',
      relation: 'Partner',
      phone: '+1 (555) 123-4567',
    ),
    emergencyContact2: const EmergencyContact(name: 'Kim'),
    insurance: const DiverInsurance(
      provider: 'DAN',
      policyNumber: '1234567',
      emergencyPhone: '+1 919 684 9111',
    ),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  group('availableFields', () {
    test('lists only fields with something recorded', () {
      expect(EmergencyTagBuilder.availableFields(diver), {
        EmergencyTagField.birthYear,
        EmergencyTagField.allergies,
        EmergencyTagField.bloodType,
        EmergencyTagField.medicalNotes,
        EmergencyTagField.contact1,
        EmergencyTagField.contact2,
        EmergencyTagField.insurance,
      });
    });
  });

  group('build', () {
    test('includes chosen fields that have values, trimmed', () {
      final info = EmergencyTagBuilder.build(
        diver,
        EmergencyTagChoices.defaults,
        written: written,
      );
      expect(info.name, 'Sam Diver');
      expect(info.birthYear, isNull);
      expect(info.allergies, 'Penicillin');
      expect(info.medications, isNull);
      expect(info.bloodType, 'O+');
      expect(info.medicalNotes, isNull);
      expect(info.contact1?.name, 'Alex Diver');
      expect(info.contact1?.phone, '+1 (555) 123-4567');
      expect(info.contact2?.name, 'Kim');
      expect(info.contact2?.phone, isNull);
      expect(info.insurer, 'DAN');
      expect(info.policy, '1234567');
      expect(info.assistanceLine, '+1 919 684 9111');
      expect(info.written, written);
      expect(info.trimmed, isFalse);
    });

    test('leaves out fields switched off', () {
      final info = EmergencyTagBuilder.build(
        diver,
        const EmergencyTagChoices(
          primary: EmergencyTagPrimary.link,
          callTarget: EmergencyCallTarget.contact1,
          fields: {EmergencyTagField.birthYear},
        ),
        written: written,
      );
      expect(info.birthYear, 1984);
      expect(info.allergies, isNull);
      expect(info.contact1, isNull);
      expect(info.insurer, isNull);
    });
  });

  group('call numbers', () {
    test('lists the targets that have a number', () {
      expect(EmergencyTagBuilder.callTargets(diver), [
        EmergencyCallTarget.contact1,
        EmergencyCallTarget.insurer,
      ]);
    });

    test('dials the chosen number, digits and a leading plus only', () {
      expect(
        EmergencyTagBuilder.callUri(diver, EmergencyCallTarget.contact1),
        'tel:+15551234567',
      );
      expect(
        EmergencyTagBuilder.callUri(diver, EmergencyCallTarget.insurer),
        'tel:+19196849111',
      );
      expect(
        EmergencyTagBuilder.callUri(diver, EmergencyCallTarget.contact2),
        isNull,
      );
    });
  });
}
