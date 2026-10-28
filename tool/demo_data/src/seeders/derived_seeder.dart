import 'package:submersion/features/data_quality/data/services/quality_scan_service.dart';
import 'package:submersion/features/dive_log/data/repositories/derived_metrics_repository.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_findings_pass.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';

import 'seed_context.dart';

/// What the app computes from the logbook: per-dive sensor summaries and
/// derived metrics, gear condition findings and the data quality scan, run
/// through the app's own services so they match what it would compute.
class DerivedSeeder implements DemoSeeder {
  @override
  String get name => 'derived data';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final sensors = DiveSensorSummaryRepository();
    final metrics = DerivedMetricsRepository();
    for (final d in ctx.plan.dives) {
      final id = ctx.diveId(d.number);
      await sensors.ensureCurrent(id, force: true);
      await metrics.ensureCurrent(id, force: true);
    }
    final items = await EquipmentRepository().getAllEquipment(
      diverId: DemoSeedContext.diverId,
    );
    await EquipmentFindingsPass().run(
      items: items,
      thresholds: ExposureThresholds.defaults,
    );
    await QualityScanService().scanLibrary(now: ctx.anchor);
  }
}
