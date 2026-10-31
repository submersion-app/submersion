import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/repositories/reef_repository.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/entities/reef_protection.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _location = GeoPoint(12.16, -68.28);
const _reef = ReefPart<ReefHabitat>.ok(
  ReefHabitat(onReef: true, threatLevel: 'High'),
);

/// Each part answers with whatever its queue holds next; a Future left
/// incomplete is a source that has not replied.
class _FakeRepository implements ReefRepository {
  final habitat = <Future<ReefPart<ReefHabitat>>>[];
  final health = <Future<ReefPart<ReefHealth>>>[];
  final protection = <Future<ReefPart<List<ReefProtection>>>>[];
  final forgotten = <ReefProviderId>[];
  Object? forgetError;
  int habitatCalls = 0;
  int healthCalls = 0;
  int protectionCalls = 0;

  @override
  Future<ReefPart<ReefHabitat>> habitatFor(GeoPoint point) =>
      habitat[habitatCalls++];

  @override
  Future<ReefPart<ReefHealth>> currentHealthFor(GeoPoint point) =>
      health[healthCalls++];

  @override
  Future<ReefPart<List<ReefProtection>>> protectionFor(GeoPoint point) =>
      protection[protectionCalls++];

  @override
  Future<void> forgetFailure(ReefProviderId provider, GeoPoint point) async {
    if (forgetError case final error?) throw error;
    forgotten.add(provider);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness(_FakeRepository repository, {WaterType? waterType}) {
  return ProviderScope(
    // A thrown part would otherwise back off on timers the test never runs.
    retry: (_, _) => null,
    overrides: [
      reefRepositoryProvider.overrideWithValue(repository),
      temperatureUnitProvider.overrideWithValue(TemperatureUnit.celsius),
    ],
    child: localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReefSection(location: _location, waterType: waterType),
        ),
      ),
    ),
  );
}

ReefPart<ReefHealth> _stressed() => ReefPart.ok(
  ReefHealth(
    sst: 30.1,
    degreeHeatingWeeks: 15.64,
    hotspot: 0.91,
    alertLevel: BleachingAlertLevel.watch,
    observedAt: DateTime.utc(2023, 9, 1, 12),
  ),
);

