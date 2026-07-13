import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides, ...extra].cast(),
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
  testWidgets('scanForTripDives explains when there is no diver', (
    tester,
  ) async {
    await pumpActionButton(
      tester,
      const [],
      (context, ref) => scanForTripDives(context, ref, _trip()),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    // No scan runs, but the user gets feedback instead of a silent no-op.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Assign a diver to this trip to scan for dives'),
      findsOneWidget,
    );
  });

  testWidgets('scanForTripDives shows a no-matches snackbar', (tester) async {
    await pumpActionButton(tester, [
      tripRepositoryProvider.overrideWithValue(_NoCandidatesRepo()),
    ], (context, ref) => scanForTripDives(context, ref, _trip(diverId: 'd1')));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('No matching dives found'), findsOneWidget);
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
