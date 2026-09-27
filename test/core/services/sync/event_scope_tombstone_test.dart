import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/event_scope_tombstone.dart';
import 'package:submersion/core/services/sync/hlc.dart';

void main() {
  test('encodes and decodes both scopes', () {
    const dive = EventScopeTombstone(diveId: 'd1');
    const computer = EventScopeTombstone(diveId: 'd1', computerId: 'c1');
    expect(dive.encode(), 'd1');
    expect(computer.encode(), 'd1|c1');
    expect(EventScopeTombstone.tryDecode('d1')!.computerId, isNull);
    expect(EventScopeTombstone.tryDecode('d1|c1')!.computerId, 'c1');
  });

  test('rejects malformed ids', () {
    for (final bad in ['', '|c1', 'd1|', 'a|b|c']) {
      expect(EventScopeTombstone.tryDecode(bad), isNull, reason: bad);
    }
  });

  group('eventPredatesScopeDelete', () {
    const h = Hlc(1000, 0, 'a');

    test('compares clocks when both exist', () {
      expect(
        eventPredatesScopeDelete(
          rowHlc: const Hlc(999, 0, 'b'),
          rowCreatedAt: 5000,
          deleteHlc: h,
          deletedAt: 1,
        ),
        isTrue,
      );
      expect(
        eventPredatesScopeDelete(
          rowHlc: h,
          rowCreatedAt: 0,
          deleteHlc: h,
          deletedAt: 0,
        ),
        isTrue,
        reason: 'a tie is covered, as a per-row tombstone covers it',
      );
      expect(
        eventPredatesScopeDelete(
          rowHlc: const Hlc(1001, 0, 'b'),
          rowCreatedAt: 0,
          deleteHlc: h,
          deletedAt: 9999,
        ),
        isFalse,
      );
    });

    test('falls back to createdAt when a clock is missing', () {
      expect(
        eventPredatesScopeDelete(
          rowHlc: null,
          rowCreatedAt: 10,
          deleteHlc: h,
          deletedAt: 10,
        ),
        isTrue,
      );
      expect(
        eventPredatesScopeDelete(
          rowHlc: null,
          rowCreatedAt: 11,
          deleteHlc: h,
          deletedAt: 10,
        ),
        isFalse,
      );
      expect(
        eventPredatesScopeDelete(
          rowHlc: const Hlc(1, 0, 'b'),
          rowCreatedAt: 11,
          deleteHlc: null,
          deletedAt: 10,
        ),
        isFalse,
        reason: 'an old peer tombstone has no clock',
      );
    });
  });

  group('EventScopeCoverage', () {
    const clock = Hlc(1000, 0, 'a');
    final coverage = EventScopeCoverage.from(
      deletedAt: {'d1|c1': 1000, 'd2': 1000, 'garbage|x|y': 5},
      clocks: {'d1|c1': clock},
    );
    Map<String, dynamic> event(
      String dive,
      String? computer, {
      Hlc? hlc,
      int createdAt = 0,
    }) => {
      'id': 'e',
      'diveId': dive,
      'computerId': computer,
      'hlc': hlc?.toString(),
      'createdAt': createdAt,
    };

    test('a computer scope covers only that computer', () {
      const older = Hlc(999, 0, 'b');
      expect(coverage.covers(event('d1', 'c1', hlc: older)), isTrue);
      expect(coverage.covers(event('d1', 'c2', hlc: older)), isFalse);
      expect(coverage.covers(event('d1', null, hlc: older)), isFalse);
    });

    test('a newer row is not covered', () {
      expect(
        coverage.covers(event('d1', 'c1', hlc: const Hlc(1001, 0, 'b'))),
        isFalse,
      );
    });

    test('a dive scope covers every computer by createdAt', () {
      expect(coverage.covers(event('d2', 'c9', createdAt: 999)), isTrue);
      expect(coverage.covers(event('d2', null, createdAt: 1001)), isFalse);
    });

    test('other dives are not covered', () {
      expect(coverage.covers(event('d3', 'c1')), isFalse);
      expect(EventScopeCoverage.from(deletedAt: {}, clocks: {}).isEmpty, true);
    });
  });
}
