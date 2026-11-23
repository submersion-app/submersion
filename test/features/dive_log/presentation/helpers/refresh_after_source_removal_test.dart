import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/derived_metrics_scheduler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/helpers/refresh_after_source_removal.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';

/// The refresh the dive page's Data Sources menu and the profile editor run
/// after a source leaves a dive (issues #4393, #4972).
void main() {
  late ProviderContainer container;
  late int sourceReads;
  final derivedRequests = <(Set<String>, bool)>[];
  final summaryRequests = <(Set<String>, bool)>[];

  setUp(() {
    sourceReads = 0;
    derivedRequests.clear();
    summaryRequests.clear();
    DerivedMetricsScheduler.instance.requestListener = (ids, force) =>
        derivedRequests.add((ids, force));
    SensorSummaryScheduler.instance.summaryRequestListener = (ids, force) =>
        summaryRequests.add((ids, force));
    container = ProviderContainer(
      overrides: [
        diveDataSourcesProvider('d1').overrideWith((ref) async {
          sourceReads++;
          return const <DiveDataSource>[];
        }),
      ],
    );
  });

  tearDown(() {
    DerivedMetricsScheduler.instance.requestListener = null;
    SensorSummaryScheduler.instance.summaryRequestListener = null;
    container.dispose();
  });

  test('stops showing and overlaying the removed source', () {
    final active = container.listen(activeDiveSourceProvider('d1'), (_, _) {});
    final overlays = container.listen(overlaySourcesProvider('d1'), (_, _) {});
    container.read(activeDiveSourceProvider('d1').notifier).state = 's2';
    container.read(overlaySourcesProvider('d1').notifier).state = {'s2', 's3'};

    refreshAfterSourceRemoval(container, diveId: 'd1', sourceId: 's2');

    expect(active.read(), isNull);
    expect(overlays.read(), {'s3'});
  });

  test('keeps another source the chart was showing', () {
    final active = container.listen(activeDiveSourceProvider('d1'), (_, _) {});
    container.read(activeDiveSourceProvider('d1').notifier).state = 's3';

    refreshAfterSourceRemoval(container, diveId: 'd1', sourceId: 's2');

    expect(active.read(), 's3');
  });

  test('forces the dive\'s derived metrics and sensor summary', () {
    refreshAfterSourceRemoval(container, diveId: 'd1', sourceId: 's2');

    for (final requests in [derivedRequests, summaryRequests]) {
      expect(requests, hasLength(1));
      expect(requests.single.$1, {'d1'});
      expect(requests.single.$2, isTrue, reason: 'a forced refresh');
    }
  });

  test('reads the dive\'s sources again', () async {
    final sub = container.listen(diveDataSourcesProvider('d1'), (_, _) {});
    await container.read(diveDataSourcesProvider('d1').future);
    expect(sourceReads, 1);

    refreshAfterSourceRemoval(container, diveId: 'd1', sourceId: 's2');
    await container.read(diveDataSourcesProvider('d1').future);

    expect(sourceReads, 2);
    sub.close();
  });
}
