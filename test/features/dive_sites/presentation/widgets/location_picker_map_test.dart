import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/location_picker_map.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

Future<void> _pump(WidgetTester tester, {LatLng? initialLocation}) async {
  final base = await getBaseOverrides();
  await tester.pumpWidget(
    ProviderScope(
      overrides: base,
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LocationPickerMap(initialLocation: initialLocation),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('renders the FlutterMap with a world view when no location', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byType(FlutterMap), findsOneWidget);
    // No selection yet, so no confirm action and no location marker.
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.byIcon(Icons.location_on), findsNothing);
  });

  testWidgets('renders the FlutterMap and a marker for an initial location', (
    tester,
  ) async {
    await _pump(tester, initialLocation: const LatLng(12.34, 98.76));

    expect(find.byType(FlutterMap), findsOneWidget);
    // The selected-location marker uses a location_on glyph.
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });
}
