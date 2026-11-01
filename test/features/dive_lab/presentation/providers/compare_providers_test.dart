import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/presentation/providers/compare_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_repository_provider.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _plan(String id, {String? linkedDiveId}) => domain.DivePlan(
  id: id,
  name: 'Wreck',
  gfLow: 30,
  gfHigh: 70,
  linkedDiveId: linkedDiveId,
  tanks: const [
    DiveTank(id: 'tank-1', volume: 24, startPressure: 220, gasMix: _air),
  ],
  segments: [
    PlanSegment.travel(
      id: '$id-seg-1',
      fromDepth: 0,
      targetDepth: 30,
      tankId: 'tank-1',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: '$id-seg-2',
      depth: 30,
      durationMinutes: 20,
      tankId: 'tank-1',
      gasMix: _air,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late ProviderContainer container;
  late String diveId;

  setUp(() async {
    await setUpTestDatabase();
    container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      ],
    );
    addTearDown(container.dispose);
    final dive = await container
        .read(diveRepositoryProvider)
        .createDive(Dive(id: '', diveNumber: 1, dateTime: DateTime.utc(2026)));
    diveId = dive.id;
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  Future<void> savePlan({bool linked = true}) => container
      .read(divePlanRepositoryProvider)
      .savePlan(_plan('plan-1', linkedDiveId: linked ? diveId : null));

  test('no link gives no comparison', () async {
    await savePlan(linked: false);

    expect(
      await container.read(linkedPlanComparisonProvider(diveId).future),
      isNull,
    );
    expect(container.read(hasLinkedPlanProvider(diveId)), isFalse);
  });

  test('a link gives the outcome and the overlay', () async {
    await savePlan();

    final comparison = await container.read(
      linkedPlanComparisonProvider(diveId).future,
    );

    expect(comparison!.plan.id, 'plan-1');
    expect(comparison.outcome.maxDepth, 30);
    expect(comparison.overlay.sourceId, 'plan:plan-1');
    expect(comparison.overlay.points, isNotEmpty);
    expect(container.read(hasLinkedPlanProvider(diveId)), isTrue);
  });

  test('the planned column comes from the comparison', () async {
    await savePlan();
    await container.read(linkedPlanComparisonProvider(diveId).future);

    final column = container.read(plannedColumnProvider(diveId));

    expect(column!.kind, CompareLineKind.planned);
    expect(column.maxDepthMeters, 30);
  });

  test('clearing the link empties it live', () async {
    await savePlan();
    final sub = container.listen(
      linkedPlanComparisonProvider(diveId),
      (_, _) {},
    );
    addTearDown(sub.close);
    expect(
      await container.read(linkedPlanComparisonProvider(diveId).future),
      isNotNull,
    );

    await container.read(divePlanRepositoryProvider).unlinkPlan('plan-1');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      await container.read(linkedPlanComparisonProvider(diveId).future),
      isNull,
    );
  });

  test('the chart overlay and the comparison are one run', () async {
    await savePlan();

    final comparison = await container.read(
      linkedPlanComparisonProvider(diveId).future,
    );
    final overlay = await container.read(
      plannedProfileOverlayProvider(diveId).future,
    );

    expect(identical(overlay, comparison!.overlay), isTrue);
  });

  test('the dive column reads the dive itself', () async {
    final dive = await DiveRepository().createDive(
      Dive(
        id: '',
        diveNumber: 2,
        dateTime: DateTime.utc(2026),
        maxDepth: 28,
        runtime: const Duration(minutes: 40),
      ),
    );

    final column = await container.read(divedColumnProvider(dive.id).future);

    expect(column!.kind, CompareLineKind.asDived);
    expect(column.maxDepthMeters, 28);
    expect(column.runtimeSeconds, 2400);
    expect(column.ndl, isNull);
  });

  group('compareLineOn', () {
    test('Planned and As dived start on', () {
      expect(compareLineOn(const {}, 'planned'), isTrue);
      expect(compareLineOn(const {}, 'dived'), isTrue);
    });

    test('only the newest what-if starts on', () {
      expect(
        compareLineOn(const {}, 'sc-new', newestWhatIfId: 'sc-new'),
        isTrue,
      );
      expect(
        compareLineOn(const {}, 'sc-old', newestWhatIfId: 'sc-new'),
        isFalse,
      );
    });

    test('a choice wins over the default', () {
      expect(compareLineOn(const {'planned': false}, 'planned'), isFalse);
      expect(
        compareLineOn(const {'sc-old': true}, 'sc-old', newestWhatIfId: 'x'),
        isTrue,
      );
    });
  });
}
