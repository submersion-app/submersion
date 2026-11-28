import 'dart:convert';

import 'package:equatable/equatable.dart';

/// What a tap on the tag does: open the details as a web page, or call a
/// number (issue #5060).
enum EmergencyTagPrimary { link, call }

/// The number a call tag dials.
enum EmergencyCallTarget { contact1, contact2, insurer }

/// A detail the diver may put on their emergency tag. The name is always on
/// it, so it has no switch.
enum EmergencyTagField {
  birthYear,
  allergies,
  medications,
  bloodType,
  medicalNotes,
  contact1,
  contact2,
  insurance,
}

/// What a diver puts on their emergency tag, remembered between writes.
class EmergencyTagChoices extends Equatable {
  final EmergencyTagPrimary primary;
  final EmergencyCallTarget callTarget;
  final Set<EmergencyTagField> fields;

  /// Whether a link tag also carries the details as a plain-text record,
  /// which reader apps show offline. Leaving it off gives the link the whole
  /// tag. A call tag always carries the text: it is where its details are.
  final bool includeText;

  const EmergencyTagChoices({
    required this.primary,
    required this.callTarget,
    required this.fields,
    this.includeText = true,
  });

  /// Medical notes are free text and the most likely to overflow a tag, and
  /// a birth year is not needed to treat the diver, so both start off.
  static const defaults = EmergencyTagChoices(
    primary: EmergencyTagPrimary.link,
    callTarget: EmergencyCallTarget.contact1,
    fields: {
      EmergencyTagField.allergies,
      EmergencyTagField.medications,
      EmergencyTagField.bloodType,
      EmergencyTagField.contact1,
      EmergencyTagField.contact2,
      EmergencyTagField.insurance,
    },
  );

  /// Reads stored choices. Null, unreadable JSON, a missing key or a value
  /// of the wrong type all take the default, key by key.
  factory EmergencyTagChoices.fromJson(String? json) {
    if (json == null) return defaults;
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return defaults;
    }
    if (decoded is! Map<String, Object?>) return defaults;

    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;

    final stored = decoded['fields'];
    final fields = {
      for (final field in EmergencyTagField.values)
        if (switch (stored is Map<String, Object?>
            ? stored[field.name]
            : null) {
          final bool on => on,
          _ => defaults.fields.contains(field),
        })
          field,
    };
    return EmergencyTagChoices(
      primary: byName(
        EmergencyTagPrimary.values,
        decoded['primary'],
        defaults.primary,
      ),
      callTarget: byName(
        EmergencyCallTarget.values,
        decoded['callTarget'],
        defaults.callTarget,
      ),
      fields: fields,
      includeText: switch (decoded['text']) {
        final bool on => on,
        _ => defaults.includeText,
      },
    );
  }

  String toJson() => jsonEncode({
    'primary': primary.name,
    'callTarget': callTarget.name,
    'fields': {
      for (final field in EmergencyTagField.values)
        field.name: fields.contains(field),
    },
    'text': includeText,
  });

  EmergencyTagChoices copyWith({
    EmergencyTagPrimary? primary,
    EmergencyCallTarget? callTarget,
    Set<EmergencyTagField>? fields,
    bool? includeText,
  }) => EmergencyTagChoices(
    primary: primary ?? this.primary,
    callTarget: callTarget ?? this.callTarget,
    fields: fields ?? this.fields,
    includeText: includeText ?? this.includeText,
  );

  /// These choices with [field] switched [on].
  EmergencyTagChoices withField(EmergencyTagField field, bool on) =>
      copyWith(fields: on ? {...fields, field} : ({...fields}..remove(field)));

  @override
  List<Object?> get props => [primary, callTarget, fields, includeText];
}
