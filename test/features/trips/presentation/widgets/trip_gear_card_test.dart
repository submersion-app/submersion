import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
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
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Regulator',
    type: EquipmentType.regulator,
  );

  EquipmentSet kit(List<EquipmentItem> items) => EquipmentSet(
    id: 's1',
    name: 'Reef kit',
    description: '',
    equipmentIds: [for (final i in items) i.id],
    items: items,
    createdAt: now,
    updatedAt: now,
  );

  Future<_FakePacks> pump(
    WidgetTester tester, {
    Future<List<EquipmentItem>> Function()? gear,
    Trip? onTrip,
    List<EquipmentItem> active = const [],
    List<EquipmentSet> sets = const [],
    Set<String> unshared = const {},
    Locale? locale,
    bool diverUnreadable = false,
    bool noDiver = false,
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
          equipmentSetsProvider.overrideWith((ref) async => sets),
          equipmentSetWithItemsProvider.overrideWith(
            (ref, id) async => sets.where((s) => s.id == id).firstOrNull,
          ),
          validatedCurrentDiverIdProvider.overrideWith(
            (ref) async => diverUnreadable
                ? throw StateError('database is locked')
                : (noDiver ? null : 'd1'),
          ),
          equipmentRepositoryProvider.overrideWithValue(
            _FakeEquipment(unshared),
          ),
        ],
        locale: locale,
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

  group('Use set (issue #2794)', () {
    Future<void> sized(WidgetTester tester, double width) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('the buttons sit beside the title when they fit', (
      tester,
    ) async {
      await sized(tester, 800);
      await pump(tester, locale: const Locale('en'));
      final title = tester.getCenter(
        find.text(l10nOf(tester).trips_gear_title),
      );
      for (final key in ['trip-gear-use-set', 'trip-gear-add']) {
        expect(tester.getCenter(find.byKey(Key(key))).dy, title.dy);
      }
    });

    testWidgets('the buttons drop under the title when they do not fit', (
      tester,
    ) async {
      await sized(tester, 320);
      await pump(tester, locale: const Locale('hu'));
      final title = tester.getRect(find.text(l10nOf(tester).trips_gear_title));
      final useSet = tester.getRect(find.byKey(const Key('trip-gear-use-set')));
      expect(useSet.top, greaterThanOrEqualTo(title.bottom));
    });

    for (final locale in AppLocalizations.supportedLocales) {
      testWidgets('the header fits a 320 px phone in $locale', (tester) async {
        await sized(tester, 320);
        await pump(tester, gear: () async => const [bcd], locale: locale);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('trip-gear-use-set')), findsOneWidget);
        expect(find.byKey(const Key('trip-gear-add')), findsOneWidget);
      });
    }

    Future<void> useSet(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('trip-gear-use-set')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reef kit'));
      await tester.pumpAndSettle();
    }

    testWidgets('sits beside Add gear', (tester) async {
      await pump(tester);
      expect(find.text(l10nOf(tester).trips_gear_useSet), findsOneWidget);
    });

    testWidgets('packs every member of the picked set and says so', (
      tester,
    ) async {
      final fake = await pump(
        tester,
        sets: [
          kit(const [bcd, fins, reg]),
        ],
      );
      await useSet(tester);
      expect(fake.packed.single.$1, 't1');
      expect(fake.packed.single.$2, ['bcd', 'fins', 'reg']);
      expect(
        find.text(l10nOf(tester).trips_gear_packedFromSet(3, 'Reef kit')),
        findsOneWidget,
      );
    });

    testWidgets('skips a member no longer shared with the diver', (
      tester,
    ) async {
      final fake = await pump(
        tester,
        sets: [
          kit(const [bcd, fins, reg]),
        ],
        unshared: {'fins'},
      );
      await useSet(tester);
      expect(fake.packed.single.$2, ['bcd', 'reg']);
    });

    testWidgets('a set with no member still shared packs nothing', (
      tester,
    ) async {
      final fake = await pump(
        tester,
        sets: [
          kit(const [bcd, fins]),
        ],
        unshared: {'bcd', 'fins'},
      );
      await useSet(tester);
      expect(fake.packed, isEmpty);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('with no diver yet every member is packed', (tester) async {
      final fake = await pump(
        tester,
        sets: [
          kit(const [bcd, fins]),
        ],
        unshared: {'fins'},
        noDiver: true,
      );
      await useSet(tester);
      expect(fake.packed.single.$2, ['bcd', 'fins']);
    });

    // Packing unscoped would skip the #2046 share filter, so a diver that
    // cannot be read fails the pack and says so.
    testWidgets('an unreadable diver packs nothing and says so', (
      tester,
    ) async {
      final fake = await pump(
        tester,
        sets: [
          kit(const [bcd, fins]),
        ],
        unshared: {'fins'},
        diverUnreadable: true,
      );
      await useSet(tester);
      expect(fake.packed, isEmpty);
      expect(find.text(l10nOf(tester).trips_gear_failed), findsOneWidget);
    });

    testWidgets('a set already packed says nothing was added', (tester) async {
      final fake = await pump(
        tester,
        gear: () async => const [bcd],
        sets: [
          kit(const [bcd]),
        ],
      );
      fake.alreadyPacked = {'bcd'};
      await useSet(tester);
      final l10n = l10nOf(tester);
      expect(
        find.text(l10n.trips_gear_packedFromSet(0, 'Reef kit')),
        findsOneWidget,
      );
      expect(
        l10n.trips_gear_packedFromSet(0, 'Reef kit'),
        'Everything in Reef kit is already packed',
      );
    });

    testWidgets('a failed pack says so', (tester) async {
      final fake = await pump(
        tester,
        sets: [
          kit(const [bcd]),
        ],
      );
      fake.failing = true;
      await useSet(tester);
      final l10n = l10nOf(tester);
      expect(find.text(l10n.trips_gear_failed), findsOneWidget);
      expect(
        find.text(l10n.trips_gear_packedFromSet(1, 'Reef kit')),
        findsNothing,
      );
    });

    testWidgets('closing the picker packs nothing', (tester) async {
      final fake = await pump(
        tester,
        sets: [
          kit(const [bcd]),
        ],
      );
      await tester.tap(find.byKey(const Key('trip-gear-use-set')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(fake.packed, isEmpty);
    });
  });
}

/// Hides the [unshared] ids the way `usableSetMemberIds` hides a member
/// another diver owns and no longer shares (issue #2046).
class _FakeEquipment extends EquipmentRepository {
  _FakeEquipment(this.unshared);

  final Set<String> unshared;

  @override
  Future<List<String>> usableSetMemberIds(
    List<String> ids,
    String diverId,
  ) async => [
    for (final id in ids)
      if (!unshared.contains(id)) id,
  ];
}

class _FakePacks extends TripEquipmentRepository {
  bool failing = false;
  Set<String> alreadyPacked = const {};
  final packed = <(String, List<String>)>[];
  final unpacked = <(String, String)>[];

  @override
  Future<int> pack(String tripId, Iterable<String> equipmentIds) async {
    if (failing) throw StateError('database is locked');
    packed.add((tripId, equipmentIds.toList()));
    return equipmentIds.where((id) => !alreadyPacked.contains(id)).length;
  }

  @override
  Future<void> unpack(String tripId, String equipmentId) async {
    if (failing) throw StateError('database is locked');
    unpacked.add((tripId, equipmentId));
  }
}
