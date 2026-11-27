import 'package:equatable/equatable.dart';

/// One emergency contact as the tag carries it.
class EmergencyTagContact extends Equatable {
  final String? name;
  final String? relation;
  final String? phone;

  const EmergencyTagContact({this.name, this.relation, this.phone});

  @override
  List<Object?> get props => [name, relation, phone];
}

/// The details an emergency tag carries (issue #5060): only what the diver
/// chose and recorded, every value trimmed and non-empty.
class EmergencyTagInfo extends Equatable {
  final String name;
  final int? birthYear;
  final String? allergies;
  final String? medications;
  final String? bloodType;
  final String? medicalNotes;
  final EmergencyTagContact? contact1;
  final EmergencyTagContact? contact2;
  final String? insurer;
  final String? policy;
  final String? assistanceLine;
  final DateTime written;

  /// Whether details were left off to fit the tag.
  final bool trimmed;

  const EmergencyTagInfo({
    required this.name,
    this.birthYear,
    this.allergies,
    this.medications,
    this.bloodType,
    this.medicalNotes,
    this.contact1,
    this.contact2,
    this.insurer,
    this.policy,
    this.assistanceLine,
    required this.written,
    this.trimmed = false,
  });

  EmergencyTagInfo copyWith({
    bool clearBirthYear = false,
    bool clearAllergies = false,
    bool clearMedications = false,
    bool clearBloodType = false,
    bool clearMedicalNotes = false,
    bool clearContact1 = false,
    bool clearContact2 = false,
    bool clearInsurer = false,
    bool clearPolicy = false,
    bool clearAssistanceLine = false,
    bool? trimmed,
  }) => EmergencyTagInfo(
    name: name,
    birthYear: clearBirthYear ? null : birthYear,
    allergies: clearAllergies ? null : allergies,
    medications: clearMedications ? null : medications,
    bloodType: clearBloodType ? null : bloodType,
    medicalNotes: clearMedicalNotes ? null : medicalNotes,
    contact1: clearContact1 ? null : contact1,
    contact2: clearContact2 ? null : contact2,
    insurer: clearInsurer ? null : insurer,
    policy: clearPolicy ? null : policy,
    assistanceLine: clearAssistanceLine ? null : assistanceLine,
    written: written,
    trimmed: trimmed ?? this.trimmed,
  );

  @override
  List<Object?> get props => [
    name,
    birthYear,
    allergies,
    medications,
    bloodType,
    medicalNotes,
    contact1,
    contact2,
    insurer,
    policy,
    assistanceLine,
    written,
    trimmed,
  ];
}
