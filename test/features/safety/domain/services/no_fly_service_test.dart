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
}
