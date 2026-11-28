import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/domain/services/emergency_tag_codec.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The words the tag's text record uses, in the app's language, with dates
/// written by [formatDate] (the diver's date format).
EmergencyTagLabels emergencyTagLabels(
  AppLocalizations l10n,
  String Function(DateTime date) formatDate,
) => EmergencyTagLabels(
  header: l10n.emergencyTag_text_header,
  name: l10n.emergencyTag_text_name,
  born: (year) => l10n.emergencyTag_text_born('$year'),
  allergies: l10n.emergencyTag_field_allergies,
  contact: l10n.emergencyTag_text_contact,
  insurance: l10n.emergencyTag_field_insurance,
  policy: l10n.emergencyTag_text_policy,
  assistanceLine: l10n.emergencyTag_text_assistanceLine,
  medications: l10n.emergencyTag_field_medications,
  bloodType: l10n.emergencyTag_field_bloodType,
  medicalNotes: l10n.emergencyTag_field_medicalNotes,
  written: (date) => l10n.emergencyTag_text_written(formatDate(date)),
  someLeftOff: l10n.emergencyTag_text_someLeftOff,
);

/// The switch label for [field].
String emergencyTagFieldName(AppLocalizations l10n, EmergencyTagField field) =>
    switch (field) {
      EmergencyTagField.birthYear => l10n.emergencyTag_field_birthYear,
      EmergencyTagField.allergies => l10n.emergencyTag_field_allergies,
      EmergencyTagField.medications => l10n.emergencyTag_field_medications,
      EmergencyTagField.bloodType => l10n.emergencyTag_field_bloodType,
      EmergencyTagField.medicalNotes => l10n.emergencyTag_field_medicalNotes,
      EmergencyTagField.contact1 => l10n.emergencyTag_field_contact1,
      EmergencyTagField.contact2 => l10n.emergencyTag_field_contact2,
      EmergencyTagField.insurance => l10n.emergencyTag_field_insurance,
    };

/// A readable name for a key left off a small tag, as the write sheet lists
/// them.
String emergencyTagDroppedLabel(AppLocalizations l10n, String key) =>
    switch (key) {
      'mn' => l10n.emergencyTag_field_medicalNotes,
      'y' => l10n.emergencyTag_field_birthYear,
      'c2' => l10n.emergencyTag_field_contact2,
      'ip' => l10n.emergencyTag_field_policy,
      'me' => l10n.emergencyTag_field_medications,
      'bt' => l10n.emergencyTag_field_bloodType,
      'in' => l10n.emergencyTag_field_insurance,
      'al' => l10n.emergencyTag_field_allergies,
      'c1' => l10n.emergencyTag_field_contact1,
      _ => key,
    };

/// The menu label for a call [target].
String emergencyCallTargetName(
  AppLocalizations l10n,
  EmergencyCallTarget target,
) => switch (target) {
  EmergencyCallTarget.contact1 => l10n.emergencyTag_callTarget_contact1,
  EmergencyCallTarget.contact2 => l10n.emergencyTag_callTarget_contact2,
  EmergencyCallTarget.insurer => l10n.emergencyTag_callTarget_insurer,
};
