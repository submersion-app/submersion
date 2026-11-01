import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/export/models/uddf_import_result.dart';
import 'package:submersion/core/services/export/uddf/uddf_dump_codec.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_import_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/off_isolate.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/uddf_import_parser.dart';

/// Parses on this isolate, for comparing a worker's result against.
Future<R> _inline<R>(FutureOr<R> Function() work) async => work();

/// Parses on a worker and fails the test if the worker did not finish.
///
/// runOffIsolate reruns an unexpected failure on this isolate, so a result that
/// could not cross would otherwise arrive anyway, from the wrong isolate.
Future<UddfImportResult> _parseOnWorker(String xml) async {
  Object? failure;
  final result = await UddfFullImportService(
    runner: <R>(work) async {
      try {
        return await LoggerService.isolateRunKeepingLogs(work);
      } catch (e) {
        failure = e;
        rethrow;
      }
    },
  ).importAllDataFromUddf(xml);
  expect(failure, isNull, reason: 'the worker failed, so this parsed inline');
  return result;
}

/// A trailing comment puts [xml] past the worker threshold and parses to
/// nothing, so a small document can stand in for a large one.
String _pastThreshold(String xml) => xml.length >= kOffIsolateMinBytes
    ? xml
    : '$xml<!--${'x' * kOffIsolateMinBytes}-->';

/// Every list and count a result carries, so one comparison covers them all.
Map<String, Object?> _contents(UddfImportResult result) => {
  'dives': result.dives,
  'sites': result.sites,
  'equipment': result.equipment,
  'buddies': result.buddies,
  'certifications': result.certifications,
  'diveCenters': result.diveCenters,
  'species': result.species,
  'sightings': result.sightings,
  'serviceRecords': result.serviceRecords,
  'settings': result.settings,
  'owner': result.owner,
  'trips': result.trips,
  'tags': result.tags,
  'customDiveTypes': result.customDiveTypes,
  'customDiveRoles': result.customDiveRoles,
  'customSiteTypes': result.customSiteTypes,
  'serviceKinds': result.serviceKinds,
  'diveComputers': result.diveComputers,
  'equipmentSets': result.equipmentSets,
  'courses': result.courses,
  'fills': result.fills,
  'currencyRules': result.currencyRules,
  'currencyPrefs': result.currencyPrefs,
  'currencyEvents': result.currencyEvents,
  'dataSourcesByDiveRef': result.dataSourcesByDiveRef,
  'unpairedDumps': result.unpairedDumps,
  'divesMissingSite': result.divesMissingSite,
};

String _dive(String id) =>
    '''
      <dive id="$id">
        <informationbeforedive>
          <datetime>2019-06-02T10:00:00</datetime>
        </informationbeforedive>
      </dive>''';

String _source(String diveRef, int ordinal, String model) =>
    '''
        <source diveref="$diveRef" ordinal="$ordinal" hasdump="true">
          <descriptor vendor="Shearwater" product="Perdix" model="$model"/>
          <primary>${ordinal == 0}</primary>
          <importedat>2019-06-02T18:41:07.000</importedat>
          <createdat>2019-06-02T18:41:07.000</createdat>
        </source>''';

String _dump(String ref, String payload) =>
    '''
    <divecomputerdump>
      <link ref="$ref"/>
      <datetime>2019-06-02T18:41:07</datetime>
      <dcdump>$payload</dcdump>
    </divecomputerdump>''';

