import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/models/source_diver.dart';
import 'package:submersion/features/universal_import/data/services/payload_dive_rewrite.dart';

Map<String, dynamic> _dive(int number, {int samples = 0}) => {
  'diveNumber': number,
  if (samples > 0)
    'profile': [
      for (var i = 0; i < samples; i++) <String, dynamic>{'timestamp': i},
    ],
};

Map<String, dynamic> _renumbered(Map<String, dynamic> dive) => {
  ...dive,
  'diveNumber': (dive['diveNumber'] as int) + 100,
};

ImportPayload _payload(List<Map<String, dynamic>> dives) => ImportPayload(
  entities: {
    ImportEntityType.dives: dives,
    ImportEntityType.tags: const [
      {'name': 'wreck'},
    ],
  },
  warnings: const [
    ImportWarning(severity: ImportWarningSeverity.error, message: 'kept'),
  ],
  metadata: const {'source': 'test'},
  sourceDivers: const [SourceDiver(key: 'd1', name: 'Pat')],
);

void main() {
  group('rewriteDives', () {
    test('rewrites every dive and keeps everything else', () {
      final payload = _payload([_dive(1), _dive(2)]);

      final result = rewriteDives(payload, _renumbered);

      expect(
        result.entitiesOf(ImportEntityType.dives).map((d) => d['diveNumber']),
        [101, 102],
      );
      expect(result.entitiesOf(ImportEntityType.tags), hasLength(1));
      expect(result.warnings, payload.warnings);
      expect(result.metadata, payload.metadata);
      expect(result.sourceDivers, payload.sourceDivers);
    });

    test('never mutates the payload it was given', () {
      final payload = _payload([_dive(1)]);

      rewriteDives(payload, _renumbered);

      expect(
        payload.entitiesOf(ImportEntityType.dives).single['diveNumber'],
        1,
      );
    });

    test('returns a payload with no dives as it is', () {
      const payload = ImportPayload(entities: {});

      expect(identical(rewriteDives(payload, _renumbered), payload), isTrue);
    });
  });

  group('rewriteDivesInSlices', () {
    test('gives the same result as rewriting in one go', () async {
      final payload = _payload([
        for (var i = 0; i < 20; i++) _dive(i, samples: 10),
      ]);

      final sliced = await rewriteDivesInSlices(
        payload,
        _renumbered,
        sliceSamples: 25,
      );

      expect(sliced, equals(rewriteDives(payload, _renumbered)));
    });

    test('hands the event loop back once a slice is used up', () async {
      // A zero-delay timer needs the event loop back. A pass that held it
      // would finish before this could fire.
      var eventLoopRan = false;
      Timer.run(() => eventLoopRan = true);

      await rewriteDivesInSlices(
        _payload([_dive(1, samples: 10), _dive(2, samples: 10)]),
        _renumbered,
        sliceSamples: 10,
      );

      expect(eventLoopRan, isTrue);
    });

    test('counts dives without samples towards a slice', () async {
      var eventLoopRan = false;
      Timer.run(() => eventLoopRan = true);

      await rewriteDivesInSlices(
        _payload([for (var i = 0; i < 10; i++) _dive(i)]),
        _renumbered,
        sliceSamples: 5,
      );

      expect(eventLoopRan, isTrue);
    });

    test('runs a payload within one slice without giving way', () async {
      var eventLoopRan = false;
      Timer.run(() => eventLoopRan = true);

      await rewriteDivesInSlices(
        _payload([_dive(1, samples: 10), _dive(2, samples: 10)]),
        _renumbered,
      );

      expect(eventLoopRan, isFalse);
    });

    test('stops at the next slice once cancelled', () async {
      final token = ImportCancellationToken();
      var rewrites = 0;
      final payload = _payload([for (var i = 0; i < 10; i++) _dive(i)]);

      final result = await rewriteDivesInSlices(
        payload,
        (dive) {
          if (++rewrites == 2) token.cancel();
          return _renumbered(dive);
        },
        sliceSamples: 2,
        cancelToken: token,
      );

      expect(rewrites, 2);
      expect(identical(result, payload), isTrue);
    });

    test('returns a payload with no dives as it is', () async {
      const payload = ImportPayload(entities: {});

      final result = await rewriteDivesInSlices(payload, _renumbered);

      expect(identical(result, payload), isTrue);
    });
  });
}
