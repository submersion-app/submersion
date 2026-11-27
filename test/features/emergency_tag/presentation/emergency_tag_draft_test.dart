import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/domain/services/emergency_tag_codec.dart';
import 'package:submersion/features/emergency_tag/presentation/utils/emergency_tag_draft.dart';

const labels = EmergencyTagLabels(
  header: 'EMERGENCY INFO',
  name: 'Name',
  born: _born,
  allergies: 'Allergies',
  contact: 'Emergency contact',
  insurance: 'Insurance',
  policy: _same,
  assistanceLine: _same,
  medications: 'Medications',
  bloodType: 'Blood type',
  medicalNotes: 'Medical notes',
  written: _written,
  someLeftOff: 'Left off',
);

String _born(int year) => 'born $year';
String _same(String n) => n;
String _written(DateTime d) => 'Written';

void main() {
  final base = Diver(
    id: 'd1',
    name: 'Sam',
    allergies: 'Penicillin',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  EmergencyTagDraft draftOf(Diver diver, EmergencyTagChoices choices) =>
      EmergencyTagDraft.of(
        diver,
        choices,
        written: DateTime(2026, 11, 27),
        labels: labels,
        languageCode: 'en',
      );

  const call = EmergencyTagChoices(
    primary: EmergencyTagPrimary.call,
    callTarget: EmergencyCallTarget.contact2,
    fields: {EmergencyTagField.allergies},
  );

  test('a call tag with no number to call falls back to the link', () {
    final draft = draftOf(base, call);
    expect(draft.choices.primary, EmergencyTagPrimary.link);
    expect(draft.callUri, isNull);
    expect(draft.firstUri, startsWith(EmergencyTagCodec.linkPrefix));
  });

  test('a link tag may leave the text off; a call tag always has it', () {
    final diver = base.copyWith(
      emergencyContact: const EmergencyContact(name: 'Alex', phone: '+1 555'),
    );
    final linkOnly = draftOf(
      diver,
      EmergencyTagChoices.defaults.copyWith(includeText: false),
    );
    expect(linkOnly.includeText, isFalse);
    expect(linkOnly.planFor(888)!.message.records, hasLength(1));
    final callOnly = draftOf(diver, call.copyWith(includeText: false));
    expect(callOnly.includeText, isTrue);
    expect(callOnly.planFor(888)!.message.records, hasLength(2));
  });

  test('a call target with no number moves to the first with one', () {
    final diver = base.copyWith(
      emergencyContact: const EmergencyContact(name: 'Alex', phone: '+1 555'),
    );
    final draft = draftOf(diver, call);
    expect(draft.choices.callTarget, EmergencyCallTarget.contact1);
    expect(draft.firstUri, 'tel:+1555');
  });

  test('the text and the smallest tag follow the chosen fields', () {
    final draft = draftOf(base, EmergencyTagChoices.defaults);
    expect(draft.text, contains('Allergies: Penicillin'));
    expect(draft.smallestTag, 'NTAG213');
    expect(draft.tagBytes, lessThanOrEqualTo(144));
  });

  test('a message too big for every common tag has no smallest tag', () {
    final diver = base.copyWith(medicalNotes: 'x' * 1000);
    final draft = draftOf(
      diver,
      EmergencyTagChoices.defaults.withField(
        EmergencyTagField.medicalNotes,
        true,
      ),
    );
    expect(draft.smallestTag, isNull);
    expect(draft.planFor(888)!.droppedKeys, contains('mn'));
  });
}
