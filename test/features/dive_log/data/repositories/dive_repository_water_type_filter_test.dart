import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

/// The water-type filter matches a dive by its effective water type: its own,
/// else its site's, as `Dive.effectiveWaterType` and the insights chart do
/// (issue #3196).
void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    final saltSite = await SiteRepository().createSite(
      const DiveSite(id: '', name: 'Reef', waterType: WaterType.salt),
    );
    final date = DateTime.utc(2026, 6, 8);
    await repository.createDive(
      domain.Dive(id: 'own', dateTime: date, waterType: WaterType.salt),
    );
    await repository.createDive(
      domain.Dive(id: 'fromSite', dateTime: date, site: saltSite),
    );
    await repository.createDive(
      domain.Dive(
        id: 'override',
        dateTime: date,
        site: saltSite,
        waterType: WaterType.fresh,
      ),
    );
    await repository.createDive(domain.Dive(id: 'unknown', dateTime: date));
  });
  tearDown(() async => tearDownTestDatabase());

  Future<Set<String>> matching(List<WaterType> waterTypes) async {
    final results = await repository.getDiveSummaries(
      filter: DiveFilterState(waterTypes: waterTypes),
    );
    return results.map((d) => d.id).toSet();
  }

  test('a dive with no water type matches by its site', () async {
    expect(await matching([WaterType.salt]), {'own', 'fromSite'});
  });

  test('the dive own water type wins over the site one', () async {
    expect(await matching([WaterType.fresh]), {'override'});
  });

  test('the id set the entity views narrow by agrees', () async {
    final ids = await repository.getDiveIdsMatching(
      const DiveFilterState(waterTypes: [WaterType.salt]),
    );
    expect(ids, {'own', 'fromSite'});
  });
}
