import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

/// Issue #3958: stored SAC metrics read a dive's water, which a dive with none
/// of its own takes from its site.
void main() {
  late SiteRepository sites;
  late DiveSite site;
  var sweeps = 0;

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
    site = await sites.createSite(
      const DiveSite(id: '', name: 'Quarry', waterType: WaterType.fresh),
    );
    sweeps = 0;
    DerivedMetricsScheduler.instance.requestListener = (ids, _) {
      if (ids.isEmpty) sweeps++;
    };
    addTearDown(() => DerivedMetricsScheduler.instance.requestListener = null);
  });

  tearDown(tearDownTestDatabase);

  test('editing the water type sweeps for stale metrics', () async {
    await sites.updateSite(site.copyWith(waterType: WaterType.salt));

    expect(sweeps, 1);
  });

  test('editing anything else does not', () async {
    await sites.updateSite(site.copyWith(name: 'Old Quarry'));

    expect(sweeps, 0);
  });
}
