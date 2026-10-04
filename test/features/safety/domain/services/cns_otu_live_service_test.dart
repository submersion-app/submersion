import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/services/cns_otu_live_service.dart';

void main() {
  final diveEnd = DateTime.utc(2026, 7, 17, 12);

  test('no time elapsed: CNS unchanged', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 40.0,
      lastDiveEnd: diveEnd,
      now: diveEnd,
    );
    expect(result, 40.0);
  });

  test('one half-time (90 minutes) elapsed: CNS halved', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 40.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(minutes: 90)),
    );
    expect(result, closeTo(20.0, 0.001));
  });

  test('two half-times (180 minutes) elapsed: CNS quartered', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 40.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(minutes: 180)),
    );
    expect(result, closeTo(10.0, 0.001));
  });

  test('a day later: decayed to practically zero', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 100.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(hours: 24)),
    );
    expect(result, lessThan(0.01));
  });

  test('zero CNS at dive end stays zero', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 0.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.add(const Duration(hours: 2)),
    );
    expect(result, 0.0);
  });

  test('now before the dive end (clock skew): no decay applied, not negative '
      'elapsed time', () {
    final result = CnsOtuLiveService.currentCns(
      cnsAtDiveEnd: 40.0,
      lastDiveEnd: diveEnd,
      now: diveEnd.subtract(const Duration(minutes: 5)),
    );
    expect(result, 40.0);
  });
}
