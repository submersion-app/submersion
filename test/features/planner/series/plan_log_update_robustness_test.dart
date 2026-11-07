import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/series_follow.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_state.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_update.dart';
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';
import 'series_fixtures.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Fails the [failOn]th entry the log adds: a write that breaks part way.
class _FailingLog extends PaginatedDiveListNotifier {
  _FailingLog(super.repository, super.ref, this.failOn);

  final int failOn;
  var _calls = 0;

  @override
  Future<Dive> addDive(Dive dive) {
    if (++_calls == failOn) throw StateError('disk full');
    return super.addDive(dive);
  }
}

/// Counts the plan rows read, as the log state reads them.
class _CountingPlanRepository extends DivePlanRepository {
  var reads = 0;

  @override
  Future<domain.DivePlan?> getPlan(String id) {
    reads++;
    return super.getPlan(id);
  }
}

/// "Create / Update planned dives" against edits, failures and other divers
/// (issue #3565, phase 2b review).
void main() {
  late ProviderContainer c;
  final nine = DateTime.utc(2026, 10, 27, 9);

  Future<void> setUpContainer({List<dynamic> overrides = const []}) async {
    final prefs = await SharedPreferences.getInstance();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        ...overrides,
      ],
    );
    addTearDown(c.dispose);
    c
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 18, bottomTimeMinutes: 20);
    c.read(planSeriesNotifierProvider);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
  });

  tearDown(tearDownTestDatabase);

  PlanSeriesNotifier series() => c.read(planSeriesNotifierProvider.notifier);

  String? linkOf(int index) =>
      c.read(planSeriesNotifierProvider).dives[index].state.linkedDiveId;

  Future<Dive?> entry(String? id) =>
      c.read(diveRepositoryProvider).getDiveById(id!);

  /// Dives A, B and C, starting at nine.
  void threeDives() {
    series().setSelectedStart(nine);
    for (var i = 0; i < 2; i++) {
      series().addDive();
      series().fillAllTanks();
    }
  }

  Future<PlannedDivesLogState> logState() async {
    final sub = c.listen(plannedDivesLogStateProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    return c.read(plannedDivesLogStateProvider.future);
  }

  group('a single plan with no start', () {
    setUp(setUpContainer);

    test('keeps its entry at the time it was made', () async {
      final made = DateTime(2026, 10, 27, 8);
      final first = await withClock(
        Clock.fixed(made),
        () => updatePlannedDives(c),
      );
      final at = (await entry(first.selectedDiveId))!.dateTime;

      final bottom = c.read(divePlanNotifierProvider).segments.last;
      c
          .read(divePlanNotifierProvider.notifier)
          .updateSegment(
            bottom.id,
            bottom.copyWith(durationSeconds: bottom.durationSeconds + 60),
          );
      await withClock(
        Clock.fixed(made.add(const Duration(hours: 5))),
        () => updatePlannedDives(c),
      );

      expect((await entry(first.selectedDiveId))!.dateTime, at);
    });

    test('is up to date once updated', () async {
      await updatePlannedDives(c);

      expect((await logState()).outOfDate, isFalse);
    });
  });

  group('a dive removed while the log is read', () {
    setUp(setUpContainer);

    test('leaves the other entries with their own dives', () async {
      threeDives();
      await updatePlannedDives(c);
      final b = linkOf(1)!;
      final cEntry = linkOf(2)!;
      final bAt = (await entry(b))!.dateTime;

      final running = updatePlannedDives(c);
      // The lookups are under way; B goes before they finish.
      series().removeDive(1);
      final result = await running;

      expect(result.updated, 2);
      expect((await entry(b))!.dateTime, bAt);
      expect(linkOf(1), cEntry);
      expect(
        (await entry(cEntry))!.dateTime,
        c.read(planSeriesResultsProvider)[1].state.startDateTime,
      );
      expect(result.orphans.map((d) => d.id), [b]);
    });
  });

  group('a write that fails part way', () {
    setUp(
      () => setUpContainer(
        overrides: [
          paginatedDiveListProvider.overrideWith(
            (ref) => _FailingLog(ref.watch(diveRepositoryProvider), ref, 2),
          ),
        ],
      ),
    );

    test('still links the entries it made, so none is made twice', () async {
      threeDives();

      await expectLater(updatePlannedDives(c), throwsStateError);
      final made = linkOf(0);
      expect(made, isNotNull);
      final stored = await c
          .read(divePlanRepositoryProvider)
          .getPlan(c.read(planSeriesNotifierProvider).dives[0].state.id);
      expect(stored?.linkedDiveId, made);

      await updatePlannedDives(c);

      expect(linkOf(0), made);
      expect(await c.read(diveRepositoryProvider).getAllDives(), hasLength(3));
    });
  });

  group('an update', () {
    setUp(setUpContainer);

    test('rewrites the profile in place, with no revision each time', () async {
      final id = (await updatePlannedDives(c)).selectedDiveId!;
      final editor = c.read(divePlanNotifierProvider.notifier);
      for (var i = 1; i <= 3; i++) {
        final bottom = c.read(divePlanNotifierProvider).segments.last;
        editor.updateSegment(
          bottom.id,
          bottom.copyWith(durationSeconds: bottom.durationSeconds + 60),
        );
        await updatePlannedDives(c);
      }

      final db = DatabaseService.instance.database;
      final rows = await (db.select(
        db.diveProfileSeries,
      )..where((t) => t.diveId.equals(id))).get();
      expect(rows, hasLength(1));
      expect(rows.single.isPrimary, isTrue);
      final profile = await c.read(diveRepositoryProvider).getDiveProfile(id);
      expect(profile.last.timestamp, greaterThan(23 * 60));
    });

    test('names a dive with no segments as the reason', () async {
      series().addDive();
      series().fillAllTanks();
      final editor = c.read(divePlanNotifierProvider.notifier);
      for (final segment in c.read(divePlanNotifierProvider).segments) {
        editor.removeSegment(segment.id);
      }

      final result = await updatePlannedDives(c);

      expect(result.valid, isFalse);
      expect(result.blockedBy, 'B');
      expect(result.blockedEmpty, isTrue);
    });

    test('of a single plan with no segments says so too', () async {
      c.read(divePlanNotifierProvider.notifier).newPlan();

      final result = await updatePlannedDives(c);

      expect(result.blockedEmpty, isTrue);
      expect(result.blockedBy, isNull);
    });

    test('a critical warning is not an empty dive', () async {
      c
          .read(divePlanNotifierProvider.notifier)
          .addSimplePlan(maxDepth: 120, bottomTimeMinutes: 60);

      final result = await updatePlannedDives(c);

      expect(result.valid, isFalse);
      expect(result.blockedEmpty, isFalse);
    });
  });

  group('a removed dive', () {
    setUp(setUpContainer);

    test('is offered when every dive left has been dived', () async {
      threeDives();
      await updatePlannedDives(c);
      final removed = linkOf(2)!;
      final repository = c.read(diveRepositoryProvider);
      await repository.convertPlanToActualDive(linkOf(0)!);
      await repository.convertPlanToActualDive(linkOf(1)!);
      series().removeDive(2);

      final result = await updatePlannedDives(c);

      expect(result.created + result.updated, 0);
      expect(result.orphans.map((d) => d.id), [removed]);
    });

    test('once offered, the log is up to date again', () async {
      threeDives();
      await updatePlannedDives(c);
      series().removeDive(2);
      expect((await logState()).outOfDate, isTrue);

      await updatePlannedDives(c);
      // Saved without it, its entry still waits for the offer.
      expect((await logState()).outOfDate, isTrue);
      series().clearRemovedLinkedDives();

      expect((await logState()).outOfDate, isFalse);
    });

    test('is forgotten when another series opens after an unsaved one', () {
      threeDives();
      series().adoptLinks({
        c.read(planSeriesNotifierProvider).dives[1].state.id: 'entry-b',
      });
      series().removeDive(1);
      expect(series().removedLinkedDiveIds, {'entry-b'});

      series().loadSeries(
        c.read(planSeriesNotifierProvider).copyWith(id: 'another-series'),
      );

      expect(series().removedLinkedDiveIds, isEmpty);
      expect(c.read(removedLinkedDiveIdsProvider), isEmpty);
    });
  });

  group('the log state', () {
    late _CountingPlanRepository plans;

    setUp(() async {
      plans = _CountingPlanRepository();
      await setUpContainer(
        overrides: [divePlanRepositoryProvider.overrideWithValue(plans)],
      );
    });

    test('compares an edit without reading the log again', () async {
      threeDives();
      await updatePlannedDives(c);
      expect((await logState()).outOfDate, isFalse);
      final before = plans.reads;

      final bottom = c.read(divePlanNotifierProvider).segments.last;
      c
          .read(divePlanNotifierProvider.notifier)
          .updateSegment(
            bottom.id,
            bottom.copyWith(durationSeconds: bottom.durationSeconds + 60),
          );

      expect((await logState()).outOfDate, isTrue);
      expect(plans.reads, before);
    });
  });

  group('needs a first start', () {
    setUp(setUpContainer);

    test('not for a series begun by a dived dive', () async {
      threeDives();
      await updatePlannedDives(c);
      final a = c.read(planSeriesNotifierProvider).dives[0];
      // A's plan has no start of its own; it was dived at nine.
      series().select(0);
      series().setSelectedStart(null);
      series().setActuals({
        a.state.id: SeriesFollow(
          loggedDives: [
            seriesLoggedDive('logged-a', nine.add(const Duration(minutes: 45))),
          ],
        ),
      });
      series().select(2);

      expect(
        seriesNeedsFirstStart(
          c.read(planSeriesNotifierProvider),
          c.read(planSeriesResultsProvider),
        ),
        isFalse,
      );
    });

    test('for a series with no start at all', () {
      series().addDive();
      series().fillAllTanks();

      expect(
        seriesNeedsFirstStart(
          c.read(planSeriesNotifierProvider),
          c.read(planSeriesResultsProvider),
        ),
        isTrue,
      );
    });
  });

  group('another diver updating the series', () {
    late String a;
    late String b;

    Future<String> diver(String id) async {
      final now = DateTime.now();
      final created = await DiverRepository().createDiver(
        Diver(id: id, name: id, createdAt: now, updatedAt: now),
      );
      return created.id;
    }

    Future<String> site(String ownerId) async =>
        (await SiteRepository().createSite(
          DiveSite(id: '', name: 'Blue Hole', diverId: ownerId),
        )).id;

    setUp(() async {
      await setUpContainer();
      a = await diver('diver-a');
      b = await diver('diver-b');
    });

    test("keeps the site the entry's own diver can see", () async {
      final own = await site(a);
      await c.read(currentDiverIdProvider.notifier).setCurrentDiver(a);
      c.read(divePlanNotifierProvider.notifier).updateSite(own);
      final id = (await updatePlannedDives(c)).selectedDiveId!;
      expect((await entry(id))?.site?.id, own);

      await c.read(currentDiverIdProvider.notifier).setCurrentDiver(b);
      c.read(divePlanNotifierProvider.notifier).updateName('Changed');
      await updatePlannedDives(c);

      expect((await entry(id))?.diverId, a);
      expect((await entry(id))?.site?.id, own);
    });

    test("never gives the entry a site private to the updater", () async {
      await c.read(currentDiverIdProvider.notifier).setCurrentDiver(a);
      final id = (await updatePlannedDives(c)).selectedDiveId!;

      await c.read(currentDiverIdProvider.notifier).setCurrentDiver(b);
      c.read(divePlanNotifierProvider.notifier).updateSite(await site(b));
      await updatePlannedDives(c);

      expect((await entry(id))?.site, isNull);
    });
  });
}
