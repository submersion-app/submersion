import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' show Intl;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/entities/reef_protection.dart';
import 'package:submersion/features/reef/domain/entities/reef_snapshot.dart';
import 'package:submersion/features/reef/domain/services/bleaching_alert_level.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/l10n_test_helpers.dart';

const _location = GeoPoint(12.16, -68.28);

ReefSnapshot _snapshot({
  ReefPart<ReefHabitat> habitat = const ReefPart.empty(),
  ReefPart<ReefHealth>? health,
  ReefPart<List<ReefProtection>> protection = const ReefPart.empty(),
}) => ReefSnapshot(
  habitat: habitat,
  health: health ?? const ReefPart.unavailable(),
  protection: protection,
  species: const ReefPart.empty(),
);

Widget _harness(ReefSnapshot snapshot, {WaterType? waterType}) {
  final request = ReefSnapshotRequest(
    location: _location,
    fetchHealth: waterType != WaterType.fresh,
  );
  return ProviderScope(
    overrides: [
      reefSnapshotProvider(request).overrideWith((ref) async => snapshot),
      // WaterConditionsCard reads the diver's unit setting, which chains
      // through settingsProvider to SharedPreferences. Overriding at the
      // narrowest point severs that chain without mocking preferences.
      temperatureUnitProvider.overrideWithValue(TemperatureUnit.celsius),
    ],
    child: localizedMaterialApp(
      locale: const Locale('en'),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReefSection(location: _location, waterType: waterType),
        ),
      ),
    ),
  );
}

void main() {
  // WaterConditionsCard formats the observation date with DateFormat.yMMMd(),
  // which resolves against intl's process-global default locale. Pin it so
  // the expected month names do not depend on the test host's locale.
  String? previousDefaultLocale;

  setUp(() {
    previousDefaultLocale = Intl.defaultLocale;
    Intl.defaultLocale = 'en_US';
  });

  tearDown(() {
    Intl.defaultLocale = previousDefaultLocale;
  });

  testWidgets('shows habitat threat level when on a reef', (tester) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          habitat: const ReefPart.ok(
            ReefHabitat(onReef: true, threatLevel: 'High'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('High'), findsOneWidget);
  });

  testWidgets('always shows degree heating weeks beside the alert level', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          habitat: const ReefPart.ok(ReefHabitat(onReef: true)),
          health: ReefPart.ok(
            ReefHealth(
              sst: 30.1,
              degreeHeatingWeeks: 15.64,
              hotspot: 0.91,
              alertLevel: BleachingAlertLevel.watch,
              observedAt: DateTime.utc(2023, 9, 1, 12),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The trap this guards: a reassuring level over a dying reef.
    expect(find.textContaining('15.6'), findsOneWidget);
    expect(find.textContaining('Bleaching watch'), findsOneWidget);
  });

  testWidgets('titles the section Ecosystem', (tester) async {
    await tester.pumpWidget(_harness(_snapshot()));
    await tester.pumpAndSettle();

    expect(find.text('Ecosystem'), findsOneWidget);
    expect(find.text('Reef'), findsNothing);
  });

  testWidgets('hides the habitat row when the site is not on a reef', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_snapshot()));
    await tester.pumpAndSettle();

    expect(find.textContaining('No mapped coral reef'), findsNothing);
    expect(find.textContaining('Reef habitat'), findsNothing);
  });

  testWidgets('keeps the habitat row when the check failed', (tester) async {
    await tester.pumpWidget(
      _harness(_snapshot(habitat: const ReefPart.unavailable())),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Could not check reef habitat'), findsOneWidget);
  });

  testWidgets('shows the freshwater message for freshwater sites', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_snapshot(), waterType: WaterType.fresh));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Satellite water temperature covers oceans only'),
      findsOneWidget,
    );
  });

  testWidgets('suppresses stress lines at a confirmed non-reef site', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          health: ReefPart.ok(
            ReefHealth(
              sst: 14.2,
              sstAnomaly: 0.3,
              degreeHeatingWeeks: 0.0,
              hotspot: -0.5,
              alertLevel: BleachingAlertLevel.noStress,
              observedAt: DateTime.utc(2026, 8, 1, 12),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('14.2'), findsOneWidget);
    expect(find.textContaining('stress'), findsNothing);
    expect(find.textContaining('Degree Heating'), findsNothing);
  });

  testWidgets('distinguishes not-protected from could-not-check', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_snapshot()));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Not in a marine protected area'),
      findsOneWidget,
    );

    await tester.pumpWidget(
      _harness(_snapshot(protection: const ReefPart.unavailable())),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not check'), findsWidgets);
  });

  // NOAA publishes one composite per UTC day at 12:00Z. Formatting in local
  // time would report a date the dataset never had at the extremes of the
  // timezone range.
  testWidgets('reports the observation date in UTC, not local time', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          habitat: const ReefPart.ok(ReefHabitat(onReef: true)),
          health: ReefPart.ok(
            ReefHealth(
              degreeHeatingWeeks: 1.2,
              hotspot: 0.2,
              alertLevel: BleachingAlertLevel.watch,
              observedAt: DateTime.utc(2026, 7, 23, 12),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Jul 23, 2026'), findsOneWidget);
    expect(find.textContaining('Jul 24, 2026'), findsNothing);
    expect(find.textContaining('Jul 22, 2026'), findsNothing);
  });

  // navigatorLink is remote data; a malformed value must not produce a button
  // that throws when tapped.
  testWidgets('omits the regulations button for an unparseable link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          protection: const ReefPart.ok([
            ReefProtection(
              siteName: 'Somewhere',
              navigatorLink: ':::not a url',
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Somewhere'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'View regulations'), findsNothing);
  });

  testWidgets('renders the regulations button for a valid link', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          protection: const ReefPart.ok([
            ReefProtection(
              siteName: 'Somewhere',
              navigatorLink: 'https://navigatormap.org/site/1',
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextButton, 'View regulations'), findsOneWidget);
  });

  testWidgets('does not render ProtectedSeas activity codes', (tester) async {
    await tester.pumpWidget(
      _harness(
        _snapshot(
          protection: const ReefPart.ok([
            ReefProtection(
              siteName: 'Molasses Reef Sanctuary Preserve',
              iucnCategory: 'Ia',
              navigatorLink: 'https://navigatormap.org/site/1',
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Molasses Reef'), findsOneWidget);
    expect(find.textContaining('Ia'), findsOneWidget);
    expect(find.textContaining('Diving'), findsNothing);
    expect(find.textContaining('Anchoring'), findsNothing);
  });
}
