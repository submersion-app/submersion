import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_mirror_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/new_dive_after_create.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/tides/presentation/providers/tide_providers.dart';
import 'package:submersion/features/weather/data/repositories/weather_repository.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Records each weather fetch instead of asking the network.
class _SpyWeather extends WeatherRepository {
  _SpyWeather()
    : super(weatherService: WeatherService(), diveRepository: DiveRepository());

  final fetched = <String>[];

  @override
  Future<void> fetchAndSaveWeather({
    required String diveId,
    required double latitude,
    required double longitude,
    required DateTime dateTime,
  }) async => fetched.add('$diveId $latitude');
}

/// Answers the buddy question's candidates, and counts the asks.
class _NoCandidates implements DiveMirrorService {
  final asked = <String>[];

  @override
  Future<List<MirrorCandidate>> candidates(String diveId) async {
    asked.add(diveId);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [NewDiveAfterCreate.read] wires each step to the app's own services
/// (issue #4527, plan 8).
void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  const point = GeoPoint(7.1, 134.2);
  final created = Dive(
    id: 'new',
    dateTime: DateTime.utc(2026, 11, 17, 9, 30),
    site: const DiveSite(id: 'reef', name: 'Blue Corner', location: point),
  );

  testWidgets('the steps reach the weather, tide and buddy services', (
    tester,
  ) async {
    final weather = _SpyWeather();
    final mirror = _NoCandidates();
    var tideAsked = 0;
    late NewDiveAfterCreate after;
    final overrides = await tester.runAsync(getBaseOverrides);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides!,
          weatherRepositoryProvider.overrideWithValue(weather),
          diveMirrorServiceProvider.overrideWithValue(mirror),
          resolvedTideDataProvider(point).overrideWith((ref) async {
            tideAsked++;
            return null;
          }),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              after = NewDiveAfterCreate.read(context, ref);
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    // Each wired step on its own; the rules step needs the rule engine's
    // own flow and is the one-line call to captureRulesAfterCreate's runner.
    after.fetchWeather(created, point);
    await tester.runAsync(() => after.recordTide(created, point));
    await tester.runAsync(() => after.offerMirror(created.id));
    await tester.pump();

    expect(weather.fetched, ['new 7.1']);
    expect(tideAsked, 1);
    expect(mirror.asked, ['new']);
  });
}
