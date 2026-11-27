import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_info.dart';

/// Turns a diver's profile and their choices into what the emergency tag
/// carries (issue #5060).
abstract final class EmergencyTagBuilder {
  static String? _present(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  static EmergencyTagContact? _contact(EmergencyContact c) {
    final contact = EmergencyTagContact(
      name: _present(c.name),
      relation: _present(c.relation),
      phone: _present(c.phone),
    );
    return contact.name == null && contact.phone == null ? null : contact;
  }

  static bool _hasInsurance(DiverInsurance i) =>
      i.providerLabel != null ||
      i.policyLabel != null ||
      i.assistanceLine != null;

  /// The fields [diver] has something recorded for.
  static Set<EmergencyTagField> availableFields(Diver diver) => {
    if (diver.birthYear != null) EmergencyTagField.birthYear,
    if (_present(diver.allergies) != null) EmergencyTagField.allergies,
    if (_present(diver.medications) != null) EmergencyTagField.medications,
    if (_present(diver.bloodType) != null) EmergencyTagField.bloodType,
    if (_present(diver.medicalNotes) != null) EmergencyTagField.medicalNotes,
    if (_contact(diver.emergencyContact) != null) EmergencyTagField.contact1,
    if (_contact(diver.emergencyContact2) != null) EmergencyTagField.contact2,
    if (_hasInsurance(diver.insurance)) EmergencyTagField.insurance,
  };

  /// What the tag carries for [diver] under [choices], written on [written].
  static EmergencyTagInfo build(
    Diver diver,
    EmergencyTagChoices choices, {
    required DateTime written,
  }) {
    bool on(EmergencyTagField field) => choices.fields.contains(field);
    final insurance = on(EmergencyTagField.insurance) ? diver.insurance : null;
    return EmergencyTagInfo(
      name: diver.name.trim(),
      birthYear: on(EmergencyTagField.birthYear) ? diver.birthYear : null,
      allergies: on(EmergencyTagField.allergies)
          ? _present(diver.allergies)
          : null,
      medications: on(EmergencyTagField.medications)
          ? _present(diver.medications)
          : null,
      bloodType: on(EmergencyTagField.bloodType)
          ? _present(diver.bloodType)
          : null,
      medicalNotes: on(EmergencyTagField.medicalNotes)
          ? _present(diver.medicalNotes)
          : null,
      contact1: on(EmergencyTagField.contact1)
          ? _contact(diver.emergencyContact)
          : null,
      contact2: on(EmergencyTagField.contact2)
          ? _contact(diver.emergencyContact2)
          : null,
      insurer: insurance?.providerLabel,
      policy: insurance?.policyLabel,
      assistanceLine: insurance?.assistanceLine,
      written: written,
    );
  }

  static String? _number(Diver diver, EmergencyCallTarget target) =>
      switch (target) {
        EmergencyCallTarget.contact1 => _present(diver.emergencyContact.phone),
        EmergencyCallTarget.contact2 => _present(diver.emergencyContact2.phone),
        EmergencyCallTarget.insurer => diver.insurance.assistanceLine,
      };

  /// The call targets [diver] has a number for, in menu order.
  static List<EmergencyCallTarget> callTargets(Diver diver) => [
    for (final target in EmergencyCallTarget.values)
      if (dialable(_number(diver, target)) != null) target,
  ];

  /// [number] as a `tel:` link: digits, with a leading plus kept. Null when
  /// no digit is left.
  static String? dialable(String? number) {
    if (number == null) return null;
    final trimmed = number.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return 'tel:${trimmed.startsWith('+') ? '+' : ''}$digits';
  }

  /// The `tel:` link a call tag dials for [target]; null when [diver] has no
  /// number there.
  static String? callUri(Diver diver, EmergencyCallTarget target) =>
      dialable(_number(diver, target));
}
