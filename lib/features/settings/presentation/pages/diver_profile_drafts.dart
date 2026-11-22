import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

// What each diver profile page hands its sitting (issue #4527, phase 4):
// the form as it reads on screen, and what its Save writes. A page writes
// only the fields whose text changed since the form was filled, on top of
// the diver as stored at Save; every other field keeps its stored value,
// so a sync, the hub's avatar or another profile page is never overwritten.

/// The personal info page (and the new-diver page) as shown.
typedef PersonalInfoDraft = ({
  String name,
  String email,
  String phone,
  String social,
  DiverSex? sex,
  String birthYear,
});

/// The medical info page as shown.
typedef MedicalInfoDraft = ({
  String bloodType,
  String allergies,
  String medications,
  String medicalNotes,
});

/// The emergency contacts page as shown: the primary contact, then the
/// secondary.
typedef EmergencyContactsDraft = ({
  String name1,
  String phone1,
  String relation1,
  String name2,
  String phone2,
  String relation2,
});

/// The notes page as shown.
typedef DiverNotesDraft = ({String notes});

/// The prior experience page as shown.
typedef PriorExperienceDraft = ({
  String diveCount,
  String hours,
  String minutes,
  int? divingSinceYear,
});

/// [stored] with each personal field whose text differs between [start]
/// and [draft] set from [draft].
Diver applyPersonalInfoDraft(
  Diver stored,
  PersonalInfoDraft start,
  PersonalInfoDraft draft,
) => stored.copyWith(
  name: start.name == draft.name ? stored.name : draft.name.trim(),
  email: start.email == draft.email ? stored.email : _trimOrNull(draft.email),
  phone: start.phone == draft.phone ? stored.phone : _trimOrNull(draft.phone),
  socialHandle: start.social == draft.social
      ? stored.socialHandle
      : _trimOrNull(draft.social),
  sex: start.sex == draft.sex ? stored.sex : draft.sex,
  birthYear: start.birthYear == draft.birthYear
      ? stored.birthYear
      : _wholeNumber(draft.birthYear),
);

/// [stored] with each medical field whose text differs between [start] and
/// [draft] set from [draft].
Diver applyMedicalInfoDraft(
  Diver stored,
  MedicalInfoDraft start,
  MedicalInfoDraft draft,
) => stored.copyWith(
  bloodType: start.bloodType == draft.bloodType
      ? stored.bloodType
      : _trimOrNull(draft.bloodType),
  allergies: start.allergies == draft.allergies
      ? stored.allergies
      : _trimOrNull(draft.allergies),
  medications: start.medications == draft.medications
      ? stored.medications
      : _trimOrNull(draft.medications),
  medicalNotes: start.medicalNotes == draft.medicalNotes
      ? stored.medicalNotes
      : draft.medicalNotes.trim(),
);

/// [stored] with each contact field whose text differs between [start] and
/// [draft] set from [draft]. A contact is rebuilt field by field: its
/// `copyWith` cannot clear a field.
Diver applyEmergencyContactsDraft(
  Diver stored,
  EmergencyContactsDraft start,
  EmergencyContactsDraft draft,
) {
  String? field(String? kept, String before, String now) =>
      before == now ? kept : _trimOrNull(now);
  final one = stored.emergencyContact;
  final two = stored.emergencyContact2;
  return stored.copyWith(
    emergencyContact: EmergencyContact(
      name: field(one.name, start.name1, draft.name1),
      phone: field(one.phone, start.phone1, draft.phone1),
      relation: field(one.relation, start.relation1, draft.relation1),
    ),
    emergencyContact2: EmergencyContact(
      name: field(two.name, start.name2, draft.name2),
      phone: field(two.phone, start.phone2, draft.phone2),
      relation: field(two.relation, start.relation2, draft.relation2),
    ),
  );
}

/// [stored] with its notes from [draft] when they differ from [start].
Diver applyDiverNotesDraft(
  Diver stored,
  DiverNotesDraft start,
  DiverNotesDraft draft,
) => start.notes == draft.notes
    ? stored
    : stored.copyWith(notes: draft.notes.trim());

/// [stored] with each prior experience value whose text differs between
/// [start] and [draft] set from [draft]. Hours and minutes are one value:
/// a change to either recomputes it from both.
Diver applyPriorExperienceDraft(
  Diver stored,
  PriorExperienceDraft start,
  PriorExperienceDraft draft,
) {
  final timeChanged =
      start.hours != draft.hours || start.minutes != draft.minutes;
  final year = draft.divingSinceYear;
  return stored.copyWith(
    priorDiveCount: start.diveCount == draft.diveCount
        ? stored.priorDiveCount
        : _wholeNumber(draft.diveCount),
    priorDiveTimeSeconds: timeChanged
        ? _priorSeconds(draft.hours, draft.minutes)
        : stored.priorDiveTimeSeconds,
    divingSince: start.divingSinceYear == year
        ? stored.divingSince
        : (year == null ? null : DateTime(year)),
  );
}

/// A new diver from the new-diver page's form, under [id].
Diver newDiverFromDraft(String id, PersonalInfoDraft draft, DateTime now) =>
    Diver(
      id: id,
      name: draft.name.trim(),
      email: _trimOrNull(draft.email),
      phone: _trimOrNull(draft.phone),
      socialHandle: _trimOrNull(draft.social),
      sex: draft.sex,
      birthYear: _wholeNumber(draft.birthYear),
      createdAt: now,
      updatedAt: now,
    );

String? _trimOrNull(String text) {
  final value = text.trim();
  return value.isEmpty ? null : value;
}

/// A whole number once the form has validated: blank is "not given", and
/// unreadable text cannot reach here.
int? _wholeNumber(String text) => switch (readNumber(text, integer: true)) {
  NumberValue(:final value) => value.round(),
  NumberBlank() || NumberInvalid() => null,
};

/// The prior bottom time from its two fields: both blank is none.
int? _priorSeconds(String hours, String minutes) {
  if (hours.trim().isEmpty && minutes.trim().isEmpty) return null;
  return (_wholeNumber(hours) ?? 0) * 3600 + (_wholeNumber(minutes) ?? 0) * 60;
}
