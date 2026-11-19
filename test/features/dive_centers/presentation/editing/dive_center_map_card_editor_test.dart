import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/location_service_provider.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_cards.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_card_ids.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_fields.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_map_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// The dive centre Map card's editor (issue #4527, phase 3).
void main() {
  DiveCenter centre() => DiveCenter(
    id: 'dc1',
    name: 'Reef Divers',
    createdAt: DateTime(2020),
    updatedAt: DateTime(2020),
  );

  testWidgets('pick from map sets the coordinates', (tester) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = EditSession(centre());
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(
          body: SingleChildScrollView(
            child: DiveCenterMapCardEditor(
              session: session,
              pickLocation: (context, initial) async => const PickedLocation(
                latitude: 28.5,
                longitude: 34.5,
                place: PlaceLookup.empty(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dive-center-edit-pick-map')));
    await tester.pumpAndSettle();

    expect(session.valueOf(diveCenterCoordinatesField), (
      latitude: 28.5,
      longitude: 34.5,
    ));
    expect(session.changedCardIds, {'map'});
  });

  test('out of range coordinates are invalid', () {
    final session = EditSession(centre())
      ..set(diveCenterCoordinatesField, (latitude: 91.0, longitude: 0.0));
    final card = diveCenterEditCards[DiveCenterCardId.map]!;
    expect(card.isValid!(session), isFalse);
    session.set(diveCenterCoordinatesField, (latitude: 45.0, longitude: 0.0));
    expect(card.isValid!(session), isTrue);
    session.dispose();
  });

  testWidgets('an unreadable longitude names the longitude', (tester) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = EditSession(centre());
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(
          body: SingleChildScrollView(
            child: DiveCenterMapCardEditor(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '28.5');
    await tester.enterText(fields.at(1), 'abc');
    await tester.pumpAndSettle();

    final l = AppLocalizationsEn();
    // Said once, under the field, as the site card says it.
    expect(find.text(l.common_coordinates_invalidLongitude), findsOneWidget);
    expect(find.text(l.common_coordinates_invalidLatitude), findsNothing);
    expect(session.isDirty, isFalse);
  });

  testWidgets('half a position says once which half is missing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = EditSession(centre());
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(
          body: SingleChildScrollView(
            child: DiveCenterMapCardEditor(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '28.5');
    await tester.pumpAndSettle();

    final l = AppLocalizationsEn();
    expect(find.text(l.common_coordinates_longitudeRequired), findsOneWidget);
    expect(find.text(l.common_coordinates_invalidLongitude), findsNothing);
    expect(session.isDirty, isFalse);
  });

  testWidgets('unreadable text marks the Map card invalid for the page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = RecordEditController<DiveCenter>(onSave: (_) async {})
      ..unlock(centre());
    addTearDown(controller.dispose);
    final session = controller.session!;
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: RecordEditScope<DiveCenter>(
          controller: controller,
          child: Scaffold(
            body: SingleChildScrollView(
              child: DiveCenterMapCardEditor(session: session),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.invalidCardIds, isEmpty);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '28.5');
    await tester.enterText(fields.at(1), 'abc');
    await tester.pumpAndSettle();

    expect(controller.invalidCardIds, {'map'});

    await tester.enterText(fields.at(1), '34.5');
    await tester.pumpAndSettle();
    expect(controller.invalidCardIds, isEmpty);
  });

  testWidgets('a lookup for an address changed meanwhile sets nothing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = EditSession(
      DiveCenter(
        id: 'dc1',
        name: 'Reef Divers',
        city: 'Dahab',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
    addTearDown(session.dispose);
    final locations = _SlowLocations();
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          locationServiceProvider.overrideWithValue(locations),
        ],
        child: Scaffold(
          body: SingleChildScrollView(
            child: DiveCenterMapCardEditor(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l = AppLocalizationsEn();
    await tester.tap(find.text(l.diveCenters_action_lookupFromAddress));
    await tester.pump();
    session.set(diveCenterCityField, 'Sharm');

    locations.answer.complete();
    await tester.pumpAndSettle();
    expect(session.isSettled, isTrue);
    expect(session.valueOf(diveCenterCoordinatesField), isNull);
  });

  testWidgets('a pick clears the error left by unreadable text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = EditSession(centre());
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(
          body: SingleChildScrollView(
            child: DiveCenterMapCardEditor(
              session: session,
              pickLocation: (context, initial) async => const PickedLocation(
                latitude: 28.5,
                longitude: 34.5,
                place: PlaceLookup.empty(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '1');
    await tester.enterText(fields.at(1), 'abc');
    await tester.pumpAndSettle();
    final l = AppLocalizationsEn();
    expect(find.text(l.common_coordinates_invalidLongitude), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('dive-center-edit-pick-map')));
    await tester.pumpAndSettle();

    expect(find.text(l.common_coordinates_invalidLongitude), findsNothing);
  });

  testWidgets('Save waits for a lookup asked for on the card', (tester) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = EditSession(
      DiveCenter(
        id: 'dc1',
        name: 'Reef Divers',
        city: 'Dahab',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
    addTearDown(session.dispose);
    final locations = _SlowLocations();
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          locationServiceProvider.overrideWithValue(locations),
        ],
        child: Scaffold(
          body: SingleChildScrollView(
            child: DiveCenterMapCardEditor(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l = AppLocalizationsEn();
    await tester.tap(find.text(l.diveCenters_action_lookupFromAddress));
    await tester.pump();
    expect(session.isSettled, isFalse);

    locations.answer.complete();
    await tester.pumpAndSettle();
    expect(session.isSettled, isTrue);
    expect(session.valueOf(diveCenterCoordinatesField), (
      latitude: 1.0,
      longitude: 2.0,
    ));
  });

  testWidgets('a lookup that throws says it found nothing', (tester) async {
    tester.view.physicalSize = const Size(700, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final session = EditSession(
      DiveCenter(
        id: 'dc1',
        name: 'Reef Divers',
        city: 'Dahab',
        createdAt: DateTime(2020),
        updatedAt: DateTime(2020),
      ),
    );
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          locationServiceProvider.overrideWithValue(_ThrowingLocations()),
        ],
        child: Scaffold(
          body: SingleChildScrollView(
            child: DiveCenterMapCardEditor(session: session),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l = AppLocalizationsEn();
    await tester.tap(find.text(l.diveCenters_action_lookupFromAddress));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(l.diveCenters_error_geocodeFailed), findsOneWidget);
  });

  group('Use my location', () {
    Future<EditSession<DiveCenter>> pumpWith(
      WidgetTester tester,
      LocationService locations,
    ) async {
      tester.view.physicalSize = const Size(700, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = EditSession(centre());
      addTearDown(session.dispose);
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        testApp(
          overrides: [
            ...overrides,
            locationServiceProvider.overrideWithValue(locations),
          ],
          child: Scaffold(
            body: SingleChildScrollView(
              child: DiveCenterMapCardEditor(session: session),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return session;
    }

    final l = AppLocalizationsEn();

    testWidgets('sets the coordinates where the diver is', (tester) async {
      final session = await pumpWith(
        tester,
        _HereLocations(const LocationResult(latitude: 28.5, longitude: 34.5)),
      );

      await tester.tap(find.text(l.diveCenters_action_useMyLocation));
      await tester.pumpAndSettle();

      expect(session.valueOf(diveCenterCoordinatesField), (
        latitude: 28.5,
        longitude: 34.5,
      ));
    });

    testWidgets('no position says so and sets nothing', (tester) async {
      final session = await pumpWith(tester, _HereLocations(null));

      await tester.tap(find.text(l.diveCenters_action_useMyLocation));
      await tester.pumpAndSettle();

      expect(session.isDirty, isFalse);
      expect(
        find.text(l.diveCenters_error_locationUnavailable),
        findsOneWidget,
      );
    });

    testWidgets('a position that throws says so as one not found', (
      tester,
    ) async {
      final session = await pumpWith(tester, _HereLocations(null, fail: true));

      await tester.tap(find.text(l.diveCenters_action_useMyLocation));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(session.isDirty, isFalse);
      expect(
        find.text(l.diveCenters_error_locationUnavailable),
        findsOneWidget,
      );
    });
  });
}

class _HereLocations extends Fake implements LocationService {
  _HereLocations(this.here, {this.fail = false});

  final LocationResult? here;
  final bool fail;

  @override
  Future<LocationResult?> getCurrentLocation({
    bool includeGeocoding = true,
    Duration timeout = const Duration(seconds: 15),
    String languageCode = LocationService.defaultLanguageCode,
  }) async {
    if (fail) throw StateError('no fix');
    return here;
  }
}

class _ThrowingLocations extends Fake implements LocationService {
  @override
  Future<LocationResult?> forwardGeocode(String address) async =>
      throw StateError('offline');
}

class _SlowLocations extends Fake implements LocationService {
  final answer = Completer<void>();

  @override
  Future<LocationResult?> forwardGeocode(String address) async {
    await answer.future;
    return const LocationResult(latitude: 1, longitude: 2);
  }
}