void main() {
  // WaterConditionsCard formats the observation date with DateFormat.yMMMd(),
  // which resolves against intl's process-global default locale.
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  testWidgets('a ready part shows while the others are still checking', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..habitat.add(Future.value(_reef))
      ..health.add(Completer<ReefPart<ReefHealth>>().future)
      ..protection.add(Completer<ReefPart<List<ReefProtection>>>().future);

    await tester.pumpWidget(_harness(repository));
    await tester.pump();

    expect(find.textContaining('threat level High'), findsOneWidget);
    expect(find.text('Water conditions'), findsOneWidget);
    expect(find.text('Protected area'), findsOneWidget);
    expect(find.text('Checking…'), findsNWidgets(2));
  });

  testWidgets('a part arriving late fills its row and leaves the rest', (
    tester,
  ) async {
    final late = Completer<ReefPart<List<ReefProtection>>>();
    final repository = _FakeRepository()
      ..habitat.add(Future.value(_reef))
      ..health.add(Future.value(const ReefPart<ReefHealth>.empty()))
      ..protection.add(late.future);

    await tester.pumpWidget(_harness(repository));
    await tester.pump();
    expect(find.text('Checking…'), findsOneWidget);

    late.complete(const ReefPart.ok([ReefProtection(siteName: 'Bonaire')]));
    await tester.pumpAndSettle();

    expect(find.text('Checking…'), findsNothing);
    expect(find.text('Bonaire'), findsOneWidget);
    expect(find.textContaining('threat level High'), findsOneWidget);
    expect(repository.habitatCalls, 1);
  });

  testWidgets('coral stress lines stay until habitat rules a reef out', (
    tester,
  ) async {
    final habitat = Completer<ReefPart<ReefHabitat>>();
    final repository = _FakeRepository()
      ..habitat.add(habitat.future)
      ..health.add(Future.value(_stressed()))
      ..protection.add(Future.value(const ReefPart.empty()));

    await tester.pumpWidget(_harness(repository));
    await tester.pump();
    expect(find.textContaining('15.6'), findsOneWidget);

    habitat.complete(const ReefPart.empty());
    await tester.pumpAndSettle();

    expect(find.textContaining('15.6'), findsNothing);
    expect(find.text('Reef habitat'), findsNothing);
  });

  testWidgets('every failed part offers a retry, a good part does not', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..habitat.add(Future.value(const ReefPart.unavailable()))
      ..health.add(Future.value(const ReefPart.unavailable()))
      ..protection.add(Future.value(const ReefPart.empty()));

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsNWidgets(2));
    expect(find.text('Not in a marine protected area'), findsOneWidget);
  });

  testWidgets('retry forgets the failure and refetches only that part', (
    tester,
  ) async {
    final second = Completer<ReefPart<ReefHabitat>>();
    final repository = _FakeRepository()
      ..habitat.addAll([
        Future.value(const ReefPart.unavailable()),
        second.future,
      ])
      ..health.add(Future.value(_stressed()))
      ..protection.add(
        Future.value(const ReefPart.ok([ReefProtection(siteName: 'Bonaire')])),
      );

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    // The row is checking again, not showing the old failure.
    expect(repository.forgotten, [ReefProviderId.habitat]);
    expect(find.text('Could not check reef habitat right now'), findsNothing);
    expect(find.text('Checking…'), findsOneWidget);
    expect(find.text('Bonaire'), findsOneWidget);
    expect(find.textContaining('15.6'), findsOneWidget);

    second.complete(_reef);
    await tester.pumpAndSettle();

    expect(find.textContaining('threat level High'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
    expect(repository.healthCalls, 1);
    expect(repository.protectionCalls, 1);
  });

  testWidgets('water and protection retries name their own part', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..habitat.add(Future.value(const ReefPart.empty()))
      ..health.addAll([
        Future.value(const ReefPart.unavailable()),
        Future.value(const ReefPart.empty()),
      ])
      ..protection.addAll([
        Future.value(const ReefPart.unavailable()),
        Future.value(const ReefPart.empty()),
      ]);

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.forgotten, [
      ReefProviderId.health,
      ReefProviderId.protection,
    ]);
    expect(repository.healthCalls, 2);
    expect(repository.protectionCalls, 2);
  });

  testWidgets('a retry that fails again lands back on the retry state', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..habitat.addAll([
        Future.value(const ReefPart.unavailable()),
        Future.value(const ReefPart.unavailable()),
      ])
      ..health.add(Future.value(const ReefPart.empty()))
      ..protection.add(Future.value(const ReefPart.empty()));

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Could not check reef habitat right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('a retry still refetches when forgetting the failure fails', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..forgetError = StateError('cache delete failed')
      ..habitat.addAll([
        Future.value(const ReefPart.unavailable()),
        Future.value(_reef),
      ])
      ..health.add(Future.value(const ReefPart.empty()))
      ..protection.add(Future.value(const ReefPart.empty()));

    await tester.pumpWidget(_harness(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(repository.habitatCalls, 2);
    expect(find.textContaining('threat level High'), findsOneWidget);
  });

  testWidgets('a part that throws reads as unavailable with a retry', (
    tester,
  ) async {
    final habitat = Completer<ReefPart<ReefHabitat>>();
    final repository = _FakeRepository()
      ..habitat.add(habitat.future)
      ..health.add(Future.value(const ReefPart.empty()))
      ..protection.add(Future.value(const ReefPart.empty()));

    await tester.pumpWidget(_harness(repository));
    await tester.pump();
    habitat.completeError(StateError('cache read failed'));
    await tester.pumpAndSettle();

    expect(find.text('Could not check reef habitat right now'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Not in a marine protected area'), findsOneWidget);
  });

  testWidgets('a freshwater site never asks for NOAA data', (tester) async {
    final repository = _FakeRepository()
      ..habitat.add(Future.value(const ReefPart.empty()))
      ..protection.add(Future.value(const ReefPart.empty()));

    await tester.pumpWidget(_harness(repository, waterType: WaterType.fresh));
    await tester.pumpAndSettle();

    expect(repository.healthCalls, 0);
    expect(find.text('Checking…'), findsNothing);
    expect(find.text('Retry'), findsNothing);
    expect(find.text('Water conditions'), findsOneWidget);
  });
}
