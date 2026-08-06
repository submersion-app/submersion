import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';

void main() {
  // reefRepositoryProvider reads the local cache database singleton, so it
  // must be primed with an in-memory instance before any provider resolves.
  setUp(() {
    LocalCacheDatabaseService.instance.setTestDatabase(
      LocalCacheDatabase(NativeDatabase.memory()),
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

  test('reefSnapshotProvider resolves through the overridden client', () async {
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

    final snapshot = await container.read(
      reefSnapshotProvider(const GeoPoint(12.16, -68.28)).future,
    );
    expect(snapshot.habitat, isNotNull);
  });
}
