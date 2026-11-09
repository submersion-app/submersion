import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/weather/data/services/bulk_conditions_service.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/presentation/widgets/fetch_conditions_flow.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

import '../../../../helpers/test_database.dart';

String _payload() {
  final times = [
    for (var h = 0; h < 24; h++)
      '2024-06-15T${h.toString().padLeft(2, '0')}:00',
  ];
  return jsonEncode({
    'hourly': {
      'time': times,
      'temperature_2m': [for (var _ in times) 27.0],
      'relative_humidity_2m': [for (var _ in times) 70.0],
      'precipitation': [for (var _ in times) 0.0],
      'cloud_cover': [for (var _ in times) 10.0],
      'wind_speed_10m': [for (var _ in times) 18.0],
      'wind_direction_10m': [for (var _ in times) 90.0],
      'surface_pressure': [for (var _ in times) 1013.0],
      'weathercode': [for (var _ in times) 0],
    },
  });
}

/// Fails the initial count, to exercise the flow's error path.
class _CountFailsService extends BulkConditionsService {
  _CountFailsService({
    required super.diveRepository,
    required super.weatherService,
  });

  @override
  Future<int> countCandidates({String? diverId, Set<String>? diveIds}) async =>
      throw StateError('count exploded');
}

/// Counts fine, then fails the run itself.
class _RunFailsService extends BulkConditionsService {
  _RunFailsService({
    required super.diveRepository,
    required super.weatherService,
  });

  @override
  Future<int> countCandidates({String? diverId, Set<String>? diveIds}) async =>
      1;

  @override
  Future<BulkConditionsResult> run({
    String? diverId,
    Set<String>? diveIds,
    void Function(BulkConditionsProgress)? onProgress,
    bool Function()? isCancelled,
  }) async => throw StateError('run exploded');
}

