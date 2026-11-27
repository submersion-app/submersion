import 'dart:convert';
import 'dart:typed_data';

import 'package:ndef_record/ndef_record.dart';

import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_info.dart';

/// The words the text record uses, in the diver's app language.
class EmergencyTagLabels {
  const EmergencyTagLabels({
    required this.header,
    required this.name,
    required this.born,
    required this.allergies,
    required this.contact,
    required this.insurance,
    required this.policy,
    required this.assistanceLine,
    required this.medications,
    required this.bloodType,
    required this.medicalNotes,
    required this.written,
    required this.someLeftOff,
  });

  final String header;
  final String name;
  final String Function(int year) born;
  final String allergies;
  final String contact;
  final String insurance;
  final String Function(String number) policy;
  final String Function(String number) assistanceLine;
  final String medications;
  final String bloodType;
  final String medicalNotes;
  final String Function(DateTime date) written;
  final String someLeftOff;
}

/// A well-known text record (NFC Forum RTD Text): UTF-8 [text] in
/// [languageCode].
NdefRecord textRecord(String text, {required String languageCode}) {
  final lang = utf8.encode(languageCode);
  return NdefRecord(
    typeNameFormat: TypeNameFormat.wellKnown,
    type: Uint8List.fromList(const [0x54]),
    identifier: Uint8List(0),
    payload: Uint8List.fromList([lang.length, ...lang, ...utf8.encode(text)]),
  );
}

/// What an emergency tag write puts on a tag.
class EmergencyTagNdefPlan implements TagNdefPlan {
  const EmergencyTagNdefPlan({
    required this.message,
    required this.url,
    required this.droppedKeys,
    required this.info,
  });

  @override
  final NdefMessage message;

  /// The first record's link: the emergency link or the `tel:` number.
  @override
  final String url;

  @override
  final List<String> droppedKeys;

  /// The details the tag carries, after any drops.
  final EmergencyTagInfo info;

  @override
  bool get includesAndroidRecord => false;

  @override
  bool get includesFill => false;
}

/// Reads and writes emergency tags (issue #5060); the format is in
/// `docs/developer/reference/formats/emergency-tag.md`.
abstract final class EmergencyTagCodec {
  static const int currentVersion = 1;
  static const String linkPrefix = 'https://submersion.app/e#';

  /// Fields come off both records together, in this order, until the
  /// message fits. The name is never dropped.
  static const List<String> dropOrder = [
    'mn',
    'y',
    'c2',
    'ip',
    'me',
    'bt',
    'in',
    'al',
    'c1',
  ];

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// [info] as an emergency link, the payload in the fragment.
  static String link(EmergencyTagInfo info) {
    final pairs = <(String, String?)>[
      ('f', '$currentVersion'),
      ('w', _date(info.written)),
      ('n', info.name),
      ('y', info.birthYear?.toString()),
      ('al', info.allergies),
      ('me', info.medications),
      ('bt', info.bloodType),
      ('mn', info.medicalNotes),
      ('c1', info.contact1?.name),
      ('r1', info.contact1?.relation),
      ('p1', info.contact1?.phone),
      ('c2', info.contact2?.name),
      ('r2', info.contact2?.relation),
      ('p2', info.contact2?.phone),
      ('in', info.insurer),
      ('ip', info.policy),
      ('il', info.assistanceLine),
      if (info.trimmed) ('t', '1'),
    ];
    final query = [
      for (final (key, value) in pairs)
        if (value != null) '$key=${Uri.encodeQueryComponent(value)}',
    ].join('&');
    return '$linkPrefix$query';
  }

  static String? _contactLine(EmergencyTagContact? c) {
    if (c == null) return null;
    return [
      if (c.name != null) c.name!,
      if (c.relation != null) '(${c.relation})',
      if (c.phone != null) c.phone!,
    ].join(' ');
  }

