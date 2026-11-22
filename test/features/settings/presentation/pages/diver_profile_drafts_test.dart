import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_drafts.dart';

void main() {
  final then = DateTime.utc(2026, 1, 1);

  Diver stored({
    String name = 'Alice Alpha',
    String? email = 'alice@example.com',
    String? bloodType,
    String? allergies,
    EmergencyContact primary = const EmergencyContact(),
    EmergencyContact secondary = const EmergencyContact(),
    int? priorSeconds,
    DateTime? divingSince,
    String notes = '',
  }) => Diver(
    id: 'diver-1',
    name: name,
    email: email,
    bloodType: bloodType,
    allergies: allergies,
    emergencyContact: primary,
    emergencyContact2: secondary,
    priorDiveTimeSeconds: priorSeconds,
    divingSince: divingSince,
    notes: notes,
    createdAt: then,
    updatedAt: then,
  );

  const medical = (
    bloodType: '',
    allergies: '',
    medications: '',
    medicalNotes: '',
  );
  const personal = (
    name: 'Alice Alpha',
    email: 'alice@example.com',
    phone: '',
    social: '',
    sex: null,
    birthYear: '',
  );
  const contacts = (
    name1: 'Bob',
    phone1: '555 0101',
    relation1: 'Partner',
    name2: '',
    phone2: '',
    relation2: '',
  );
  const prior = (
    diveCount: '125',
    hours: '90',
    minutes: '5',
    divingSinceYear: 2001,
  );

  group('an unchanged draft returns the stored diver as it is', () {
    // Each stored diver differs from the start: a sync landed meanwhile.
    final synced = stored(
      name: 'Synced',
      bloodType: 'B-',
      primary: const EmergencyContact(name: 'Synced'),
      priorSeconds: 1,
      divingSince: DateTime(1999),
      notes: 'synced',
    );

    test('personal', () {
      expect(applyPersonalInfoDraft(synced, personal, personal), synced);
    });
    test('medical', () {
      expect(applyMedicalInfoDraft(synced, medical, medical), synced);
    });
    test('emergency contacts', () {
      expect(applyEmergencyContactsDraft(synced, contacts, contacts), synced);
    });
    test('notes', () {
      const notes = (notes: 'x');
      expect(applyDiverNotesDraft(synced, notes, notes), synced);
    });
    test('prior experience', () {
      expect(applyPriorExperienceDraft(synced, prior, prior), synced);
    });
  });

  test('a changed optional field is written trimmed; others keep storage', () {
    final result = applyMedicalInfoDraft(stored(bloodType: 'A+'), medical, (
      bloodType: '',
      allergies: ' nuts ',
      medications: '',
      medicalNotes: '',
    ));
    expect(result.allergies, 'nuts');
    expect(result.bloodType, 'A+');
  });

  test('clearing an optional field writes null', () {
    final result = applyMedicalInfoDraft(
      stored(allergies: 'nuts'),
      (bloodType: '', allergies: 'nuts', medications: '', medicalNotes: ''),
      (bloodType: '', allergies: '  ', medications: '', medicalNotes: ''),
    );
    expect(result.allergies, isNull);
  });

  test('medical notes are written trimmed, never null', () {
    final result = applyMedicalInfoDraft(stored(), medical, (
      bloodType: '',
      allergies: '',
      medications: '',
      medicalNotes: '  ',
    ));
    expect(result.medicalNotes, '');
  });

  test('a changed name keeps an email synced meanwhile', () {
    final result =
        applyPersonalInfoDraft(stored(email: 'synced@example.com'), personal, (
          name: ' Alice Beta ',
          email: 'alice@example.com',
          phone: '',
          social: '',
          sex: null,
          birthYear: '',
        ));
    expect(result.name, 'Alice Beta');
    expect(result.email, 'synced@example.com');
  });

  test('a changed sex and birth year are written', () {
    final result = applyPersonalInfoDraft(stored(), personal, (
      name: 'Alice Alpha',
      email: 'alice@example.com',
      phone: '',
      social: '',
      sex: DiverSex.female,
      birthYear: '1985',
    ));
    expect(result.sex, DiverSex.female);
    expect(result.birthYear, 1985);
  });

  test('a cleared birth year writes null', () {
    final result = applyPersonalInfoDraft(stored(), (
      name: 'Alice Alpha',
      email: 'alice@example.com',
      phone: '',
      social: '',
      sex: null,
      birthYear: '1985',
    ), personal);
    expect(result.birthYear, isNull);
  });

  test('a changed primary phone keeps the stored secondary contact', () {
    const secondary = EmergencyContact(name: 'Synced', phone: '1');
    final result = applyEmergencyContactsDraft(
      stored(
        primary: const EmergencyContact(
          name: 'Bob',
          phone: '555 0101',
          relation: 'Partner',
        ),
        secondary: secondary,
      ),
      contacts,
      (
        name1: 'Bob',
        phone1: '555 0199',
        relation1: 'Partner',
        name2: '',
        phone2: '',
        relation2: '',
      ),
    );
    expect(result.emergencyContact.phone, '555 0199');
    expect(result.emergencyContact2, secondary);
  });

  test(
    'a changed relation keeps the stored name and phone of that contact',
    () {
      final result = applyEmergencyContactsDraft(
        stored(
          primary: const EmergencyContact(
            name: 'Synced',
            phone: '9',
            relation: 'Partner',
          ),
        ),
        contacts,
        (
          name1: 'Bob',
          phone1: '555 0101',
          relation1: '',
          name2: '',
          phone2: '',
          relation2: '',
        ),
      );
      expect(
        result.emergencyContact,
        const EmergencyContact(name: 'Synced', phone: '9'),
      );
    },
  );

  test('changing minutes recomputes the prior time from both fields', () {
    final result = applyPriorExperienceDraft(stored(priorSeconds: 1), prior, (
      diveCount: '125',
      hours: '90',
      minutes: '10',
      divingSinceYear: 2001,
    ));
    expect(result.priorDiveTimeSeconds, 90 * 3600 + 600);
  });

  test('blanking both time fields writes no prior time', () {
    final result = applyPriorExperienceDraft(
      stored(priorSeconds: 324300),
      prior,
      (diveCount: '125', hours: '', minutes: '', divingSinceYear: 2001),
    );
    expect(result.priorDiveTimeSeconds, isNull);
  });

  test('an untouched time keeps stored seconds that are not whole minutes', () {
    final result = applyPriorExperienceDraft(
      stored(priorSeconds: 5430),
      prior,
      (diveCount: '126', hours: '90', minutes: '5', divingSinceYear: 2001),
    );
    expect(result.priorDiveTimeSeconds, 5430);
    expect(result.priorDiveCount, 126);
  });

  test('clearing diving since writes null', () {
    final result = applyPriorExperienceDraft(
      stored(divingSince: DateTime(2001)),
      prior,
      (diveCount: '125', hours: '90', minutes: '5', divingSinceYear: null),
    );
    expect(result.divingSince, isNull);
  });

  test('a changed diving since is written as that year', () {
    final result = applyPriorExperienceDraft(stored(), prior, (
      diveCount: '125',
      hours: '90',
      minutes: '5',
      divingSinceYear: 2005,
    ));
    expect(result.divingSince, DateTime(2005));
  });

  test('notes are written trimmed', () {
    final result = applyDiverNotesDraft(
      stored(),
      (notes: ''),
      (notes: ' Morning dives. '),
    );
    expect(result.notes, 'Morning dives.');
  });

  test('a new diver is built from the draft under the given id', () {
    final now = DateTime.utc(2026, 11, 22);
    final diver = newDiverFromDraft('n1', (
      name: ' Carlos ',
      email: '  ',
      phone: '555',
      social: '',
      sex: DiverSex.male,
      birthYear: '1990',
    ), now);
    expect(diver.id, 'n1');
    expect(diver.name, 'Carlos');
    expect(diver.email, isNull);
    expect(diver.phone, '555');
    expect(diver.socialHandle, isNull);
    expect(diver.sex, DiverSex.male);
    expect(diver.birthYear, 1990);
    expect(diver.createdAt, now);
    expect(diver.updatedAt, now);
  });

  // The profile editor skips a Save whose result equals the stored diver
  // (issue #4527, phase 4), so Diver's equality must see every field a page
  // writes: a field missing from Diver.props would make its edits vanish.
  test('every field a page writes makes the diver differ from storage', () {
    final base = stored();
    final changes = <String, Diver>{
      'name': applyPersonalInfoDraft(base, personal, (
        name: 'Alice Beta',
        email: personal.email,
        phone: '',
        social: '',
        sex: null,
        birthYear: '',
      )),
      'email': applyPersonalInfoDraft(base, personal, (
        name: personal.name,
        email: 'other@example.com',
        phone: '',
        social: '',
        sex: null,
        birthYear: '',
      )),
      'phone': applyPersonalInfoDraft(base, personal, (
        name: personal.name,
        email: personal.email,
        phone: '555',
        social: '',
        sex: null,
        birthYear: '',
      )),
      'social': applyPersonalInfoDraft(base, personal, (
        name: personal.name,
        email: personal.email,
        phone: '',
        social: '@alice',
        sex: null,
        birthYear: '',
      )),
      'sex': applyPersonalInfoDraft(base, personal, (
        name: personal.name,
        email: personal.email,
        phone: '',
        social: '',
        sex: DiverSex.female,
        birthYear: '',
      )),
      'birth year': applyPersonalInfoDraft(base, personal, (
        name: personal.name,
        email: personal.email,
        phone: '',
        social: '',
        sex: null,
        birthYear: '1985',
      )),
      'blood type': applyMedicalInfoDraft(base, medical, (
        bloodType: 'A+',
        allergies: '',
        medications: '',
        medicalNotes: '',
      )),
      'allergies': applyMedicalInfoDraft(base, medical, (
        bloodType: '',
        allergies: 'nuts',
        medications: '',
        medicalNotes: '',
      )),
      'medications': applyMedicalInfoDraft(base, medical, (
        bloodType: '',
        allergies: '',
        medications: 'none',
        medicalNotes: '',
      )),
      'medical notes': applyMedicalInfoDraft(base, medical, (
        bloodType: '',
        allergies: '',
        medications: '',
        medicalNotes: 'cleared',
      )),
      'primary contact': applyEmergencyContactsDraft(base, contacts, (
        name1: 'Robert',
        phone1: contacts.phone1,
        relation1: contacts.relation1,
        name2: '',
        phone2: '',
        relation2: '',
      )),
      'secondary contact': applyEmergencyContactsDraft(base, contacts, (
        name1: contacts.name1,
        phone1: contacts.phone1,
        relation1: contacts.relation1,
        name2: 'Carol',
        phone2: '',
        relation2: '',
      )),
      'notes': applyDiverNotesDraft(base, (notes: ''), (notes: 'note')),
      'dive count': applyPriorExperienceDraft(base, prior, (
        diveCount: '126',
        hours: prior.hours,
        minutes: prior.minutes,
        divingSinceYear: prior.divingSinceYear,
      )),
      'prior time': applyPriorExperienceDraft(base, prior, (
        diveCount: prior.diveCount,
        hours: '91',
        minutes: prior.minutes,
        divingSinceYear: prior.divingSinceYear,
      )),
      'diving since': applyPriorExperienceDraft(base, prior, (
        diveCount: prior.diveCount,
        hours: prior.hours,
        minutes: prior.minutes,
        divingSinceYear: 2005,
      )),
    };
    for (final MapEntry(key: field, value: result) in changes.entries) {
      expect(result, isNot(base), reason: field);
    }
  });
}
