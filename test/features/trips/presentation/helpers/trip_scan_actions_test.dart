import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/media/data/services/photo_picker_service.dart';
import 'package:submersion/features/media/presentation/providers/photo_picker_providers.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_scan_actions.dart';
import 'package:submersion/features/trips/presentation/providers/trip_media_providers.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Photo picker that always denies permission.
class _DeniedPicker implements PhotoPickerService {
  @override
  Future<PhotoPermissionStatus> requestPermission() async =>
      PhotoPermissionStatus.denied;

  @override
  Future<PhotoPermissionStatus> checkPermission() async =>
      PhotoPermissionStatus.denied;

  @override
  Future<List<AssetInfo>> getAssetsInDateRange(DateTime s, DateTime e) async =>
      [];

  @override
  Future<Uint8List?> getThumbnail(String id, {int size = 200}) async => null;

  @override
  Future<Uint8List?> getFileBytes(String id) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Trip repository whose candidate lookup returns nothing.
class _NoCandidatesRepo extends TripRepository {
  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async => [];
}

/// Trip repository that records the diverId it was queried with, so tests
/// can assert which diver's dives get searched.
class _RecordingCandidatesRepo extends TripRepository {
  String? lastDiverId;

  @override
  Future<List<DiveCandidate>> findCandidateDivesForTrip({
    required String tripId,
    required DateTime startDate,
    required DateTime endDate,
    required String diverId,
  }) async {
    lastDiverId = diverId;
    return [];
  }
}

/// Mock CurrentDiverIdNotifier pinned to a fixed active diver.
class _FixedDiverIdNotifier extends StateNotifier<String?>
    implements CurrentDiverIdNotifier {
  _FixedDiverIdNotifier(super.diverId);

  @override
  Future<void> setCurrentDiver(String id) async => state = id;

  @override
  Future<void> clearCurrentDiver() async => state = null;
}

Trip _trip({String? diverId}) => Trip(
  id: 'trip-1',
  diverId: diverId,
  name: 'Bonaire',
  startDate: DateTime(2026, 3, 25),
  endDate: DateTime(2026, 3, 30),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

/// Pumps a button that invokes [onPressed] with a live context + ref.
Future<void> pumpActionButton(
  WidgetTester tester,
  List<Override> extra,
  void Function(BuildContext, WidgetRef) onPressed,
) async {
  final overrides = await getBaseOverrides();
  // Let `extra` overrides win when they target a provider the base list
  // already overrides (e.g. currentDiverIdProvider); Riverpod disallows
  // overriding the same provider twice in one ProviderScope.
  final extraOrigins = extra.map((o) => o.origin).toSet();
  final deduped = overrides.where((o) => !extraOrigins.contains(o.origin));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...deduped, ...extra].cast(),
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Consumer(
          builder: (context, ref, _) => Scaffold(
            body: ElevatedButton(
              onPressed: () => onPressed(context, ref),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('scanForTripDives explains when there is no active diver', (
    tester,
  ) async {
    // The trip has an owner; what is missing is the *active* diver, so the
    // guard and its message must both be about the active diver. The base
    // overrides pin currentDiverIdProvider to null.
    await pumpActionButton(
      tester,
      const [],
      (context, ref) => scanForTripDives(context, ref, _trip(diverId: 'BAB')),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // No scan runs, but the user gets feedback instead of a silent no-op.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Select an active diver to scan for dives'),
      findsOneWidget,
    );
  });

  testWidgets('scanForTripDives shows a no-matches snackbar', (tester) async {
    await pumpActionButton(tester, [
      tripRepositoryProvider.overrideWithValue(_NoCandidatesRepo()),
      currentDiverIdProvider.overrideWith((ref) => _FixedDiverIdNotifier('d1')),
    ], (context, ref) => scanForTripDives(context, ref, _trip(diverId: 'd1')));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('No matching dives found'), findsOneWidget);
  });

  testWidgets('scanForTripDives searches the active diver, not the trip owner '
      '(shared trip)', (tester) async {
    // Trip is owned by BAB but shared with, and being viewed by, MAB.
    final repo = _RecordingCandidatesRepo();
    await pumpActionButton(tester, [
      tripRepositoryProvider.overrideWithValue(repo),
      currentDiverIdProvider.overrideWith(
        (ref) => _FixedDiverIdNotifier('MAB'),
      ),
    ], (context, ref) => scanForTripDives(context, ref, _trip(diverId: 'BAB')));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(repo.lastDiverId, 'MAB');
  });

  testWidgets('scanGalleryForTripPhotos asks to add dives first when empty', (
    tester,
  ) async {
    await pumpActionButton(
      tester,
      [divesForTripProvider('trip-1').overrideWith((ref) async => <Dive>[])],
      (context, ref) =>
          scanGalleryForTripPhotos(context, ref, 'trip-1', _trip()),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Add dives first to link photos'), findsOneWidget);
  });

  testWidgets('scanGalleryForTripPhotos reports denied photo access', (
    tester,
  ) async {
    final dive = Dive(id: 'd1', dateTime: DateTime(2026, 3, 26, 10));
    await pumpActionButton(
      tester,
      [
        divesForTripProvider('trip-1').overrideWith((ref) async => [dive]),
        mediaForTripProvider('trip-1').overrideWith((ref) async => {}),
        photoPickerServiceProvider.overrideWithValue(_DeniedPicker()),
      ],
      (context, ref) =>
          scanGalleryForTripPhotos(context, ref, 'trip-1', _trip()),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Photo library access denied'), findsOneWidget);
  });

  testWidgets('scanLightroomForTrip asks to add dives first when empty', (
    tester,
  ) async {
    await pumpActionButton(tester, [
      divesForTripProvider('trip-1').overrideWith((ref) async => <Dive>[]),
    ], (context, ref) => scanLightroomForTrip(context, ref, 'trip-1'));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Add dives first to link photos'), findsOneWidget);
  });
}
