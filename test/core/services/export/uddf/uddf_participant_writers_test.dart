import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_participant_writers.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

final _epoch = DateTime(2024, 1, 1);

Buddy _buddy(String id, String name) => Buddy(
  id: id,
  name: name,
  email: '$id@example.test',
  phone: '555-0100',
  notes: 'private note',
  certificationLevel: CertificationLevel.rescue,
  certificationAgency: CertificationAgency.padi,
  createdAt: _epoch,
  updatedAt: _epoch,
);

BuddyWithRole _row(Buddy buddy, String roleId) => BuddyWithRole(
  buddy: buddy,
  role: DiveRole(
    id: roleId,
    name: roleId,
    createdAt: _epoch,
    updatedAt: _epoch,
  ),
);

XmlElement _write(void Function(XmlBuilder builder) body) {
  final builder = XmlBuilder();
  builder.element('root', nest: () => body(builder));
  return builder.buildDocument().rootElement;
}

final _guide = _buddy('g', 'Nicol Sorin');
final _master = _buddy('m', 'Ana Reyes');
final _plain = _buddy('p', 'Joe Bloggs');
final _solo = _buddy('s', 'Solo Sam');
final _rows = [
  _row(_guide, DiveRole.diveGuideId),
  _row(_plain, DiveRole.buddyId),
  _row(_master, DiveRole.diveMasterId),
  _row(_solo, DiveRole.soloId),
];
final _dive = Dive(id: 'd1', dateTime: DateTime(2026, 3, 1));

void main() {
  group('writeBuddyDeclarations', () {
    test('writes contact details and notes by default', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeBuddyDeclarations(b, [_guide]),
      );
      final buddy = root.findElements('buddy').single;
      expect(buddy.getAttribute('id'), 'buddy_g');
      expect(buddy.findAllElements('firstname').single.innerText, 'Nicol');
      expect(buddy.findAllElements('lastname').single.innerText, 'Sorin');
      expect(buddy.findAllElements('email').single.innerText, 'g@example.test');
      expect(buddy.findAllElements('phone').single.innerText, '555-0100');
      expect(buddy.findElements('notes').single.innerText, 'private note');
      expect(buddy.findAllElements('level').single.innerText, 'rescue');
      expect(buddy.findAllElements('agency').single.innerText, 'padi');
    });

    test('trimmed keeps name and certification only', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeBuddyDeclarations(b, [
          _guide,
        ], trimmed: true),
      );
      final buddy = root.findElements('buddy').single;
      expect(buddy.findAllElements('firstname').single.innerText, 'Nicol');
      expect(buddy.findAllElements('lastname').single.innerText, 'Sorin');
      expect(buddy.findAllElements('level').single.innerText, 'rescue');
      expect(buddy.findAllElements('agency').single.innerText, 'padi');
      expect(buddy.findAllElements('email'), isEmpty);
      expect(buddy.findAllElements('phone'), isEmpty);
      expect(buddy.findAllElements('notes'), isEmpty);
    });
  });

  group('writeLeaders', () {
    test('joins every leader name in row order', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeLeaders(b, _dive, _rows),
      );
      expect(
        root.findElements('divemaster').single.innerText,
        'Nicol Sorin, Ana Reyes',
      );
    });

    test('falls back to the legacy text when no leader is linked', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeLeaders(
          b,
          _dive.copyWith(diveMaster: 'Legacy Master'),
          [_row(_plain, DiveRole.buddyId)],
        ),
      );
      expect(root.findElements('divemaster').single.innerText, 'Legacy Master');
    });

    test('writes nothing with neither', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeLeaders(b, _dive, const []),
      );
      expect(root.findElements('divemaster'), isEmpty);
    });
  });

  test('writeLinks links every row, leaders and solo included', () {
    final root = _write((b) => UddfParticipantWriters.writeLinks(b, _rows));
    expect(root.findElements('link').map((e) => e.getAttribute('ref')), [
      'buddy_g',
      'buddy_p',
      'buddy_m',
      'buddy_s',
    ]);
  });

  group('writeInlineBuddies', () {
    test('writes plain buddies only, skipping leaders and solo', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeInlineBuddies(b, _dive, _rows),
      );
      final names = root
          .findElements('buddy')
          .map((e) => e.findAllElements('firstname').single.innerText);
      expect(names, ['Joe']);
      expect(root.findAllElements('lastname').single.innerText, 'Bloggs');
    });

    test('falls back to the legacy text when there is no plain buddy', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeInlineBuddies(
          b,
          _dive.copyWith(buddy: 'Legacy Buddy'),
          [_row(_guide, DiveRole.diveGuideId)],
        ),
      );
      expect(
        root
            .findElements('buddy')
            .single
            .findAllElements('firstname')
            .single
            .innerText,
        'Legacy Buddy',
      );
    });

    test('writes nothing with neither', () {
      final root = _write(
        (b) => UddfParticipantWriters.writeInlineBuddies(b, _dive, const []),
      );
      expect(root.findElements('buddy'), isEmpty);
    });
  });
}
