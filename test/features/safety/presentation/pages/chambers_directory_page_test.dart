import 'package:flutter/material.dart'
    show Locale, MaterialApp, Size, TextField;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/entities/chamber_listing.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';
import 'package:submersion/features/safety/presentation/pages/chambers_directory_page.dart';
import 'package:submersion/features/safety/presentation/providers/emergency_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

ChamberListing _listing({
  required String id,
  required String name,
  required String country,
  String? city,
  double? distanceMeters,
}) {
  return ChamberListing(
    chamber: EmergencyChamber(
      id: id,
      name: name,
      country: country,
      city: city,
      phone: '+1-555-0100',
      lastVerified: DateTime.utc(2026, 8, 1),
      isBuiltIn: true,
    ),
    distanceMeters: distanceMeters,
  );
}

void main() {
  final listings = [
    _listing(
      id: 'us-duke',
      name: 'Duke Center for Hyperbaric Medicine',
      country: 'US',
      city: 'Durham, NC',
      distanceMeters: 12000,
    ),
    _listing(
      id: 'mt-gozo',
      name: 'Gozo General Hospital Hyperbaric Unit',
      country: 'MT',
      city: 'Victoria, Gozo',
    ),
    _listing(
      id: 'eg-sharm',
      name: 'Sharm el-Sheikh Hyperbaric Medical Center',
      country: 'EG',
      city: 'Sharm el-Sheikh',
    ),
  ];

  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          chamberListingsProvider.overrideWith((ref) async => listings),
        ],
        child: const MaterialApp(
          // Pinned: the assertions match English strings.
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChambersDirectoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lists every chamber', (tester) async {
    await pump(tester);

    expect(find.textContaining('Duke Center'), findsOneWidget);
    expect(find.textContaining('Gozo General'), findsOneWidget);
    expect(find.textContaining('Sharm el-Sheikh Hyperbaric'), findsOneWidget);
    expect(find.text('3 chambers'), findsOneWidget);
  });

  testWidgets('filters by name', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'gozo');
    await tester.pumpAndSettle();

    expect(find.textContaining('Gozo General'), findsOneWidget);
    expect(find.textContaining('Duke Center'), findsNothing);
    expect(find.text('1 chamber'), findsOneWidget);
  });

  testWidgets('filters by city', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'durham');
    await tester.pumpAndSettle();

    expect(find.textContaining('Duke Center'), findsOneWidget);
    expect(find.textContaining('Sharm'), findsNothing);
  });

  testWidgets('filters by country code', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'eg');
    await tester.pumpAndSettle();

    expect(find.textContaining('Sharm el-Sheikh Hyperbaric'), findsOneWidget);
    expect(find.textContaining('Gozo General'), findsNothing);
  });

  testWidgets('shows an empty state when nothing matches', (tester) async {
    await pump(tester);

    await tester.enterText(find.byType(TextField), 'atlantis');
    await tester.pumpAndSettle();

    expect(find.text('No chamber matches that search.'), findsOneWidget);
  });

  testWidgets('shows the distance when the diver position is known', (
    tester,
  ) async {
    await pump(tester);

    expect(find.textContaining('12 km'), findsOneWidget);
  });

  testWidgets('shows a localized message when the directory fails to load', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          chamberListingsProvider.overrideWith(
            (ref) async => throw Exception('boom'),
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ChambersDirectoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('went wrong'), findsOneWidget);
  });
}
