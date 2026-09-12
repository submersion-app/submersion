import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_buddy_roles.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:xml/xml.dart';

import '../../../../helpers/test_database.dart';

/// Issue #1737: dive guides, divemasters and every other per-dive role
/// must survive a UDDF export and import instead of collapsing into the
/// `<divemaster>` text and a plain buddy link.
final _epoch = DateTime(2024, 1, 1);

Buddy _buddy(String id, String name) =>
    Buddy(id: id, name: name, createdAt: _epoch, updatedAt: _epoch);

DiveRole _role(String id) =>
    DiveRole(id: id, name: id, createdAt: _epoch, updatedAt: _epoch);

String _applicationData(Map<String, List<BuddyWithRole>> diveBuddies) {
  final builder = XmlBuilder();
  builder.element(
    'uddf',
    nest: () {
      UddfExportBuilders.buildApplicationData(
        builder,
        diveBuddies: diveBuddies,
      );
    },
  );
  return builder.buildDocument().toXmlString();
}

/// A document declaring [buddies] (id to full name) and one dive per
/// entry of [dives] (dive id to the XML inside its informationbeforedive),
/// plus an optional private [submersion] block.
String _document({
  Map<String, String> buddies = const {},
  required Map<String, String> dives,
  String submersion = '',
}) {
  final diverSection = buddies.isEmpty
      ? ''
      : '''
  <diver>
${buddies.entries.map((e) {
          final parts = e.value.split(' ');
          final last = parts.length > 1 ? '<lastname>${parts.sublist(1).join(' ')}</lastname>' : '';
          return '    <buddy id="${e.key}"><personal>'
              '<firstname>${parts.first}</firstname>$last'
              '</personal></buddy>';
        }).join('\n')}
  </diver>''';
  final diveSection = dives.entries
      .map(
        (e) =>
            '''
      <dive id="${e.key}">
        <informationbeforedive>
          <datetime>2025-03-19T08:19:54</datetime>
          ${e.value}
        </informationbeforedive>
      </dive>''',
      )
      .join('\n');
  final appData = submersion.isEmpty
      ? ''
      : '''
  <applicationdata>
    <submersion version="1.0">
$submersion
    </submersion>
  </applicationdata>''';
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<uddf version="3.2.0">
$diverSection
  <profiledata>
    <repetitiongroup>
$diveSection
    </repetitiongroup>
  </profiledata>
$appData
</uddf>
''';
}

Future<Map<String, dynamic>> _importSingleDive(String xml) async {
  final result = await UddfFullImportService().importAllDataFromUddf(xml);
  return result.dives.single;
}

void main() {
  group('export: <buddyroles>', () {
    test('writes every non-buddy role per dive, keyed by dive ref', () {
      final xml = _applicationData({
        'd1': [
          BuddyWithRole(
            buddy: _buddy('b1', 'Nicol Sorin'),
            role: _role(DiveRole.diveMasterId),
          ),
          BuddyWithRole(
            buddy: _buddy('b2', 'Joe Bloggs'),
            role: _role(DiveRole.buddyId),
          ),
          BuddyWithRole(
            buddy: _buddy('b3', 'Pat Kim'),
            role: _role('custom-uuid'),
          ),
        ],
      });

      final dive = XmlDocument.parse(
        xml,
      ).findAllElements('buddyroles').single.findElements('dive').single;
      expect(dive.getAttribute('ref'), 'dive_d1');
      final rows = {
        for (final e in dive.findElements('buddy'))
          e.getAttribute('ref'): e.getAttribute('role'),
      };
      expect(rows, {
        'buddy_b1': DiveRole.diveMasterId,
        'buddy_b3': 'custom-uuid',
      });
    });

    test('writes no block when every dive has only plain buddies', () {
      final xml = _applicationData({
        'd1': [
          BuddyWithRole(
            buddy: _buddy('b2', 'Joe Bloggs'),
            role: _role(DiveRole.buddyId),
          ),
        ],
      });

      expect(xml, isNot(contains('buddyroles')));
    });
  });

  group('import', () {
    setUp(() async {
      await setUpTestDatabase();
    });

    tearDown(() async {
      await tearDownTestDatabase();
    });

    group('<divemaster> without a <buddyroles> block', () {
      test('resolves a declared person to a dive guide ref', () async {
        // Submersion's own export also links every participant, leaders
        // included, so the guide arrives as a buddy link as well.
        final dive = await _importSingleDive(
          _document(
            buddies: {'buddy_n': 'Nicol Sorin', 'buddy_j': 'Joe Bloggs'},
            dives: {
              'dive_1':
                  '<link ref="buddy_n"/><link ref="buddy_j"/>'
                  '<divemaster>nicol sorin</divemaster>',
            },
          ),
        );

        expect(dive['diveGuideRefs'], ['buddy_n']);
        expect(dive['buddyRefs'], [
          'buddy_j',
        ], reason: 'the guide holds one role, not a buddy link as well');
        expect(dive.containsKey('unmatchedDiveGuideNames'), isFalse);
        expect(
          dive['diveMaster'],
          isNull,
          reason: 'a name that became a guide link is not also kept as text',
        );
        expect(
          dive.keys.where((k) => k.startsWith('_')),
          isEmpty,
          reason: 'the held <divemaster> text does not reach the importer',
        );
      });

      test('passes an undeclared name on to be found or created', () async {
        final dive = await _importSingleDive(
          _document(
            buddies: {'buddy_n': 'Nicol Sorin'},
            dives: {
              'dive_1': '<divemaster>Nicol Sorin, Walk In Guide</divemaster>',
            },
          ),
        );

        expect(dive['diveGuideRefs'], ['buddy_n']);
        expect(dive['unmatchedDiveGuideNames'], ['Walk In Guide']);
        expect(dive['diveMaster'], isNull);
      });

      test('keeps a declared name that contains a comma whole', () async {
        final dive = await _importSingleDive(
          _document(
            buddies: {'buddy_d': 'Doe, Jane', 'buddy_n': 'Nicol Sorin'},
            dives: {
              'dive_1': '<divemaster>Doe, Jane, Nicol Sorin</divemaster>',
            },
          ),
        );

        expect(dive['diveGuideRefs'], ['buddy_d', 'buddy_n']);
        expect(dive.containsKey('unmatchedDiveGuideNames'), isFalse);
      });
    });

    group('<buddyroles> block', () {
      test(
        'carries exact roles and supersedes the text it came from',
        () async {
          final dive = await _importSingleDive(
            _document(
              buddies: {
                'buddy_n': 'Nicol Sorin',
                'buddy_s': 'Sam Park',
                'buddy_j': 'Joe Bloggs',
              },
              dives: {
                'dive_1':
                    '<link ref="buddy_s"/><link ref="buddy_j"/>'
                    '<divemaster>Nicol Sorin</divemaster>',
              },
              submersion: '''
      <buddyroles>
        <dive ref="dive_1">
          <buddy ref="buddy_n" role="diveMaster"/>
          <buddy ref="buddy_s" role="student"/>
        </dive>
      </buddyroles>''',
            ),
          );

          expect(dive['buddyRoleRefs'], [
            {'buddyRef': 'buddy_n', 'roleId': 'diveMaster'},
            {'buddyRef': 'buddy_s', 'roleId': 'student'},
          ]);
          expect(dive['buddyRefs'], [
            'buddy_j',
          ], reason: 'a person with an exact role is not also linked as buddy');
          expect(
            dive.containsKey('diveGuideRefs'),
            isFalse,
            reason: 'the <divemaster> text was generated from the leader rows',
          );
          expect(dive['diveMaster'], isNull);
        },
      );

      test('a namesake of the leader keeps their buddy link', () async {
        // Text matching picks the first "Chris Diver", but the block says
        // the other one led. The first stays the plain buddy they were.
        final dive = await _importSingleDive(
          _document(
            buddies: {'buddy_a': 'Chris Diver', 'buddy_b': 'Chris Diver'},
            dives: {
              'dive_1':
                  '<link ref="buddy_a"/><link ref="buddy_b"/>'
                  '<divemaster>Chris Diver</divemaster>',
            },
            submersion: '''
      <buddyroles>
        <dive ref="dive_1">
          <buddy ref="buddy_b" role="diveGuide"/>
        </dive>
      </buddyroles>''',
          ),
        );

        expect(dive['buddyRefs'], ['buddy_a']);
        expect(dive['buddyRoleRefs'], [
          {'buddyRef': 'buddy_b', 'roleId': 'diveGuide'},
        ]);
        expect(dive.containsKey('diveGuideRefs'), isFalse);
      });

      test(
        'a leader the block cannot use still comes back as a guide',
        () async {
          // The block covers Nicol, but its row for the second leader names
          // a person the file never declares. That leader's name in the text
          // is then the only record of them, so it must not be dropped along
          // with the names the block does cover.
          final dive = await _importSingleDive(
            _document(
              buddies: {'buddy_n': 'Nicol Sorin'},
              dives: {
                'dive_1':
                    '<link ref="buddy_n"/>'
                    '<divemaster>Nicol Sorin, Ghost Leader</divemaster>',
              },
              submersion: '''
      <buddyroles>
        <dive ref="dive_1">
          <buddy ref="buddy_n" role="diveGuide"/>
          <buddy ref="buddy_ghost" role="diveMaster"/>
        </dive>
      </buddyroles>''',
            ),
          );

          expect(dive['buddyRoleRefs'], [
            {'buddyRef': 'buddy_n', 'roleId': 'diveGuide'},
          ]);
          expect(dive['unmatchedDiveGuideNames'], ['Ghost Leader']);
          expect(dive.containsKey('diveGuideRefs'), isFalse);
          expect(dive.containsKey('buddyRefs'), isFalse);
        },
      );

      test(
        'keeps text-derived guides when the block names no leader',
        () async {
          // A dive with no leader rows exports its legacy free-text
          // divemaster instead, so that text is still the only source.
          final dive = await _importSingleDive(
            _document(
              buddies: {'buddy_s': 'Sam Park'},
              dives: {
                'dive_1':
                    '<link ref="buddy_s"/>'
                    '<divemaster>Old Text Guide</divemaster>',
              },
              submersion: '''
      <buddyroles>
        <dive ref="dive_1">
          <buddy ref="buddy_s" role="student"/>
        </dive>
      </buddyroles>''',
            ),
          );

          expect(dive['unmatchedDiveGuideNames'], ['Old Text Guide']);
          expect(dive['buddyRoleRefs'], [
            {'buddyRef': 'buddy_s', 'roleId': 'student'},
          ]);
        },
      );

      test('accepts a custom role the file declares', () async {
        final dive = await _importSingleDive(
          _document(
            buddies: {'buddy_p': 'Pat Kim'},
            dives: {'dive_1': '<link ref="buddy_p"/>'},
            submersion: '''
      <diveroles>
        <diverole id="custom-uuid">
          <name>Photographer</name>
          <sortorder>10</sortorder>
          <isbuiltin>false</isbuiltin>
        </diverole>
      </diveroles>
      <buddyroles>
        <dive ref="dive_1">
          <buddy ref="buddy_p" role="custom-uuid"/>
        </dive>
      </buddyroles>''',
          ),
        );

        expect(dive['buddyRoleRefs'], [
          {'buddyRef': 'buddy_p', 'roleId': 'custom-uuid'},
        ]);
        expect(dive.containsKey('buddyRefs'), isFalse);
      });

      test('ignores unknown roles and undeclared people', () async {
        final dive = await _importSingleDive(
          _document(
            buddies: {'buddy_p': 'Pat Kim'},
            dives: {'dive_1': '<link ref="buddy_p"/>'},
            submersion: '''
      <buddyroles>
        <dive ref="dive_1">
          <buddy ref="buddy_p" role="no-such-role"/>
          <buddy ref="buddy_ghost" role="diveGuide"/>
        </dive>
      </buddyroles>''',
          ),
        );

        expect(dive.containsKey('buddyRoleRefs'), isFalse);
        expect(dive['buddyRefs'], [
          'buddy_p',
        ], reason: 'an entry that cannot be honoured leaves the standard link');
      });
    });
  });

  group('UddfBuddyRoles.resolveLeaderNames', () {
    final declared = {
      'buddy_a': {'name': 'Chris Diver'},
      'buddy_b': {'name': 'Chris Diver'},
      'buddy_c': {'name': 'Lee, Ann'},
    };

    test('splits on commas and trims blanks', () {
      final r = UddfBuddyRoles.resolveLeaderNames(' X ,, Y ', const {});

      expect(r.refs, isEmpty);
      expect(r.unmatched, ['X', 'Y']);
    });

    test('a repeated name reaches the next declared person of that name', () {
      final r = UddfBuddyRoles.resolveLeaderNames(
        'Chris Diver, Chris Diver',
        declared,
      );

      expect(r.refs, ['buddy_a', 'buddy_b']);
    });

    test('rejoins fragments that together name a declared person', () {
      final r = UddfBuddyRoles.resolveLeaderNames('lee, ann', declared);

      expect(r.refs, ['buddy_c']);
      expect(r.unmatched, isEmpty);
    });

    test('an undeclared name is listed once', () {
      final r = UddfBuddyRoles.resolveLeaderNames('Zed, Zed', declared);

      expect(r.unmatched, ['Zed']);
    });
  });
}
