import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/repositories/reef_cache_dao.dart';
import 'package:submersion/features/reef/data/repositories/reef_repository.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';

void main() {
  // reefRepositoryProvider reads the local cache database singleton, so it
  // must be primed with an in-memory instance before any provider resolves.
  setUp(() {
    LocalCacheDatabaseService.instance.setTestDatabase(
      LocalCacheDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions)),
    );
  });

  tearDown(() => LocalCacheDatabaseService.instance.resetForTesting());

  test('ReefHealthRequest equality keys the family correctly', () {
    final a = ReefHealthRequest(
      location: const GeoPoint(12.16, -68.28),
      date: DateTime.utc(2019, 3, 15),
    );
    final b = ReefHealthRequest(
      location: const GeoPoint(12.16, -68.28),
      date: DateTime.utc(2019, 3, 15),
    );
    final c = ReefHealthRequest(
      location: const GeoPoint(12.16, -68.28),
      date: DateTime.utc(2019, 3, 16),
    );
    expect(a, b);
    expect(a == c, isFalse);
  });

  test('ReefHealthRequest ignores time of day within the same UTC date', () {
    final morning = ReefHealthRequest(
      location: const GeoPoint(12.16, -68.28),
      date: DateTime.utc(2019, 3, 15, 6),
    );
    final evening = ReefHealthRequest(
      location: const GeoPoint(12.16, -68.28),
      date: DateTime.utc(2019, 3, 15, 21),
    );
    expect(morning, evening);
  });

  test('reefHabitatProvider resolves through the overridden client', () async {
    final container = ProviderContainer(
      overrides: [
        reefHttpClientProvider.overrideWithValue(
          MockClient(
            (_) async => http.Response(jsonEncode({'features': []}), 200),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final part = await container.read(
      reefHabitatProvider(const GeoPoint(12.16, -68.28)).future,
    );
    expect(part.status, ReefDataStatus.empty);
  });

  group('reef part providers', () {
    const location = GeoPoint(12.16, -68.28);

    ProviderContainer containerFor(
      Future<http.Response> Function(http.Request) respond,
    ) {
      final container = ProviderContainer(
        overrides: [
          reefHttpClientProvider.overrideWithValue(MockClient(respond)),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    ProviderContainer containerAnswering(
      ReefPart<NearbySpecies> Function() answer,
    ) {
      final container = ProviderContainer(
        overrides: [
          reefRepositoryProvider.overrideWithValue(
            _FakeSpeciesRepository(answer),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('a stalled species request leaves the other parts free', () async {
      final stalled = Completer<http.Response>();
      final container = containerFor((request) {
        if (request.url.host == 'api.gbif.org') return stalled.future;
        return Future.value(http.Response(jsonEncode({'features': []}), 200));
      });
      // Otherwise its 15 second limit fires during some later test in CI's
      // shared isolate.
      addTearDown(() => stalled.complete(http.Response('down', 503)));
      final species = container.listen(
        reefNearbySpeciesProvider(location),
        (_, _) {},
      );

      final habitat = await container.read(
        reefHabitatProvider(location).future,
      );
      final protection = await container.read(
        reefProtectionProvider(location).future,
      );

      expect(habitat.status, ReefDataStatus.empty);
      expect(protection.status, ReefDataStatus.empty);
      expect(species.read().isLoading, isTrue);
    });

    test('current health reads through the overridden client', () async {
      final container = containerFor((_) async => http.Response('down', 503));

      final part = await container.read(
        reefCurrentHealthProvider(location).future,
      );

      expect(part.status, ReefDataStatus.unavailable);
    });

    /// Reads species once under a listener, then lets the provider go.
    Future<ReefPart<NearbySpecies>> visit(ProviderContainer container) async {
      final sub = container.listen(
        reefNearbySpeciesProvider(location),
        (_, _) {},
      );
      final part = await container.read(
        reefNearbySpeciesProvider(location).future,
      );
      sub.close();
      await container.pump();
      return part;
    }

    test('a complete species answer is held after its last watcher', () async {
      var built = 0;
      final container = containerAnswering(() {
        built++;
        return const ReefPart.empty();
      });

      await visit(container);
      await visit(container);

      expect(built, 1);
    });

    test('a failed species answer goes with its last watcher', () async {
      var built = 0;
      final container = containerAnswering(() {
        built++;
        return const ReefPart.unavailable();
      });

      await visit(container);
      await visit(container);

      expect(built, 2, reason: 'no retry button, so the next visit must ask');
    });

    group('a partial species answer', () {
      const partial = ReefPart.ok(
        NearbySpecies(
          unmatchedNames: ['Aplysina archeri'],
          namesIncomplete: true,
        ),
      );

      /// [visit] for a fake clock, where nothing can be awaited.
      void visitSite(ProviderContainer container, FakeAsync async) {
        final sub = container.listen(
          reefNearbySpeciesProvider(location),
          (_, _) {},
        );
        async.flushMicrotasks();
        sub.close();
        async.elapse(Duration.zero);
      }

      test('waits out the failure window before asking again', () {
        fakeAsync((async) {
          var built = 0;
          final container = containerAnswering(() {
            built++;
            return partial;
          });

          visitSite(container, async);
          visitSite(container, async);
          expect(built, 1, reason: 'it is not cached, so this is its backoff');

          async.elapse(ReefCacheDao.failureTtl);
          visitSite(container, async);
          expect(built, 2);
        });
      });

      test('leaves no timer behind when the provider goes', () {
        fakeAsync((async) {
          final container = containerAnswering(() => partial);

          visitSite(container, async);
          container.dispose();
          async.flushMicrotasks();

          expect(async.pendingTimers, isEmpty);
        });
      });
    });
  });
}

class _FakeSpeciesRepository implements ReefRepository {
  final ReefPart<NearbySpecies> Function() answer;

  _FakeSpeciesRepository(this.answer);

  @override
  Future<ReefPart<NearbySpecies>> speciesFor(GeoPoint point) async => answer();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
