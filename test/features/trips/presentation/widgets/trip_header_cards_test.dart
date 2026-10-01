import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_equipment_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_fill_forecast_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_cylinders_card.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_gear_card.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_header_cards.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// The trip page's header cards share one height budget (issue #2338), so a
/// full set on a phone still leaves the story room.
void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('full cards on a phone leave the story room', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Bonaire')),
          body: const Column(
            children: [
              TripHeaderCards(
                children: [
                  SizedBox(height: 2000),
                  SizedBox(height: 2000),
                  SizedBox(height: 2000),
                ],
              ),
              Expanded(child: SizedBox.expand(key: Key('story'))),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const Key('story'))).height,
      greaterThanOrEqualTo(844 * 0.3),
    );
  });

  testWidgets('short cards take only their own height', (tester) async {
    phone(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TripHeaderCards(children: [SizedBox(height: 40)]),
              Expanded(child: SizedBox.expand(key: Key('story'))),
            ],
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const Key('story'))).height, 844 - 40);
  });

  group('full Cylinders and Gear cards on a phone (#2653)', () {
    final now = DateTime.now();
    final at = DateTime.utc(2026, 3, 9, 8);
    final trip = Trip(
      id: 't1',
      name: 'Bonaire',
      startDate: DateTime(now.year, now.month, now.day + 10),
      endDate: DateTime(now.year, now.month, now.day + 16),
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

    List<TripCylinderState> slots() => [
      for (var i = 0; i < 60; i++)
        foldCylinderState(
          cylinder: TripCylinder(
            id: 'c$i',
            tripId: 't1',
            label: 'Truck $i',
            workingPressure: 207,
            createdAt: at,
            updatedAt: at,
          ),
          events: const [],
          uses: const [],
        ),
    ];

    final gear = [
      for (var i = 0; i < 60; i++)
        EquipmentItem(id: 'g$i', name: 'Item $i', type: EquipmentType.other),
    ];

    Future<void> pump(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
            tripCylinderStatesProvider(
              't1',
            ).overrideWith((ref) async => slots()),
            tripFillForecastProvider('t1').overrideWith((ref) async => null),
            tripGearProvider('t1').overrideWith((ref) async => gear),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  TripHeaderCards(
                    children: [
                      TripCylindersCard(trip: trip),
                      TripGearCard(trip: trip),
                    ],
                  ),
                  const Expanded(child: SizedBox.expand(key: Key('story'))),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Whether [finder]'s top edge lies inside the header's window.
    bool shown(WidgetTester tester, Finder finder) {
      final header = tester.getRect(find.byType(TripHeaderCards));
      final top = tester.getTopLeft(finder).dy;
      return top >= header.top && top < header.bottom;
    }

    testWidgets('the header is the only thing that scrolls', (tester) async {
      await pump(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(TripHeaderCards),
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a drag on the Cylinders card goes on to the Gear card', (
      tester,
    ) async {
      await pump(tester);
      final header = tester.getRect(find.byType(TripHeaderCards));

      // Drag on whatever part of the Cylinders card is in view, the way a
      // thumb would, well past the end of its chips. Once the card has
      // nothing left to show, the drag carries the Gear card up.
      final cylinders = find.byKey(const Key('trip-cylinders-card'));
      for (var i = 0; i < 30; i++) {
        final visible = tester.getRect(cylinders).intersect(header);
        if (visible.height < 40) break;
        await tester.dragFrom(visible.center, const Offset(0, -150));
        await tester.pumpAndSettle();
      }
      expect(
        tester.getTopLeft(find.byType(TripGearCard)).dy,
        lessThan(header.top + 100),
      );
      expect(shown(tester, find.byKey(const Key('trip-gear-add'))), isTrue);
    });
  });
}
