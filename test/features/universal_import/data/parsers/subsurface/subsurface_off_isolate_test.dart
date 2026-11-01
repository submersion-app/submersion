import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/utils/off_isolate.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/subsurface_xml_parser.dart';

/// Parses on this isolate, for comparing a worker's result against.
Future<R> _inline<R>(FutureOr<R> Function() work) async => work();

/// A trailing comment puts [xml] past the worker threshold and parses to
/// nothing, so a small document can stand in for a large one.
Uint8List _pastThreshold(String xml) => Uint8List.fromList(
  utf8.encode(
    xml.length >= kOffIsolateMinBytes
        ? xml
        : '$xml<!--${'x' * kOffIsolateMinBytes}-->',
  ),
);

/// Every part of a payload, compared one at a time so a failure says which.
void _expectSamePayload(ImportPayload actual, ImportPayload expected) {
  expect(actual.entities, equals(expected.entities));
  expect(actual.warnings, equals(expected.warnings));
  expect(actual.metadata, equals(expected.metadata));
  expect(actual.sourceDivers, equals(expected.sourceDivers));
}

const _oneDive = '''
<divelog program='subsurface' version='3'>
  <dives>
    <dive number='1' date='2024-03-10' time='09:00:00' duration='30:00 min'>
      <divecomputer model='Perdix'>
        <sample time='0:10 min' depth='5.0 m'/>
      </divecomputer>
    </dive>
  </dives>
</divelog>
''';

const _fixtureDir = ['test', 'features', 'universal_import', 'data', 'parsers'];

String _fixture(String name) =>
    File(p.joinAll([..._fixtureDir, 'fixtures', name])).readAsStringSync();

void main() {
  group('a file past the threshold', () {
    test('parses without holding this isolate', () async {
      // A zero-delay timer needs the event loop back. Parsing here would
      // finish before it could fire, however long the parse took.
      var eventLoopRan = false;
      Timer.run(() => eventLoopRan = true);

      await SubsurfaceXmlParser().parse(_pastThreshold(_oneDive));

      expect(eventLoopRan, isTrue);
    });

    for (final name in const [
      'cave-tags.ssrf',
      'legacy-inline-sites.ssrf',
      'profile-events-variety.ssrf',
      'shore-log.ssrf',
    ]) {
      test('matches an inline parse of $name', () async {
        final bytes = _pastThreshold(_fixture(name));

        final worker = await SubsurfaceXmlParser().parse(bytes);
        final inline = await SubsurfaceXmlParser(runner: _inline).parse(bytes);

        expect(worker.entitiesOf(ImportEntityType.dives), isNotEmpty);
        _expectSamePayload(worker, inline);
      });
    }

    test('matches an inline parse of a dive the file left no date', () async {
      // Warnings and their enums are what a parse of real data rarely shows.
      final bytes = _pastThreshold('''
<divelog program='subsurface' version='3'>
  <dives>
    <dive number='1' duration='30:00 min'/>
    <dive number='2' date='2024-03-10' divesiteid='0000dead'>
      <picture offset='+1:00 min'/>
    </dive>
  </dives>
</divelog>
''');

      final worker = await SubsurfaceXmlParser().parse(bytes);
      final inline = await SubsurfaceXmlParser(runner: _inline).parse(bytes);

      expect(
        worker.warnings.map((w) => w.code),
        containsAll([
          ImportWarningCode.divesSkipped,
          ImportWarningCode.photosSkipped,
          ImportWarningCode.sitesUnresolved,
        ]),
      );
      _expectSamePayload(worker, inline);
    });

    test('reports malformed XML the way an inline parse does', () async {
      final bytes = _pastThreshold('<divelog><dives></divelog>');

      final worker = await SubsurfaceXmlParser().parse(bytes);
      final inline = await SubsurfaceXmlParser(runner: _inline).parse(bytes);

      expect(worker.isEmpty, isTrue);
      expect(worker.failureReason, startsWith('Failed to parse XML'));
      _expectSamePayload(worker, inline);
    });

    test('reports a file that is not a divelog', () async {
      final payload = await SubsurfaceXmlParser().parse(
        _pastThreshold('<gpx></gpx>'),
      );

      expect(payload.failureReason, 'Root element is not divelog');
    });

    test('takes a FormatException as the answer, with no rerun', () async {
      // The file is fine, so a rerun on this isolate would succeed.
      final parser = SubsurfaceXmlParser(
        runner: <R>(work) async => throw const FormatException('bad date'),
      );

      await expectLater(
        parser.parse(_pastThreshold(_oneDive)),
        throwsFormatException,
      );
    });

    test('carries a trip date it cannot read across the isolate', () async {
      Object? workerError;
      Future<R> recordingWorker<R>(FutureOr<R> Function() work) async {
        try {
          return await Isolate.run(work);
        } catch (e) {
          workerError = e;
          rethrow;
        }
      }

      final bytes = _pastThreshold('''
<divelog program='subsurface' version='3'>
  <dives><trip date='not-a-date' location='Egypt'/></dives>
</divelog>
''');

      await expectLater(
        SubsurfaceXmlParser(runner: recordingWorker).parse(bytes),
        throwsFormatException,
      );

      // A RemoteError would mean the error could not cross, which would rerun
      // the whole parse on this isolate to reach the same answer.
      expect(workerError, isA<FormatException>());
    });

    for (final (name, error) in <(String, Object)>[
      ('cannot start', IsolateSpawnException('no isolate')),
      ('dies', RemoteError('ended', '')),
    ]) {
      test('falls back to this isolate when a worker $name', () async {
        final payload = await SubsurfaceXmlParser(
          runner: <R>(work) async => throw error,
        ).parse(_pastThreshold(_oneDive));

        expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
      });
    }
  });

  group('a file under the threshold', () {
    Future<R> noWorker<R>(FutureOr<R> Function() work) =>
        throw StateError('a small file does not need a worker');

    test('stays on this isolate', () async {
      final payload = await SubsurfaceXmlParser(
        runner: noWorker,
      ).parse(Uint8List.fromList(utf8.encode(_oneDive)));

      expect(payload.entitiesOf(ImportEntityType.dives), hasLength(1));
    });

    test('still reports an empty file', () async {
      final payload = await SubsurfaceXmlParser(
        runner: noWorker,
      ).parse(Uint8List(0));

      expect(payload.failureReason, 'Empty file');
    });
  });
}