void main() {
  late AppDatabase db;
  late DiveRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertSite(String id, double lat, double lon) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: id,
            name: 'Site $id',
            createdAt: now,
            updatedAt: now,
            latitude: Value(lat),
            longitude: Value(lon),
          ),
        );
  }

  Future<void> insertDive(String id, String siteId, DateTime at) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: at.millisecondsSinceEpoch,
            createdAt: now,
            updatedAt: now,
            siteId: Value(siteId),
          ),
        );
  }

  /// A dive with no site and no GPS fix: nowhere to fetch conditions for.
  Future<void> insertSitelessDive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  /// A page whose only button starts the flow against [service], scoped to
  /// [diveIds] when given; [onOutcome] receives what the flow reports.
  /// The locale is pinned so assertions read the English strings.
  Widget hostFor(
    BulkConditionsService service, {
    Set<String>? diveIds,
    void Function(BulkActionOutcome)? onOutcome,
  }) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(
      body: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final outcome = await showFetchConditionsFlow(
              context: context,
              service: service,
              diveIds: diveIds,
            );
            onOutcome?.call(outcome);
          },
          child: const Text('go'),
        ),
      ),
    ),
  );

  ({Widget widget, List<Uri> requests}) harness({
    Set<String>? diveIds,
    void Function(BulkActionOutcome)? onOutcome,
  }) {
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      return http.Response(_payload(), 200);
    });
    final service = BulkConditionsService(
      diveRepository: repository,
      weatherService: WeatherService(client: client),
      requestDelay: Duration.zero,
    );
    return (
      widget: hostFor(service, diveIds: diveIds, onOutcome: onOutcome),
      requests: requests,
    );
  }

  group('FetchConditionsProgressController', () {
    test('adopts the total the run reports, not the pre-count', () {
      // The confirm dialog's count and the run's own candidate query are two
      // separate reads. If anything changed in between, the run's total is the
      // truthful one, otherwise the bar never reaches the end.
      final controller = FetchConditionsProgressController(total: 5);

      controller.report(const BulkConditionsProgress(completed: 2, total: 2));

      expect(controller.completed, 2);
      expect(controller.total, 2);
    });

    test('ignores a report that arrives after disposal', () {
      final controller = FetchConditionsProgressController(total: 3)..dispose();

      controller.report(const BulkConditionsProgress(completed: 1, total: 3));

      expect(controller.completed, 0);
    });
  });

  testWidgets('confirm dialog names how many dives are missing conditions', (
    tester,
  ) async {
    await insertSite('s1', 12.5, -68.25);
    await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));
    await insertDive('d2', 's1', DateTime.utc(2024, 6, 16, 9));

    final (:widget, :requests) = harness();
    await tester.pumpWidget(widget);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Fetch conditions?'), findsOneWidget);
    expect(
      find.textContaining('2 dives are missing conditions'),
      findsOneWidget,
    );
    expect(requests, isEmpty);
  });

  testWidgets('cancelling the confirm dialog fetches nothing', (tester) async {
    await insertSite('s1', 12.5, -68.25);
    await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));

    final (:widget, :requests) = harness();
    await tester.pumpWidget(widget);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(requests, isEmpty);
    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    expect(row.humidity, isNull);
  });

  testWidgets('confirming fills the dives and reports what it did', (
    tester,
  ) async {
    await insertSite('s1', 12.5, -68.25);
    await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));

    final (:widget, :requests) = harness();
    await tester.pumpWidget(widget);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();

    expect(find.text('Conditions fetched'), findsOneWidget);
    expect(find.textContaining('1 dive updated'), findsOneWidget);

    final row = await (db.select(
      db.dives,
    )..where((t) => t.id.equals('d1'))).getSingle();
    expect(row.humidity, 70.0);
  });

  testWidgets('says so when no dive is missing conditions', (tester) async {
    final (:widget, :requests) = harness();
    await tester.pumpWidget(widget);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Fetch conditions?'), findsNothing);
    expect(find.text('No dives are missing conditions.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets('progress dialog shows the count and Cancel stops the run', (
    tester,
  ) async {
    await insertSite('s1', 12.5, -68.25);
    for (var i = 0; i < 3; i++) {
      await insertDive('d$i', 's1', DateTime.utc(2024, 6, 15 + i, 9));
    }

    // Hold each response open so the run can be inspected mid-flight; without
    // a gate it finishes before the first pump and the dialog never renders.
    final gates = <Completer<void>>[];
    final requests = <Uri>[];
    final client = MockClient((request) async {
      requests.add(request.url);
      final gate = Completer<void>();
      gates.add(gate);
      await gate.future;
      return http.Response(_payload(), 200);
    });
    final service = BulkConditionsService(
      diveRepository: repository,
      weatherService: WeatherService(client: client),
      requestDelay: Duration.zero,
    );

    await tester.pumpWidget(hostFor(service));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fetch'));
    // Settle so the confirm dialog has finished leaving; the run itself stays
    // parked on the gate, so nothing advances past the first request.
    await tester.pumpAndSettle();

    expect(find.text('Fetching conditions'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('0 of 3'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    // The first dive is already in flight and still completes; the loop then
    // sees the cancellation and never asks for the second day.
    gates.first.complete();
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(find.text('Conditions fetched'), findsOneWidget);
    expect(find.textContaining('1 dive updated'), findsOneWidget);
    expect(find.textContaining('Stopped early'), findsOneWidget);
  });

  testWidgets('summary reports dives the archive had no data for', (
    tester,
  ) async {
    await insertSite('s1', 12.5, -68.25);
    await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));

    final client = MockClient((_) async => http.Response('{}', 500));
    final service = BulkConditionsService(
      diveRepository: repository,
      weatherService: WeatherService(client: client),
      requestDelay: Duration.zero,
    );

    await tester.pumpWidget(hostFor(service));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 dive had no data available'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Conditions fetched'), findsNothing);
  });

  testWidgets('summary reports a dive whose one gap had no value', (
    tester,
  ) async {
    await insertSite('s1', 12.5, -68.25);
    // Everything but airTemp is already recorded, and the payload has no
    // temperature, so the fetch succeeds and fills nothing.
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: 'd1',
            diveDateTime: DateTime.utc(2024, 6, 15, 10).millisecondsSinceEpoch,
            createdAt: now,
            updatedAt: now,
            siteId: const Value('s1'),
            windSpeed: const Value(4.0),
            windDirection: const Value('north'),
            cloudCover: const Value('clear'),
            precipitation: const Value('none'),
            humidity: const Value(70.0),
            weatherCode: const Value(0),
            surfacePressure: const Value(1.013),
          ),
        );

    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'hourly': {
            'time': ['2024-06-15T10:00'],
            'temperature_2m': [null],
            'relative_humidity_2m': [70.0],
            'precipitation': [0.0],
            'cloud_cover': [10.0],
            'wind_speed_10m': [18.0],
            'wind_direction_10m': [90.0],
            'surface_pressure': [1013.0],
            'weathercode': [0],
          },
        }),
        200,
      ),
    );
    final service = BulkConditionsService(
      diveRepository: repository,
      weatherService: WeatherService(client: client),
      requestDelay: Duration.zero,
    );

    await tester.pumpWidget(hostFor(service));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 dive had nothing to fill'), findsOneWidget);
  });

  testWidgets('a failing count is reported instead of opening the dialog', (
    tester,
  ) async {
    final service = _CountFailsService(
      diveRepository: repository,
      weatherService: WeatherService(
        client: MockClient((_) async {
          return http.Response(_payload(), 200);
        }),
      ),
    );

    await tester.pumpWidget(hostFor(service));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Fetch conditions?'), findsNothing);
    expect(find.textContaining('count exploded'), findsOneWidget);
  });

  testWidgets('a failing run is reported instead of a summary', (tester) async {
    final service = _RunFailsService(
      diveRepository: repository,
      weatherService: WeatherService(
        client: MockClient((_) async {
          return http.Response(_payload(), 200);
        }),
      ),
    );

    await tester.pumpWidget(hostFor(service));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fetch'));
    await tester.pumpAndSettle();

    expect(find.text('Conditions fetched'), findsNothing);
    expect(find.textContaining('run exploded'), findsOneWidget);
  });
  testWidgets('the logbook-wide flow never words itself as a selection', (
    tester,
  ) async {
    await insertSite('s1', 12.5, -68.25);
    await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));
    await insertSitelessDive('nowhere');

    final (:widget, :requests) = harness();
    await tester.pumpWidget(widget);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1 dive is missing conditions.'),
      findsOneWidget,
    );
    expect(find.textContaining('selected dives'), findsNothing);
    expect(find.textContaining('will be skipped'), findsNothing);
  });

  group('scoped to selected dives (#4329)', () {
    testWidgets('confirm names the share of the selection and the skipped', (
      tester,
    ) async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));
      await insertDive('d2', 's1', DateTime.utc(2024, 6, 16, 9));
      await insertDive('other', 's1', DateTime.utc(2024, 6, 17, 9));
      await insertSitelessDive('nowhere');

      final (:widget, :requests) = harness(diveIds: {'d1', 'd2', 'nowhere'});
      await tester.pumpWidget(widget);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 of 3 selected dives are missing conditions.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '1 dive has no site location or GPS fix and will be skipped.',
        ),
        findsOneWidget,
      );
      expect(requests, isEmpty);
    });

    testWidgets('planned dives in a selection are left out of its count', (
      tester,
    ) async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));
      await insertDive('d2', 's1', DateTime.utc(2024, 6, 16, 9));
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: 'planned',
              diveDateTime: now,
              createdAt: now,
              updatedAt: now,
              siteId: const Value('s1'),
              isPlanned: const Value(true),
            ),
          );

      final (:widget, :requests) = harness(diveIds: {'d1', 'd2', 'planned'});
      await tester.pumpWidget(widget);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 dives are missing conditions.'),
        findsOneWidget,
      );
      expect(find.textContaining('of 3 selected'), findsNothing);
    });

    testWidgets('uses the plain count when every selected dive qualifies', (
      tester,
    ) async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));
      await insertDive('d2', 's1', DateTime.utc(2024, 6, 16, 9));

      final (:widget, :requests) = harness(diveIds: {'d1', 'd2'});
      await tester.pumpWidget(widget);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('2 dives are missing conditions.'),
        findsOneWidget,
      );
      expect(find.textContaining('selected dives'), findsNothing);
      expect(find.textContaining('will be skipped'), findsNothing);
    });

    testWidgets('fills only the selected dives and reports completed', (
      tester,
    ) async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));
      await insertDive('other', 's1', DateTime.utc(2024, 6, 15, 9));
      BulkActionOutcome? outcome;

      final (:widget, :requests) = harness(
        diveIds: {'d1'},
        onOutcome: (o) => outcome = o,
      );
      await tester.pumpWidget(widget);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fetch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(outcome, BulkActionOutcome.completed);
      Future<Dive> row(String id) =>
          (db.select(db.dives)..where((t) => t.id.equals(id))).getSingle();
      expect((await row('d1')).humidity, 70.0);
      expect((await row('other')).humidity, isNull);
    });

    testWidgets('says none of the selection is missing conditions', (
      tester,
    ) async {
      await insertSite('s1', 12.5, -68.25);
      BulkActionOutcome? outcome;

      final (:widget, :requests) = harness(
        diveIds: {'missing-id'},
        onOutcome: (o) => outcome = o,
      );
      await tester.pumpWidget(widget);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Fetch conditions?'), findsNothing);
      expect(
        find.text('None of the selected dives are missing conditions.'),
        findsOneWidget,
      );
      expect(outcome, BulkActionOutcome.cancelled);
    });

    testWidgets('says the selection has nowhere to fetch for', (tester) async {
      await insertSitelessDive('nowhere');
      BulkActionOutcome? outcome;

      final (:widget, :requests) = harness(
        diveIds: {'nowhere'},
        onOutcome: (o) => outcome = o,
      );
      await tester.pumpWidget(widget);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Fetch conditions?'), findsNothing);
      expect(
        find.text(
          'The selected dives that are missing conditions have no site '
          'location or GPS fix.',
        ),
        findsOneWidget,
      );
      expect(outcome, BulkActionOutcome.cancelled);
      expect(requests, isEmpty);
    });

    testWidgets('backing out of the confirm reports cancelled', (tester) async {
      await insertSite('s1', 12.5, -68.25);
      await insertDive('d1', 's1', DateTime.utc(2024, 6, 15, 9));
      BulkActionOutcome? outcome;

      final (:widget, :requests) = harness(
        diveIds: {'d1'},
        onOutcome: (o) => outcome = o,
      );
      await tester.pumpWidget(widget);
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(outcome, BulkActionOutcome.cancelled);
    });

    testWidgets('a failing count or run reports failed', (tester) async {
      final weather = WeatherService(
        client: MockClient((_) async => http.Response(_payload(), 200)),
      );
      final outcomes = <BulkActionOutcome>[];

      await tester.pumpWidget(
        hostFor(
          _CountFailsService(
            diveRepository: repository,
            weatherService: weather,
          ),
          diveIds: {'d1'},
          onOutcome: outcomes.add,
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(
        hostFor(
          _RunFailsService(diveRepository: repository, weatherService: weather),
          diveIds: {'d1'},
          onOutcome: outcomes.add,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fetch'));
      await tester.pumpAndSettle();

      expect(outcomes, [BulkActionOutcome.failed, BulkActionOutcome.failed]);
    });
  });
}
