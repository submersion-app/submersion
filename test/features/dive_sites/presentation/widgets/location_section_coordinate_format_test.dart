import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/location_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/coordinate_input.dart';

void main() {
  late TextEditingController latitude;
  late TextEditingController longitude;
  late TextEditingController altitude;

  setUp(() {
    latitude = TextEditingController();
    longitude = TextEditingController();
    altitude = TextEditingController();
  });

  tearDown(() {
    latitude.dispose();
    longitude.dispose();
    altitude.dispose();
  });

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );

  Widget section(CoordinateFormat format) => LocationSection(
    expanded: true,
    onToggle: () {},
    summary: '',
    isEmpty: false,
    latitudeController: latitude,
    longitudeController: longitude,
    coordinateFormat: format,
    altitudeController: altitude,
    latValidator: (_) => null,
    lonValidator: (_) => null,
    altitudeValidator: (_) => null,
    isGettingLocation: false,
    onUseMyLocation: () {},
    onPickFromMap: () {},
    units: const UnitFormatter(AppSettings()),
  );

  testWidgets('renders the stored coordinate in the active format', (
    tester,
  ) async {
    latitude.text = '20.361944';
    longitude.text = '-87.029722';

    await tester.pumpWidget(host(section(CoordinateFormat.mgrs)));

    final input = tester.widget<CoordinateInput>(find.byType(CoordinateInput));
    expect(input.format, CoordinateFormat.mgrs);
    expect(find.text('16Q DH 96898 51535'), findsOneWidget);
  });

  testWidgets('a grid reference typed in MGRS lands in the controllers as '
      'decimal degrees', (tester) async {
    await tester.pumpWidget(host(section(CoordinateFormat.mgrs)));

    await tester.enterText(
      find.descendant(
        of: find.byType(CoordinateInput),
        matching: find.byType(TextFormField),
      ),
      '16Q DH 96898 51535',
    );
    await tester.pump();

    // The whole feature rests on this: the diver types a grid reference and
    // the form holds decimal degrees to store.
    expect(double.parse(latitude.text), closeTo(20.361944, 2e-5));
    expect(double.parse(longitude.text), closeTo(-87.029722, 2e-5));
  });

  testWidgets('switching format re-renders the same stored position', (
    tester,
  ) async {
    latitude.text = '20.361944';
    longitude.text = '-87.029722';

    await tester.pumpWidget(host(section(CoordinateFormat.decimalDegrees)));
    expect(find.text('20.361944'), findsOneWidget);

    await tester.pumpWidget(
      host(section(CoordinateFormat.degreesMinutesSeconds)),
    );
    await tester.pump();

    // Same stored position, different notation: 20 degrees 21 minutes 43.0
    // seconds. The controllers are untouched by the re-render.
    expect(find.text('43.0'), findsOneWidget);
    expect(latitude.text, '20.361944');
  });

  testWidgets('an external location update reaches the fields', (tester) async {
    await tester.pumpWidget(host(section(CoordinateFormat.decimalDegrees)));

    // "Use my location" writes the controllers directly.
    latitude.text = '17.315833';
    longitude.text = '-87.535000';
    await tester.pump();

    expect(find.text('17.315833'), findsOneWidget);
  });
}
