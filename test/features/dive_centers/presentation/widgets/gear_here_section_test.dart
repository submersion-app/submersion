import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/gear_here_section.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  EquipmentLocation place(String id, {String? center = 'c'}) =>
      EquipmentLocation(
        id: id,
        name: id,
        kind: EquipmentLocationKind.diveCenter,
        diveCenterId: center,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  const wing = EquipmentItem(id: 'bcd', name: 'Wing', type: EquipmentType.bcd);

  Future<void> pump(
    WidgetTester tester, {
    required List<EquipmentItem> items,
    required Map<String, EquipmentLocation> current,
    List<EquipmentLocation>? places,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) =>
              const Scaffold(body: GearHereSection(centerId: 'c')),
        ),
        GoRoute(
          path: '/equipment/:id',
          builder: (context, state) =>
              Scaffold(body: Text('ITEM ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allEquipmentProvider.overrideWith((ref) async => items),
          currentEquipmentLocationsProvider.overrideWith(
            (ref) async => current,
          ),
          allEquipmentLocationsByIdProvider.overrideWith(
            (ref) async => {for (final p in places ?? current.values) p.id: p},
          ),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('builds nothing when no gear is there', (tester) async {
    await pump(
      tester,
      items: const [wing],
      current: {'bcd': place('x', center: 'other')},
    );
    expect(find.text('Your gear here'), findsNothing);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('lists the gear with its type', (tester) async {
    await pump(tester, items: const [wing], current: {'bcd': place('reef')});
    expect(find.text('Your gear here'), findsOneWidget);
    expect(find.text('Wing'), findsOneWidget);
    expect(find.text('BCD'), findsOneWidget);
  });

  testWidgets('leaves out retired, sold and wishlist gear', (tester) async {
    final reef = place('reef');
    EquipmentItem gone(String id, EquipmentStatus status) => EquipmentItem(
      id: id,
      name: id,
      type: EquipmentType.bcd,
      status: status,
    );
    await pump(
      tester,
      items: [
        gone('old', EquipmentStatus.retired),
        gone('sold', EquipmentStatus.sold),
        gone('wish', EquipmentStatus.wanted),
      ],
      current: {'old': reef, 'sold': reef, 'wish': reef},
    );
    expect(find.text('Your gear here'), findsNothing);
  });

  testWidgets('keeps gear at an archived place', (tester) async {
    await pump(
      tester,
      items: const [wing],
      current: {'bcd': place('old').copyWith(isArchived: true)},
    );
    expect(find.text('Wing'), findsOneWidget);
  });

  testWidgets('one place at the center goes unnamed', (tester) async {
    await pump(
      tester,
      items: const [wing],
      current: {'bcd': place('Locker 12')},
    );
    expect(find.textContaining('Locker 12'), findsNothing);
  });

  testWidgets('several places at the center are named', (tester) async {
    final locker = place('Locker 12');
    await pump(
      tester,
      items: const [wing],
      current: {'bcd': locker},
      places: [locker, place('Boat')],
    );
    expect(find.textContaining('Locker 12'), findsOneWidget);
  });

  testWidgets('tapping a row opens the item', (tester) async {
    await pump(tester, items: const [wing], current: {'bcd': place('reef')});
    await tester.tap(find.text('Wing'));
    await tester.pumpAndSettle();
    expect(find.text('ITEM bcd'), findsOneWidget);
  });
}
