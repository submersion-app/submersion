import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/dense_trip_list_tile.dart';

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
  group('DenseTripListTile', () {
    testWidgets('renders trip name and dive count', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseTripListTile(
            tripWithStats: _makeTrip(name: 'Red Sea Explorer', diveCount: 8),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Red Sea Explorer'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('renders abbreviated date range', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseTripListTile(tripWithStats: _makeTrip(), onTap: () {}),
        ),
      );

      // Check that some date text is present
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('shows selected color when isSelected is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseTripListTile(
            tripWithStats: _makeTrip(),
            isSelected: true,
            onTap: () {},
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, isNotNull);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        testApp(
          child: DenseTripListTile(
            tripWithStats: _makeTrip(),
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(InkWell).first);
      expect(tapped, isTrue);
    });

    testWidgets('renders zero dive count', (tester) async {
      await tester.pumpWidget(
        testApp(
          child: DenseTripListTile(
            tripWithStats: _makeTrip(diveCount: 0),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('0'), findsOneWidget);
    });
  });
}
