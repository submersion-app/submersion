import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_equipment_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_gear_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The trip page's Gear card (issue #2338).
void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  final now = DateTime.now();
  Trip trip({bool past = false}) => Trip(
    id: 't1',
    name: 'Bonaire',
    startDate: DateTime(now.year, now.month, now.day + (past ? -20 : 10)),
    endDate: DateTime(now.year, now.month, now.day + (past ? -15 : 15)),
    createdAt: now,
    updatedAt: now,
  );

  const bcd = EquipmentItem(id: 'bcd', name: 'BCD', type: EquipmentType.bcd);

  Future<_FakePacks> pump(
    WidgetTester tester, {
    Future<List<EquipmentItem>> Function()? gear,
    Trip? onTrip,
    List<EquipmentItem> active = const [],
  }) async {
    final fake = _FakePacks();
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          tripGearProvider(
            't1',
          ).overrideWith((ref) => (gear ?? () async => const [])()),
          tripEquipmentRepositoryProvider.overrideWithValue(fake),
          activeEquipmentProvider.overrideWith((ref) async => active),
        ],
        child: TripGearCard(trip: onTrip ?? trip()),
      ),
    );
    await tester.pumpAndSettle();
    return fake;
  }

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(Scaffold)));

  testWidgets('renders nothing while the gear is loading', (tester) async {
    final pending = Completer<List<EquipmentItem>>();
    await pump(tester, gear: () => pending.future);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('an upcoming trip with no gear offers Add gear', (tester) async {
    await pump(tester);
    final l10n = l10nOf(tester);
    expect(find.text(l10n.trips_gear_none), findsOneWidget);
    expect(find.text(l10n.trips_gear_add), findsOneWidget);
  });

  testWidgets('a past trip with no gear shows nothing', (tester) async {
    await pump(tester, onTrip: trip(past: true));
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('lists the packed gear by name', (tester) async {
    await pump(tester, gear: () async => const [bcd]);
    expect(find.text('BCD'), findsOneWidget);
  });

  testWidgets('Unpack removes the item', (tester) async {
    final fake = await pump(tester, gear: () async => const [bcd]);
    await tester.tap(find.byTooltip(l10nOf(tester).trips_gear_remove));
    await tester.pumpAndSettle();
    expect(fake.unpacked, [('t1', 'bcd')]);
  });

  testWidgets('a failed unpack says so', (tester) async {
    final fake = await pump(tester, gear: () async => const [bcd]);
    fake.failing = true;
    await tester.tap(find.byTooltip(l10nOf(tester).trips_gear_remove));
    await tester.pumpAndSettle();
    expect(find.text(l10nOf(tester).trips_gear_failed), findsOneWidget);
  });

  testWidgets('Add gear packs the picked item', (tester) async {
    final fake = await pump(tester, active: const [bcd]);
    await tester.tap(find.text(l10nOf(tester).trips_gear_add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BCD').last);
    await tester.pumpAndSettle();
    expect(fake.packed.map((p) => p.$1), ['t1']);
    expect(fake.packed.single.$2, ['bcd']);
  });
}

class _FakePacks extends TripEquipmentRepository {
  bool failing = false;
  final packed = <(String, List<String>)>[];
  final unpacked = <(String, String)>[];

  @override
  Future<int> pack(String tripId, Iterable<String> equipmentIds) async {
    packed.add((tripId, equipmentIds.toList()));
    return equipmentIds.length;
  }

  @override
  Future<void> unpack(String tripId, String equipmentId) async {
    if (failing) throw StateError('database is locked');
    unpacked.add((tripId, equipmentId));
  }
}
