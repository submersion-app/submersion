import 'package:flutter_test/flutter_test.dart';

import 'dive_time_to_local_scanner.dart';

/// Unit tests for the scanner behind
/// `dive_time_to_local_single_source_test.dart`, on synthetic source so the
/// accepted and rejected shapes stay pinned as `lib/` moves.
void main() {
  group('flags a conversion of', () {
    for (final receiver in [
      'dive.startTime',
      'startTime',
      'dive.dateTime',
      'row.diveDateTime',
      'd.entryTime!',
      'dive.exitTime',
      '(d.entryTime ?? d.dateTime)',
      'widget.dive.startTime',
      'dives[i].startTime',
    ]) {
      test(receiver, () {
        expect(findDiveTimeToLocalCalls('final t = $receiver.toLocal();'), [
          '1: $receiver.toLocal()',
        ]);
      });
    }

    test('a null-aware conversion', () {
      expect(
        findDiveTimeToLocalCalls('final t = dive?.startTime?.toLocal();'),
        ['1: dive?.startTime?.toLocal()'],
      );
    });

    test('a conversion inside a call, reported on its own line', () {
      const source = '''
String f(DownloadedDive dive) {
  return units.formatTime(
    dive.startTime.toLocal(),
  );
}
''';
      expect(findDiveTimeToLocalCalls(source), ['3: dive.startTime.toLocal()']);
    });
  });

  group('accepts', () {
    test('a dive time formatted as is', () {
      expect(
        findDiveTimeToLocalCalls('units.formatTime(dive.startTime);'),
        isEmpty,
      );
    });

    test('a conversion of a value that is not a dive time', () {
      // Sync, backup and restore timestamps are real instants and must be
      // shown in the device's zone.
      for (final source in [
        'final t = record.timestamp.toLocal();',
        'final t = copy.quarantinedAt.toLocal();',
        'final t = instant.toLocal();',
      ]) {
        expect(findDiveTimeToLocalCalls(source), isEmpty, reason: source);
      }
    });

    test('a conversion spelled out in a comment or a string', () {
      const source = '''
// Never call dive.startTime.toLocal() here.
const hint = 'dive.startTime.toLocal()';
''';
      expect(findDiveTimeToLocalCalls(source), isEmpty);
    });
  });
}
