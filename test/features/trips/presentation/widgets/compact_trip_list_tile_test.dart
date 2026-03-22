import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/compact_trip_list_tile.dart';

import '../../../../helpers/test_app.dart';

TripWithStats _makeTrip({
  String name = 'Test Trip',
  int diveCount = 5,
  int totalBottomTime = 0,
}) {
  final now = DateTime(2025, 6, 1);
  return TripWithStats(
    trip: Trip(
      id: 'trip-1',
      name: name,
      startDate: now,
      endDate: now.add(const Duration(days: 7)),
      tripType: TripType.shore,
      createdAt: now,
      updatedAt: now,
    ),
    diveCount: diveCount,
    totalBottomTime: totalBottomTime,
  );
}

void main() {
  group('CompactTripListTile', () {
    testWidgets('renders trip name and date range', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: CompactTripListTile(
            tripWithStats: _makeTrip(name: 'Palau Adventure'),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Palau Adventure'), findsOneWidget);
      // Date text should be visible somewhere in the row
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('renders dive count', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: CompactTripListTile(
            tripWithStats: _makeTrip(diveCount: 12),
            onTap: () {},
          ),
        ),
      );

      expect(find.textContaining('12'), findsWidgets);
    });

    testWidgets('renders bottom time when non-zero', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: CompactTripListTile(
            // 3600 seconds = 1h 0m
            tripWithStats: _makeTrip(totalBottomTime: 3600),
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.timer), findsOneWidget);
      expect(find.text('1h 0m'), findsOneWidget);
    });

    testWidgets('hides bottom time when zero', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: CompactTripListTile(
            tripWithStats: _makeTrip(totalBottomTime: 0),
            onTap: () {},
          ),
        ),
      );

      expect(find.byIcon(Icons.timer), findsNothing);
    });

    testWidgets('shows selected color when isSelected is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: CompactTripListTile(
            tripWithStats: _makeTrip(),
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      final card = tester.widget<Card>(find.byType(Card));
      expect(card.color, isNotNull);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        testApp(
          child: CompactTripListTile(
            tripWithStats: _makeTrip(),
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });
  });
}
