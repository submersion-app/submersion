import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Issue #1796: the dives-only UDDF carries every linked participant and
/// their exact role, trimmed for sharing.
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

DiveRole _builtIn(String id) => DiveRole(
  id: id,
  name: id,
  isBuiltIn: true,
  createdAt: _epoch,
  updatedAt: _epoch,
);

final _photographer = DiveRole(
  id: 'role-photo',
  name: 'Photographer',
  createdAt: _epoch,
  updatedAt: _epoch,
);

final _guide = _buddy('g', 'Nicol Sorin');
final _plain = _buddy('p', 'Joe Bloggs');
final _photo = _buddy('ph', 'Pat Kim');
final _stranger = _buddy('x', 'Not Exported');

final _d1 = Dive(
  id: 'd1',
  dateTime: DateTime(2026, 3, 1, 9),
  diveMaster: 'Legacy Master',
  buddy: 'Legacy Buddy',
);
final _d2 = Dive(
  id: 'd2',
  dateTime: DateTime(2026, 3, 1, 14),
  diveMaster: 'Legacy Master',
  buddy: 'Legacy Buddy',
);

final _extras = UddfDivesExtras(
  diveBuddies: {
    'd1': [
      BuddyWithRole(buddy: _guide, role: _builtIn(DiveRole.diveGuideId)),
      BuddyWithRole(buddy: _plain, role: _builtIn(DiveRole.buddyId)),
      BuddyWithRole(buddy: _photo, role: _photographer),
    ],
    // A dive that is not exported must declare nobody.
    'other': [
      BuddyWithRole(buddy: _stranger, role: _builtIn(DiveRole.buddyId)),
    ],
  },
  diveRoles: [_builtIn(DiveRole.buddyId), _photographer],
);

Future<XmlDocument> _export({
  UddfExportOptions options = const UddfExportOptions(),
}) async => XmlDocument.parse(
  await UddfExportService().generateDivesUddfContent(
    [_d1, _d2],
    extras: _extras,
    options: options,
  ),
);

XmlElement _dive(XmlDocument doc, String diveId) => doc
    .findAllElements('dive')
    .singleWhere((e) => e.getAttribute('id') == 'dive_$diveId');

XmlElement _before(XmlDocument doc, String diveId) =>
    _dive(doc, diveId).findElements('informationbeforedive').single;

XmlElement _after(XmlDocument doc, String diveId) =>
    _dive(doc, diveId).findElements('informationafterdive').single;

void main() {
  test('declares each exported participant once, trimmed', () async {
    final doc = await _export();
    final diver = doc.rootElement.findElements('diver').single;
    final buddies = diver.findElements('buddy').toList();
    expect(buddies.map((e) => e.getAttribute('id')), [
      'buddy_g',
      'buddy_p',
      'buddy_ph',
    ]);
    expect(diver.findAllElements('email'), isEmpty);
    expect(diver.findAllElements('phone'), isEmpty);
    expect(diver.findAllElements('notes'), isEmpty);
    expect(buddies.first.findAllElements('level').single.innerText, 'rescue');
    expect(diver.findElements('owner'), isEmpty);
  });

  test('links every participant and names the leader', () async {
    final doc = await _export();
    final before = _before(doc, 'd1');
    expect(
      before
          .findElements('link')
          .map((e) => e.getAttribute('ref')!)
          .where((r) => r.startsWith('buddy_')),
      ['buddy_g', 'buddy_p', 'buddy_ph'],
    );
    expect(before.findElements('divemaster').single.innerText, 'Nicol Sorin');
  });

  test('writes plain buddies inline, not the legacy text', () async {
    final doc = await _export();
    final names = _after(doc, 'd1')
        .findElements('buddy')
        .map((e) => e.findAllElements('firstname').single.innerText)
        .toList();
    expect(names, ['Joe', 'Pat']);
  });

  test('a dive with no linked people keeps its legacy text', () async {
    final doc = await _export();
    expect(
      _before(doc, 'd2').findElements('divemaster').single.innerText,
      'Legacy Master',
    );
    expect(
      _after(doc, 'd2').findAllElements('firstname').single.innerText,
      'Legacy Buddy',
    );
  });

  test(
    'records exact roles and the custom role in one private block',
    () async {
      final doc = await _export();
      final topLevel = doc.rootElement.childElements
          .where((e) => e.name.local == 'applicationdata')
          .toList();
      expect(topLevel, hasLength(1));
      final submersion = topLevel.single.findElements('submersion').single;
      final rows = submersion
          .findElements('buddyroles')
          .single
          .findElements('dive')
          .single;
      expect(rows.getAttribute('ref'), 'dive_d1');
      expect(
        {
          for (final b in rows.findElements('buddy'))
            b.getAttribute('ref'): b.getAttribute('role'),
        },
        {'buddy_g': DiveRole.diveGuideId, 'buddy_ph': 'role-photo'},
      );
      final roles = submersion.findElements('diveroles').single;
      expect(roles.findElements('diverole').map((e) => e.getAttribute('id')), [
        'role-photo',
      ]);
    },
  );

  test('links a synthetic role but never defines it', () async {
    // A link to an id with no row, or to another diver's role, resolves as
    // DiveRole.synthetic, whose name is only the raw id: declaring it would
    // give the importing diver a role named after a UUID.
    final doc = XmlDocument.parse(
      await UddfExportService().generateDivesUddfContent(
        [_d1],
        extras: UddfDivesExtras(
          diveBuddies: {
            'd1': [
              BuddyWithRole(
                buddy: _photo,
                role: DiveRole.synthetic('role-foreign'),
              ),
            ],
          },
          diveRoles: [_builtIn(DiveRole.buddyId), _photographer],
        ),
      ),
    );

    expect(
      doc
          .findAllElements('buddyroles')
          .single
          .findAllElements('buddy')
          .single
          .getAttribute('role'),
      'role-foreign',
    );
    expect(doc.findAllElements('diveroles'), isEmpty);
  });

  test(
    'leaving participants out writes none of it, legacy text included',
    () async {
      final doc = await _export(
        options: const UddfExportOptions(includeParticipants: false),
      );
      expect(doc.findAllElements('diver'), isEmpty);
      expect(doc.findAllElements('divemaster'), isEmpty);
      expect(doc.findAllElements('buddy'), isEmpty);
      expect(doc.findAllElements('buddyroles'), isEmpty);
      expect(doc.findAllElements('diveroles'), isEmpty);
    },
  );
}