  /// [info] as the plain text a reader shows, most urgent first.
  static String text(EmergencyTagInfo info, EmergencyTagLabels labels) {
    final insurance = [
      if (info.insurer != null) info.insurer!,
      if (info.policy != null) labels.policy(info.policy!),
      if (info.assistanceLine != null)
        labels.assistanceLine(info.assistanceLine!),
    ].join(', ');
    final contact1 = _contactLine(info.contact1);
    final contact2 = _contactLine(info.contact2);
    return [
      labels.header,
      '${labels.name}: ${info.name}'
          '${info.birthYear == null ? '' : ' (${labels.born(info.birthYear!)})'}',
      if (info.allergies != null) '${labels.allergies}: ${info.allergies}',
      if (contact1 != null) '${labels.contact}: $contact1',
      if (contact2 != null) '${labels.contact}: $contact2',
      if (insurance.isNotEmpty) '${labels.insurance}: $insurance',
      if (info.medications != null)
        '${labels.medications}: ${info.medications}',
      if (info.bloodType != null) '${labels.bloodType}: ${info.bloodType}',
      if (info.medicalNotes != null)
        '${labels.medicalNotes}: ${info.medicalNotes}',
      if (info.trimmed) labels.someLeftOff,
      labels.written(info.written),
    ].join('\n');
  }

  /// [info] without the details [key] stands for.
  static EmergencyTagInfo drop(EmergencyTagInfo info, String key) =>
      switch (key) {
        'mn' => info.copyWith(clearMedicalNotes: true),
        'y' => info.copyWith(clearBirthYear: true),
        'c2' => info.copyWith(clearContact2: true),
        'ip' => info.copyWith(clearPolicy: true),
        'me' => info.copyWith(clearMedications: true),
        'bt' => info.copyWith(clearBloodType: true),
        'in' => info.copyWith(
          clearInsurer: true,
          clearPolicy: true,
          clearAssistanceLine: true,
        ),
        'al' => info.copyWith(clearAllergies: true),
        'c1' => info.copyWith(clearContact1: true),
        _ => info,
      };

  static NdefMessage _message(
    EmergencyTagInfo info,
    String firstUri,
    EmergencyTagLabels labels,
    String languageCode, {
    required bool includeText,
  }) => NdefMessage(
    records: [
      uriRecord(firstUri),
      if (includeText)
        textRecord(text(info, labels), languageCode: languageCode),
    ],
  );

  /// The message for [info] on a tag that takes [maxMessageBytes]: the
  /// first record (the emergency link, or the `tel:` link [firstRecordUri]
  /// gives) and, when [includeText], the text record, with fields dropped
  /// from both in [dropOrder] until it fits. Null when even the name does
  /// not fit.
  static EmergencyTagNdefPlan? plan(
    EmergencyTagInfo info, {
    required EmergencyTagLabels labels,
    required String languageCode,
    String Function(EmergencyTagInfo info)? firstRecordUri,
    bool includeText = true,
    required int maxMessageBytes,
  }) {
    final firstUri = firstRecordUri ?? link;
    var current = info;
    final dropped = <String>[];
    var i = 0;
    while (true) {
      final uri = firstUri(current);
      final message = _message(
        current,
        uri,
        labels,
        languageCode,
        includeText: includeText,
      );
      if (message.byteLength <= maxMessageBytes) {
        return EmergencyTagNdefPlan(
          message: message,
          url: uri,
          droppedKeys: List.unmodifiable(dropped),
          info: current,
        );
      }
      if (i >= dropOrder.length) return null;
      final key = dropOrder[i++];
      final next = drop(current, key).copyWith(trimmed: true);
      if (next.copyWith(trimmed: current.trimmed) != current) dropped.add(key);
      current = next;
    }
  }

  /// Bytes [message] takes in a tag's user memory: the message, its TLV
  /// header (2 bytes below 255, 4 above) and the terminator.
  static int tagBytes(NdefMessage message) {
    final length = message.byteLength;
    return length + (length < 255 ? 2 : 4) + 1;
  }
}
