import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/geofence_editor_sheet.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  DiveSite site() => const DiveSite(
    id: 'site-1',
    name: 'Breakwater',
    location: GeoPoint(36.62, -121.90),
  );

  testWidgets('save is disabled until a center is chosen', (tester) async {
    final overrides = await getBaseOverrides();
    overrides.add(sitesProvider.overrideWith((ref) async => <DiveSite>[]));

    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showGeofenceEditor(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save geofence'),
    );
    expect(saveButton.onPressed, isNull, reason: 'disabled without a center');
  });

  testWidgets('choosing a site anchors the center and enables save', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    overrides.add(sitesProvider.overrideWith((ref) async => [site()]));

    GeofenceDraft? result;
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              result = await showGeofenceEditor(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Pick the site from the dropdown; its coordinates become the center.
    await tester.tap(find.text('From dive site'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Breakwater').last);
    await tester.pumpAndSettle();

    // Center coordinates are now displayed and save is enabled.
    expect(find.textContaining('36.62000'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save geofence'),
    );
    expect(saveButton.onPressed, isNotNull);

    // Adjust the radius slider, then save and capture the returned draft.
    await tester.drag(find.byType(Slider), const Offset(40, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save geofence'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.latitude, 36.62);
    expect(result!.longitude, -121.90);
    // Label auto-seeded from the site name.
    expect(result!.label, 'Breakwater');
  });

  testWidgets('seeds fields from an initial geofence draft', (tester) async {
    final overrides = await getBaseOverrides();
    overrides.add(sitesProvider.overrideWith((ref) async => <DiveSite>[]));

    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showGeofenceEditor(
              context,
              initial: const GeofenceDraft(
                latitude: 10.0,
                longitude: 20.0,
                label: 'Seeded',
                radiusMeters: 30000,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // The seeded center makes save immediately available.
    expect(find.textContaining('10.00000'), findsOneWidget);
    expect(find.text('Seeded'), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save geofence'),
    );
    expect(saveButton.onPressed, isNotNull);
  });
}
