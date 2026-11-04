// Issue #4181: a dive's runtime and bottom time both survive a UDDF export
// and a restore into a clean database, from either writer.
//
// Both writers put the bottom time in `<diveduration>`, which UDDF and the
// importer read as the total dive time, so a restored dive got its bottom
// time as its runtime and its exit moved earlier to match.
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/export/uddf/uddf_dive_durations.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart'
    as domain;
import 'package:xml/xml.dart';

import '../../../../helpers/fake_hosts.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/uddf_restore.dart';

const _diverId = 'diver-runtime-round-trip';

domain.Dive _dive({Duration? runtime, Duration? bottomTime}) => domain.Dive(
  id: 'dive-runtime-1',
  diveNumber: 1,
  dateTime: DateTime.utc(2026, 5, 4, 9),
  runtime: runtime,
  bottomTime: bottomTime,
  maxDepth: 30.0,
);

Future<void> _createDiver() async {
  final now = DateTime.now();
  await DiverRepository().createDiver(
    domain.Diver(
      id: _diverId,
      name: 'Test Diver',
      isDefault: true,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

void main() {
  setUp(() async {
    serveFakeHost('api.open-meteo.com');
    await setUpTestDatabase();
    await _createDiver();
  });

  tearDown(() async => tearDownTestDatabase());

  Future<domain.Dive> restore(String xml) async {
    await restoreUddfDives(xml, diverId: _diverId);
    final dives = await DiveRepository().getAllDives(diverId: _diverId);
    return dives.single;
  }

  final writers = <String, Future<String> Function(domain.Dive)>{
    'dives export': (dive) =>
        UddfExportService().generateDivesUddfContent([dive]),
    'full backup': (dive) =>
        UddfFullExportService().generateAllDataXmlForTest(dives: [dive]),
  };

  for (final MapEntry(key: name, value: write) in writers.entries) {
    group(name, () {
      test('writes the runtime as the dive duration', () async {
        final xml = await write(
          _dive(
            runtime: const Duration(minutes: 121),
            bottomTime: const Duration(minutes: 48),
          ),
        );
        final after = XmlDocument.parse(
          xml,
        ).findAllElements('informationafterdive').single;

        expect(after.getElement('diveduration')?.innerText, '7260');
        expect(after.getElement('bottomtime')?.innerText, '2880');
        // One home for the runtime: a second element could disagree.
        expect(after.getElement('runtime'), isNull);
      });

      test('restores both the runtime and the bottom time', () async {
        final restored = await restore(
          await write(
            _dive(
              runtime: const Duration(minutes: 121),
              bottomTime: const Duration(minutes: 48),
            ),
          ),
        );

        expect(restored.runtime, const Duration(minutes: 121));
        expect(restored.bottomTime, const Duration(minutes: 48));
        expect(
          restored.exitTime,
          DateTime.utc(2026, 5, 4, 11, 1),
          reason: 'the exit follows the runtime, not the bottom time',
        );
      });

      test('keeps a bottom time equal to the runtime', () async {
        // A square dive, or a value the diver typed: the importer must
        // not mistake it for a runtime echoed into the bottom time.
        final restored = await restore(
          await write(
            _dive(
              runtime: const Duration(minutes: 40),
              bottomTime: const Duration(minutes: 40),
            ),
          ),
        );

        expect(restored.runtime, const Duration(minutes: 40));
        expect(restored.bottomTime, const Duration(minutes: 40));
      });

      test('writes no runtime for a dive with only a bottom time', () async {
        // A table-era log: bottom time is not a runtime (issue #3304).
        final xml = await write(_dive(bottomTime: const Duration(minutes: 35)));
        final after = XmlDocument.parse(
          xml,
        ).findAllElements('informationafterdive').single;
        expect(after.getElement('diveduration'), isNull);

        final restored = await restore(xml);
        expect(restored.runtime, isNull);
        expect(restored.bottomTime, const Duration(minutes: 35));
      });
    });
  }

  group('a full backup written before the fix', () {
    // Those files carry the runtime in <runtime> and the bottom time in
    // <diveduration>. Rewriting a current file back into that shape is the
    // old file, byte for byte in these elements.
    Future<String> oldBackup(domain.Dive dive) async {
      final xml = await UddfFullExportService().generateAllDataXmlForTest(
        dives: [dive],
      );
      final runtime = dive.runtime!.inSeconds;
      final bottom = dive.bottomTime!.inSeconds;
      return xml
          .replaceFirst(
            '<diveduration>$runtime</diveduration>',
            '<diveduration>$bottom</diveduration>\n'
                '<runtime>$runtime</runtime>',
          )
          .replaceFirst('<bottomtime>$bottom</bottomtime>', '');
    }

    test('restores both from the old elements', () async {
      final xml = await oldBackup(
        _dive(
          runtime: const Duration(minutes: 121),
          bottomTime: const Duration(minutes: 48),
        ),
      );
      expect(xml, contains('<runtime>7260</runtime>'));
      expect(xml, isNot(contains('<bottomtime>')));

      final restored = await restore(xml);

      expect(restored.runtime, const Duration(minutes: 121));
      expect(restored.bottomTime, const Duration(minutes: 48));
    });

    test('reads no bottom time from another app\'s duration', () async {
      // Only Submersion ever wrote the bottom time in <diveduration>, so in
      // another app's file it is not one; <runtime> still gives the runtime.
      final xml = (await oldBackup(
        _dive(
          runtime: const Duration(minutes: 121),
          bottomTime: const Duration(minutes: 48),
        ),
      )).replaceFirst(RegExp(r'<name>Submersion</name>'), '<name>Other</name>');

      final restored = await restore(xml);

      expect(restored.runtime, const Duration(minutes: 121));
      expect(restored.bottomTime, isNull);
    });
  });

  group('reading an older file', () {
    ({Duration? runtime, Duration? bottomTime}) read(String after) =>
        UddfDiveDurations.read(
          XmlDocument.parse(
            '<uddf><generator><name>Submersion</name></generator>'
            '<informationafterdive>$after</informationafterdive></uddf>',
          ).findAllElements('informationafterdive').single,
        );

    test('a runtime with no duration is still the runtime', () {
      // A dive with a runtime and no bottom time wrote only <runtime>.
      expect(read('<runtime>2400</runtime>'), (
        runtime: const Duration(minutes: 40),
        bottomTime: null,
      ));
    });

    test('a duration equal to the runtime states no bottom time', () {
      expect(read('<diveduration>2400</diveduration><runtime>2400</runtime>'), (
        runtime: const Duration(minutes: 40),
        bottomTime: null,
      ));
    });
  });
}
