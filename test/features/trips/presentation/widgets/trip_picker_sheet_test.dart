import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_picker.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('a failed trip load says so without the exception', (
    tester,
  ) async {
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          allTripsProvider.overrideWith(
            (ref) => Future<List<Trip>>.error(StateError('database is locked')),
          ),
        ],
        child: TripPickerSheet(
          scrollController: scrollController,
          selectedTrip: null,
          onTripSelected: (_) {},
          onCreateNewTrip: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load your trips."), findsOneWidget);
    expect(find.textContaining('database is locked'), findsNothing);
  });
}
