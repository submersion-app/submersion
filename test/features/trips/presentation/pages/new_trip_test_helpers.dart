import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

import '../../../../helpers/pump_until.dart';

/// Waits until a new trip's page (issue #4527, phase 3, plan 11) has
/// opened: its name field shown and nothing still loading. Its seed and
/// Documents card read the database, which answers only outside the
/// test's fake clock.
Future<void> pumpUntilNewTripPageOpens(WidgetTester tester) async {
  await pumpUntilRealAsync(
    tester,
    () =>
        find.byKey(const Key('trip-edit-name')).evaluate().isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty,
    reason: "the new trip's page to open",
  );
  await tester.pumpAndSettle();
}

/// A trip save service that creates without a database: it keeps each
/// created trip's id and hands the trip to [onCreate], for a test whose
/// reads should find it.
class CreatingTripSave implements TripEditSaveService {
  CreatingTripSave({this.onCreate});

  final void Function(Trip trip)? onCreate;
  final created = <String>[];

  @override
  Future<Trip> create({
    required Trip trip,
    required Iterable<String> changedCardIds,
    List<String> draftDiveIds = const [],
    Future<void> Function()? alsoWrite,
  }) async {
    onCreate?.call(trip);
    created.add(trip.id);
    return trip;
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
