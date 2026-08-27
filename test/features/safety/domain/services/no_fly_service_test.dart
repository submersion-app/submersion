import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/services/no_fly_service.dart';

void main() {
  const service = NoFlyService();
  final now = DateTime.utc(2026, 7, 17, 12);

  NoFlyDiveInput dive({required int hoursAgo, bool deco = false}) =>
      NoFlyDiveInput(
        endTime: now.subtract(Duration(hours: hoursAgo)),
        hadDecoObligation: deco,
      );

  test('no dives means no restriction', () {
    expect(
      service.evaluate(dives: const [], preset: NoFlyPreset.standard, now: now),
      isNull,
    );
  });

  test('single no-deco dive: 12 h from dive end (standard)', () {
    final status = service.evaluate(
      dives: [dive(hoursAgo: 2)],
      preset: NoFlyPreset.standard,
      now: now,
    );
    expect(status, isNotNull);
    expect(status!.category, NoFlyCategory.single);
    expect(status.until, now.add(const Duration(hours: 10)));
    expect(status.remaining(now), const Duration(hours: 10));
  });

  test('two dives in the window: repetitive, 18 h (standard)', () {
    final status = service.evaluate(
      dives: [dive(hoursAgo: 2), dive(hoursAgo: 6)],
      preset: NoFlyPreset.standard,
      now: now,
    );
    expect(status!.category, NoFlyCategory.repetitive);
    expect(status.until, now.add(const Duration(hours: 16)));
  });

  test('any deco dive: 24 h (standard)', () {
    final status = service.evaluate(
      dives: [dive(hoursAgo: 2), dive(hoursAgo: 6, deco: true)],
      preset: NoFlyPreset.standard,
      now: now,
    );
    expect(status!.category, NoFlyCategory.deco);
    expect(status.until, now.add(const Duration(hours: 22)));
  });

  test('strict preset raises intervals to 18/24/48', () {
    final single = service.evaluate(
      dives: [dive(hoursAgo: 2)],
      preset: NoFlyPreset.strict,
      now: now,
    );
    expect(single!.until, now.add(const Duration(hours: 16)));

    final deco = service.evaluate(
      dives: [dive(hoursAgo: 2, deco: true)],
      preset: NoFlyPreset.strict,
      now: now,
    );
    expect(deco!.until, now.add(const Duration(hours: 46)));
  });

  test('expired restriction returns null', () {
    expect(
      service.evaluate(
        dives: [dive(hoursAgo: 13)],
        preset: NoFlyPreset.standard,
        now: now,
      ),
      isNull,
    );
  });

  test('dives outside the 48 h lookback are ignored', () {
    expect(
      service.evaluate(
        dives: [dive(hoursAgo: 49, deco: true)],
        preset: NoFlyPreset.standard,
        now: now,
      ),
      isNull,
    );
  });

  test('multi-day diving counts as repetitive even with one dive today', () {
    // One dive yesterday (35 h ago, still in lookback) and one 2 h ago:
    // window has 2 dives -> repetitive.
    final status = service.evaluate(
      dives: [dive(hoursAgo: 2), dive(hoursAgo: 35)],
      preset: NoFlyPreset.standard,
      now: now,
    );
    expect(status!.category, NoFlyCategory.repetitive);
  });

  test('preset enum round-trips db values', () {
    expect(NoFlyPreset.fromDbValue('strict'), NoFlyPreset.strict);
    expect(NoFlyPreset.fromDbValue('nonsense'), NoFlyPreset.standard);
    expect(NoFlyPreset.strict.dbValue, 'strict');
  });

  group('flightWindow', () {
    final flightAt = DateTime.utc(2026, 8, 10, 9); // Mon 09:00 departure

    test('open: standard repetitive deadline is departure - 18h', () {
      final windowNow = DateTime.utc(2026, 8, 9, 10);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.standard,
        prospectiveCategory: NoFlyCategory.repetitive,
        currentNoFlyUntil: null,
        now: windowNow,
      );
      expect(status!.state, FlightWindowState.open);
      expect(status.deadline, DateTime.utc(2026, 8, 9, 15));
      expect(status.remaining(windowNow), const Duration(hours: 5));
    });

    test('closed: past the deadline but before departure', () {
      final windowNow = DateTime.utc(2026, 8, 9, 16);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.standard,
        prospectiveCategory: NoFlyCategory.repetitive,
        currentNoFlyUntil: null,
        now: windowNow,
      );
      expect(status!.state, FlightWindowState.closed);
      expect(status.remaining(windowNow), Duration.zero);
    });

    test('exactly at the deadline counts as closed', () {
      final windowNow = DateTime.utc(2026, 8, 9, 15);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.standard,
        prospectiveCategory: NoFlyCategory.repetitive,
        currentNoFlyUntil: null,
        now: windowNow,
      );
      expect(status!.state, FlightWindowState.closed);
    });

    test('conflict: existing no-fly reaches past departure, beats open', () {
      final windowNow = DateTime.utc(2026, 8, 9, 10);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.standard,
        prospectiveCategory: NoFlyCategory.deco,
        currentNoFlyUntil: DateTime.utc(2026, 8, 10, 12),
        now: windowNow,
      );
      expect(status!.state, FlightWindowState.conflict);
    });

    test('strict deco: deadline is departure - 48h', () {
      final windowNow = DateTime.utc(2026, 8, 8, 8);
      final status = service.flightWindow(
        flightAt: flightAt,
        preset: NoFlyPreset.strict,
        prospectiveCategory: NoFlyCategory.deco,
        currentNoFlyUntil: null,
        now: windowNow,
      );
      expect(status!.deadline, DateTime.utc(2026, 8, 8, 9));
      expect(status.state, FlightWindowState.open);
      expect(status.interval, const Duration(hours: 48));
    });

    test('returns null once the flight has departed', () {
      final windowNow = DateTime.utc(2026, 8, 10, 10);
      expect(
        service.flightWindow(
          flightAt: flightAt,
          preset: NoFlyPreset.standard,
          prospectiveCategory: NoFlyCategory.repetitive,
          currentNoFlyUntil: null,
          now: windowNow,
        ),
        isNull,
      );
    });
  });

  test('intervalFor matches the table evaluate() uses', () {
    expect(
      NoFlyService.intervalFor(NoFlyPreset.standard, NoFlyCategory.single),
      const Duration(hours: 12),
    );
    expect(
      NoFlyService.intervalFor(NoFlyPreset.strict, NoFlyCategory.repetitive),
      const Duration(hours: 24),
    );
  });
}
