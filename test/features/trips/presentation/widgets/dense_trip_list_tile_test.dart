import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/widgets/dense_trip_list_tile.dart';

import '../../../../helpers/test_app.dart';

/// The tile watches [settingsProvider] for the date format; the real notifier
/// would pull in a database, so stand in with a fixed [AppSettings].
class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier([super.initial = const AppSettings()]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// `Override` is sealed and not re-exported, so the helper stays dynamic --
// same convention as `testApp`'s `overrides` parameter.
List<dynamic> _settingsOverrides([AppSettings settings = const AppSettings()]) {
  return [
    settingsProvider.overrideWith((ref) => _TestSettingsNotifier(settings)),
  ];
}

TripWithStats _makeTrip({
  String name = 'Test Trip',
  int diveCount = 5,
  int totalRuntime = 0,
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
    totalRuntime: totalRuntime,
  );
}

void main() {
  group('DenseTripListTile', () {
    testWidgets('renders trip name and dive count', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: _settingsOverrides(),
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
          overrides: _settingsOverrides(),
          child: DenseTripListTile(tripWithStats: _makeTrip(), onTap: () {}),
        ),
      );

      // Check that some date text is present
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('orders the date range day-first for a day-first diver', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: _settingsOverrides(
            const AppSettings(dateFormat: DateFormatPreference.ddmmyyyy),
          ),
          child: DenseTripListTile(tripWithStats: _makeTrip(), onTap: () {}),
        ),
      );

      // The trip runs 2025-06-01 to 2025-06-08; both ends carry a year here
      // because the fixture predates the current year.
      expect(find.text('1 Jun 2025 - 8 Jun 2025'), findsOneWidget);
    });

    testWidgets('orders the date range month-first for a month-first diver', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: _settingsOverrides(
            const AppSettings(dateFormat: DateFormatPreference.mmddyyyy),
          ),
          child: DenseTripListTile(tripWithStats: _makeTrip(), onTap: () {}),
        ),
      );

      expect(find.text('Jun 1, 2025 - Jun 8, 2025'), findsOneWidget);
    });

    testWidgets('shows selected color when isSelected is true', (tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: _settingsOverrides(),
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
          overrides: _settingsOverrides(),
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
          overrides: _settingsOverrides(),
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