void main() {
  final first = Uint8List.fromList(List<int>.generate(4096, (i) => i % 251));
  final second = Uint8List.fromList(List<int>.generate(2048, (i) => i % 113));
  final third = Uint8List.fromList(List<int>.generate(1024, (i) => i % 7));

  /// One dive per way a dump can go wrong, each with a dump after it that must
  /// not slide into the slot the bad one left.
  String dumpDocument() => _pastThreshold('''
<uddf version="3.2.0" xmlns="http://www.streit.cc/uddf/3.2/">
  <profiledata>
    <repetitiongroup>
${_dive('dive_d1')}
${_dive('dive_d2')}
${_dive('dive_d3')}
    </repetitiongroup>
  </profiledata>
  <applicationdata>
    <submersion version="1.0">
      <datasources>
${_source('dive_d1', 0, '1')}
${_source('dive_d1', 1, '2')}
${_source('dive_d1', 2, '3')}
${_source('dive_d2', 0, '4')}
${_source('dive_d2', 1, '5')}
      </datasources>
    </submersion>
  </applicationdata>
  <divecomputercontrol>
${_dump('dive_d1', UddfDumpCodec.encodeOne(first))}
${_dump('dive_d1', 'bm90IGJ6aXAy')}
${_dump('dive_d1', UddfDumpCodec.encodeOne(second))}
${_dump('dive_d2', '   ')}
${_dump('dive_d2', UddfDumpCodec.encodeOne(third))}
${_dump('dive_d3', UddfDumpCodec.encodeOne(first))}
${_dump('nothing_here', UddfDumpCodec.encodeOne(first))}
  </divecomputercontrol>
</uddf>
''');

  group('a file past the threshold', () {
    test('parses without holding this isolate', () async {
      // A zero-delay timer needs the event loop back. Parsing here would
      // finish before it could fire, however long the parse took.
      var eventLoopRan = false;
      Timer.run(() => eventLoopRan = true);

      await UddfFullImportService().importAllDataFromUddf(dumpDocument());

      expect(eventLoopRan, isTrue);
    });

    test('restores dump bytes under the right descriptors', () async {
      final result = await _parseOnWorker(dumpDocument());

      final d1 = result.dataSourcesByDiveRef['dive_d1']!;
      expect(d1.map((e) => e['descriptorModel']), [1, 2, 3]);
      expect(d1[0]['rawData'], equals(first));
      expect(d1[1]['rawData'], isNull);
      expect(d1[2]['rawData'], equals(second));

      final d2 = result.dataSourcesByDiveRef['dive_d2']!;
      expect(d2.map((e) => e['descriptorModel']), [4, 5]);
      expect(d2[0]['rawData'], isNull);
      expect(d2[1]['rawData'], equals(third));

      final d3 = result.dataSourcesByDiveRef['dive_d3']!;
      expect(d3.single['rawData'], equals(first));
      expect(d3.single['isPrimary'], isTrue);

      // The corrupt dump, the empty dump, and the dump with no dive.
      expect(result.unpairedDumps, 3);
    });

    test('matches an inline parse of the same dumps', () async {
      final xml = dumpDocument();

      final worker = await _parseOnWorker(xml);
      final inline = await UddfFullImportService(
        runner: _inline,
      ).importAllDataFromUddf(xml);

      expect(_contents(worker), equals(_contents(inline)));
    });

    for (final name in [
      p.join('test', 'fixtures', 'uddf', 'round_trip_quick.uddf'),
      p.join('test', 'dives', '006_ccr_petrel3_shearwater-cloud-export.uddf'),
      p.join('test', 'dives', 'issue_279_oceanic_plus_export.uddf'),
    ]) {
      test('matches an inline parse of $name', () async {
        final xml = _pastThreshold(File(name).readAsStringSync());

        final worker = await _parseOnWorker(xml);
        final inline = await UddfFullImportService(
          runner: _inline,
        ).importAllDataFromUddf(xml);

        expect(worker.dives, isNotEmpty);
        expect(_contents(worker), equals(_contents(inline)));
      });
    }

    test('keeps the unreadable dump warning in this isolate\'s log', () async {
      final seen = <String>[];
      final sub = LoggerService.logStream.listen((e) => seen.add(e.message));
      addTearDown(sub.cancel);

      await UddfFullImportService().importAllDataFromUddf(dumpDocument());
      await Future<void>.delayed(Duration.zero);

      expect(seen, contains(startsWith('Skipping unreadable <dcdump>')));
    });

    for (final (name, error) in <(String, Object)>[
      ('cannot start', IsolateSpawnException('no isolate')),
      ('dies', RemoteError('ended', '')),
    ]) {
      test('falls back to this isolate when a worker $name', () async {
        final result = await UddfFullImportService(
          runner: <R>(work) async => throw error,
        ).importAllDataFromUddf(dumpDocument());

        expect(result.dataSourcesByDiveRef['dive_d1'], hasLength(3));
      });
    }
  });

  group('a file that is not valid UDDF', () {
    Object? workerError;

    Future<R> recordingWorker<R>(FutureOr<R> Function() work) async {
      try {
        return await Isolate.run(work);
      } catch (e) {
        workerError = e;
        rethrow;
      }
    }

    setUp(() => workerError = null);

    for (final (name, xml) in [
      ('malformed XML', _pastThreshold('<uddf><dive></uddf>')),
      ('the wrong root element', _pastThreshold('<gpx></gpx>')),
    ]) {
      test('carries $name back across the isolate', () async {
        await expectLater(
          UddfFullImportService(
            runner: recordingWorker,
          ).importAllDataFromUddf(xml),
          throwsFormatException,
        );

        // A RemoteError would mean the error could not cross, which reruns
        // the whole parse on this isolate to reach the same answer.
        expect(workerError, isA<FormatException>());
      });
    }

    test('takes a FormatException from a worker as final', () async {
      // A valid file, so a rerun here would succeed and the test would fail.
      await expectLater(
        UddfFullImportService(
          runner: <R>(work) async => throw const FormatException('the answer'),
        ).importAllDataFromUddf(dumpDocument()),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'the answer',
          ),
        ),
      );
    });

    test('still reaches the wizard as an import warning', () async {
      final payload = await UddfImportParser().parse(
        Uint8List.fromList(utf8.encode(_pastThreshold('<uddf><dive></uddf>'))),
      );

      expect(payload.entities, isEmpty);
      expect(payload.warnings.single.severity, ImportWarningSeverity.error);
    });
  });

  test('a file below the threshold stays on this isolate', () async {
    var workers = 0;
    final result =
        await UddfFullImportService(
          runner: <R>(work) async {
            workers++;
            return work();
          },
        ).importAllDataFromUddf('''
<uddf version="3.2.0" xmlns="http://www.streit.cc/uddf/3.2/">
  <profiledata>
    <repetitiongroup>
${_dive('dive_d1')}
    </repetitiongroup>
  </profiledata>
</uddf>
''');

    expect(workers, 0);
    expect(result.dives, hasLength(1));
  });
}
