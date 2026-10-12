import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/passport_usage_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// The dives a tagged cylinder was used on (issue #2650).
void main() {
  late DiveRepository dives;
  final usage = PassportUsageRepository();

  setUp(() async {
    final db = await setUpTestDatabase();
    await seedDivers(db, ['me', 'buddy']);
    dives = DiveRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<void> dive(
    String id,
    DateTime at, {
    String? diverId,
    int? number,
    DiveSite? site,
    bool planned = false,
    List<String?> passports = const ['p-1'],
  }) => dives.createDive(
    Dive(
      id: id,
      isPlanned: planned,
      diverId: diverId,
      diveNumber: number,
      dateTime: at,
      site: site,
      tanks: [
        for (var i = 0; i < passports.length; i++)
          DiveTank(id: '$id-t$i', order: i, passportId: passports[i]),
      ],
    ),
  );

  test('lists the matching dives newest first with site and number', () async {
    final site = await SiteRepository().createSite(
      const DiveSite(id: 's1', name: 'Bari Reef'),
    );
    await dive('old', DateTime.utc(2025, 3, 10), number: 7);
    await dive('new', DateTime.utc(2026, 3, 12), number: 41, site: site);
    await dive('other', DateTime.utc(2026, 4, 1), passports: const ['p-2']);

    final result = await usage.usageFor('p-1', diverId: null);
    expect(result.map((d) => d.diveId), ['new', 'old']);
    expect(result.first.siteName, 'Bari Reef');
    expect(result.first.diveNumber, 41);
    expect(result.first.dateTime, DateTime.utc(2026, 3, 12));
    expect(result.last.siteName, isNull);
  });

  test('a dive with two tanks from one tag counts once', () async {
    await dive('d1', DateTime.utc(2026, 1, 1), passports: const ['p-1', 'p-1']);
    expect(await usage.usageFor('p-1', diverId: null), hasLength(1));
  });

  test('counts only the given diver', () async {
    await dive('mine', DateTime.utc(2026, 1, 1), diverId: 'me');
    await dive('theirs', DateTime.utc(2026, 1, 2), diverId: 'buddy');
    final result = await usage.usageFor('p-1', diverId: 'me');
    expect(result.map((d) => d.diveId), ['mine']);
  });

  test('leaves out the dive being edited', () async {
    await dive('a', DateTime.utc(2026, 1, 1));
    await dive('b', DateTime.utc(2026, 1, 2));
    final result = await usage.usageFor(
      'p-1',
      diverId: null,
      excludeDiveId: 'b',
    );
    expect(result.map((d) => d.diveId), ['a']);
  });

  test('a planned dive has not used the cylinder yet', () async {
    await dive('logged', DateTime.utc(2026, 1, 1));
    await dive('planned', DateTime.utc(2026, 1, 5), planned: true);
    final result = await usage.usageFor('p-1', diverId: null);
    expect(result.map((d) => d.diveId), ['logged']);
  });

  test('a passport never used gives nothing', () async {
    await dive('a', DateTime.utc(2026, 1, 1), passports: const [null]);
    expect(await usage.usageFor('p-1', diverId: null), isEmpty);
  });

  test('a tank change ticks the change stream', () async {
    final ticks = <void>[];
    final sub = usage.watchChanges().listen(ticks.add);
    addTearDown(sub.cancel);
    await dive('a', DateTime.utc(2026, 1, 1));
    await Future<void>.delayed(Duration.zero);
    expect(ticks, isNotEmpty);
  });
}
