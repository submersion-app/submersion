import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/presentation/providers/side_trip_providers.dart';

import '../../../../helpers/test_database.dart';

/// The side trips of a trip and the larger trip of a side trip, for the
/// active profile (issue #3658).
void main() {
  late AppDatabase db;
  late ProviderContainer container;

  Future<void> trip(String id, {String? parent}) => db.customStatement(
    'INSERT INTO trips (id, name, start_date, end_date, parent_trip_id, '
    'created_at, updated_at) VALUES (?, ?, 0, 0, ?, 0, 0)',
    [id, id, parent],
  );

  setUp(() async {
    db = await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await trip('P');
    await trip('S', parent: 'P');
  });
  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test('sideTripsProvider lists the side trips', () async {
    final sides = await container.read(sideTripsProvider('P').future);
    expect(sides.map((t) => t.id), ['S']);
  });

  test('parentTripProvider names the larger trip', () async {
    expect((await container.read(parentTripProvider('S').future))!.id, 'P');
    expect(await container.read(parentTripProvider('P').future), isNull);
  });
}
