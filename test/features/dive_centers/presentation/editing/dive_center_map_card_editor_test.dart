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
    expect(find.text(l.diveCenters_validation_invalidLongitude), findsWidgets);
    expect(find.text(l.diveCenters_validation_invalidLatitude), findsNothing);
    expect(session.isDirty, isFalse);
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
    expect(find.text(l.diveCenters_validation_invalidLongitude), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('dive-center-edit-pick-map')));
    await tester.pumpAndSettle();

    expect(find.text(l.diveCenters_validation_invalidLongitude), findsNothing);
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
}

class _ThrowingLocations extends Fake implements LocationService {
  @override
  Future<LocationResult?> forwardGeocode(String address) async =>
      throw StateError('offline');
}
