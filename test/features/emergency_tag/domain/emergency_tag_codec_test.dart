import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ndef_record/ndef_record.dart';

import 'package:submersion/features/cylinder_passports/domain/services/passport_ndef.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_info.dart';
import 'package:submersion/features/emergency_tag/domain/services/emergency_tag_codec.dart';

const labels = EmergencyTagLabels(
  header: 'EMERGENCY INFO',
  name: 'Name',
  born: _born,
  allergies: 'Allergies',
  contact: 'Emergency contact',
  insurance: 'Insurance',
  policy: _policy,
  assistanceLine: _line,
  medications: 'Medications',
  bloodType: 'Blood type',
  medicalNotes: 'Medical notes',
  written: _written,
  someLeftOff: 'Some details were left off to fit the tag.',
);

String _born(int year) => 'born $year';
String _policy(String n) => 'policy $n';
String _line(String n) => '24h line $n';
String _written(DateTime d) =>
    'Written ${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')} with Submersion';

void main() {
  final full = EmergencyTagInfo(
    name: 'Sam Diver',
    birthYear: 1984,
    allergies: 'Penicillin',
    medications: 'None',
    bloodType: 'O+',
    medicalNotes: 'Asthma as a child',
    contact1: const EmergencyTagContact(
      name: 'Alex Diver',
      relation: 'Partner',
      phone: '+15551234567',
    ),
    insurer: 'DAN',
    policy: '1234567',
    assistanceLine: '+19196849111',
    written: DateTime(2026, 11, 27),
  );

  group('link', () {
    test('matches the worked example in the format doc', () {
      expect(
        EmergencyTagCodec.link(full),
        'https://submersion.app/e#f=1&w=2026-11-27&n=Sam+Diver&y=1984'
        '&al=Penicillin&me=None&bt=O%2B&mn=Asthma+as+a+child'
        '&c1=Alex+Diver&r1=Partner&p1=%2B15551234567'
        '&in=DAN&ip=1234567&il=%2B19196849111',
      );
    });

    test('leaves out absent keys and marks a trimmed tag', () {
      final info = EmergencyTagInfo(
        name: 'Sam',
        written: DateTime(2026, 1, 2),
        trimmed: true,
      );
      expect(
        EmergencyTagCodec.link(info),
        'https://submersion.app/e#f=1&w=2026-01-02&n=Sam&t=1',
      );
    });
  });

  group('text', () {
    test('puts what a responder needs first', () {
      expect(
        EmergencyTagCodec.text(full, labels),
        'EMERGENCY INFO\n'
        'Name: Sam Diver (born 1984)\n'
        'Allergies: Penicillin\n'
        'Emergency contact: Alex Diver (Partner) +15551234567\n'
        'Insurance: DAN, policy 1234567, 24h line +19196849111\n'
        'Medications: None\n'
        'Blood type: O+\n'
        'Medical notes: Asthma as a child\n'
        'Written 2026-11-27 with Submersion',
      );
    });

    test('says when details were left off', () {
      final info = EmergencyTagInfo(
        name: 'Sam',
        written: DateTime(2026, 11, 27),
        trimmed: true,
      );
      expect(
        EmergencyTagCodec.text(info, labels),
        'EMERGENCY INFO\n'
        'Name: Sam\n'
        'Some details were left off to fit the tag.\n'
        'Written 2026-11-27 with Submersion',
      );
    });
  });

  test('a second emergency contact gets its own line and keys', () {
    final info = EmergencyTagInfo(
      name: full.name,
      contact1: full.contact1,
      contact2: const EmergencyTagContact(name: 'Jo', phone: '+4412'),
      insurer: 'DAN',
      written: full.written,
    );
    expect(
      EmergencyTagCodec.text(info, labels),
      contains(
        'Emergency contact: Alex Diver (Partner) +15551234567\n'
        'Emergency contact: Jo +4412\n',
      ),
    );
    expect(EmergencyTagCodec.link(info), contains('&c2=Jo&p2=%2B4412&'));
  });

  group('text record', () {
    test('is a well-known T record with the language code', () {
      final record = textRecord('Hi', languageCode: 'en');
      expect(record.typeNameFormat, TypeNameFormat.wellKnown);
      expect(record.type, [0x54]);
      expect(record.payload.first, 2);
      expect(utf8.decode(record.payload.sublist(1, 3)), 'en');
      expect(utf8.decode(record.payload.sublist(3)), 'Hi');
    });
  });

  group('drop', () {
    test('drops in the order the spec gives', () {
      expect(EmergencyTagCodec.dropOrder, [
        'mn',
        'y',
        'c2',
        'ip',
        'me',
        'bt',
        'in',
        'al',
        'c1',
      ]);
    });

    test('dropping insurance clears every insurance key', () {
      final dropped = EmergencyTagCodec.drop(full, 'in');
      expect(dropped.insurer, isNull);
      expect(dropped.policy, isNull);
      expect(dropped.assistanceLine, isNull);
      expect(dropped.allergies, 'Penicillin');
    });
  });

  group('plan', () {
    NdefMessage? messageFor(int max, {String? first}) => EmergencyTagCodec.plan(
      full,
      labels: labels,
      languageCode: 'en',
      firstRecordUri: first == null ? null : (_) => first,
      maxMessageBytes: max,
    )?.message;

    test('a roomy tag holds the link and the text, whole', () {
      final plan = EmergencyTagCodec.plan(
        full,
        labels: labels,
        languageCode: 'en',
        maxMessageBytes: 888,
      )!;
      expect(plan.droppedKeys, isEmpty);
      expect(plan.message.records, hasLength(2));
      expect(uriOf(plan.message.records.first), EmergencyTagCodec.link(full));
      expect(plan.url, EmergencyTagCodec.link(full));
      expect(plan.includesAndroidRecord, isFalse);
      expect(plan.includesFill, isFalse);
    });

    test('a call tag starts with the tel link', () {
      final message = messageFor(888, first: 'tel:+15551234567')!;
      expect(uriOf(message.records.first), 'tel:+15551234567');
      expect(message.records, hasLength(2));
    });

    test('a small tag drops fields from both records in order', () {
      final plan = EmergencyTagCodec.plan(
        full,
        labels: labels,
        languageCode: 'en',
        maxMessageBytes: 300,
      )!;
      // The fixture has no second contact, so c2 drops nothing and is not
      // reported.
      final present = EmergencyTagCodec.dropOrder.where((k) => k != 'c2');
      expect(plan.droppedKeys, isNotEmpty);
      expect(plan.droppedKeys, present.take(plan.droppedKeys.length).toList());
      expect(plan.message.byteLength, lessThanOrEqualTo(300));
      expect(uriOf(plan.message.records.first), contains('&t=1'));
      final text = utf8.decode(plan.message.records.last.payload.sublist(3));
      expect(text, contains('Some details were left off'));
      expect(text, isNot(contains('Asthma')));
    });

    test('without the text, the link alone fills the tag', () {
      final plan = EmergencyTagCodec.plan(
        full,
        labels: labels,
        languageCode: 'en',
        includeText: false,
        maxMessageBytes: 300,
      )!;
      expect(plan.message.records, hasLength(1));
      expect(plan.droppedKeys, isEmpty);
      expect(uriOf(plan.message.records.single), EmergencyTagCodec.link(full));
    });

    test('null when not even the name fits', () {
      expect(messageFor(40), isNull);
    });
  });

  group('tagBytes', () {
    test('adds the TLV header and terminator to the message', () {
      final message = EmergencyTagCodec.plan(
        full,
        labels: labels,
        languageCode: 'en',
        maxMessageBytes: 888,
      )!.message;
      final bytes = EmergencyTagCodec.tagBytes(message);
      expect(bytes, message.byteLength + (message.byteLength < 255 ? 3 : 5));
    });
  });
}
