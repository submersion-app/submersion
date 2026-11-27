import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';

void main() {
  group('EmergencyTagChoices', () {
    test(
      'defaults: a link, contact 1, every field but notes and birth year',
      () {
        const d = EmergencyTagChoices.defaults;
        expect(d.primary, EmergencyTagPrimary.link);
        expect(d.callTarget, EmergencyCallTarget.contact1);
        expect(d.includeText, isTrue);
        expect(d.fields, {
          EmergencyTagField.allergies,
          EmergencyTagField.medications,
          EmergencyTagField.bloodType,
          EmergencyTagField.contact1,
          EmergencyTagField.contact2,
          EmergencyTagField.insurance,
        });
      },
    );

    test('null or unreadable JSON reads as the defaults', () {
      expect(EmergencyTagChoices.fromJson(null), EmergencyTagChoices.defaults);
      expect(EmergencyTagChoices.fromJson('{'), EmergencyTagChoices.defaults);
      expect(EmergencyTagChoices.fromJson('[]'), EmergencyTagChoices.defaults);
    });

    test('round trips through JSON', () {
      const choices = EmergencyTagChoices(
        primary: EmergencyTagPrimary.call,
        callTarget: EmergencyCallTarget.insurer,
        fields: {EmergencyTagField.medicalNotes, EmergencyTagField.birthYear},
        includeText: false,
      );
      expect(EmergencyTagChoices.fromJson(choices.toJson()), choices);
    });

    test('a bad value falls back to its default, key by key', () {
      final read = EmergencyTagChoices.fromJson(
        '{"primary":"fax","callTarget":"contact2",'
        '"fields":{"allergies":false,"medicalNotes":"yes"},"text":"no"}',
      );
      expect(read.includeText, isTrue);
      expect(read.primary, EmergencyTagPrimary.link);
      expect(read.callTarget, EmergencyCallTarget.contact2);
      expect(read.fields.contains(EmergencyTagField.allergies), isFalse);
      expect(read.fields.contains(EmergencyTagField.medicalNotes), isFalse);
      expect(read.fields.contains(EmergencyTagField.bloodType), isTrue);
    });

    test('withField switches one field', () {
      final on = EmergencyTagChoices.defaults.withField(
        EmergencyTagField.medicalNotes,
        true,
      );
      expect(on.fields.contains(EmergencyTagField.medicalNotes), isTrue);
      final off = on.withField(EmergencyTagField.allergies, false);
      expect(off.fields.contains(EmergencyTagField.allergies), isFalse);
      expect(
        EmergencyTagChoices.defaults.fields.contains(
          EmergencyTagField.allergies,
        ),
        isTrue,
      );
    });
  });
}
