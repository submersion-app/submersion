import 'package:flutter/material.dart'
    show Locale, ListTile, MaterialApp, Scaffold, Size;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/safety/domain/entities/chamber_listing.dart';
import 'package:submersion/features/safety/domain/entities/emergency_info.dart';
import 'package:submersion/features/safety/presentation/widgets/chamber_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

EmergencyChamber _chamber({
  ChamberCapability capability = ChamberCapability.divingEmergency,
  ChamberAvailability availability = ChamberAvailability.unknown,
  String phone = '+61-7-4433-1111',
  String? emergencyPhone,
}) {
  return EmergencyChamber(
    id: 'au-townsville',
    name: 'Townsville University Hospital Hyperbaric Unit',
    country: 'AU',
    city: 'Townsville, QLD',
    phone: phone,
    emergencyPhone: emergencyPhone,
    capability: capability,
    availability: availability,
    lastVerified: DateTime.utc(2026, 8, 1),
    isBuiltIn: true,
  );
}

void main() {
  Future<List<String>> pumpTile(
    WidgetTester tester, {
    required EmergencyChamber chamber,
    double? distanceMeters,
  }) async {
    final dialled = <String>[];

    await tester.binding.setSurfaceSize(const Size(500, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          // Pinned: the assertions match English strings.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ChamberTile(
              listing: ChamberListing(
                chamber: chamber,
                distanceMeters: distanceMeters,
              ),
              onCall: (number) async => dialled.add(number),
              showActions: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return dialled;
  }

  group('dialing', () {
    testWidgets('tapping a chamber dials its switchboard', (tester) async {
      final dialled = await pumpTile(tester, chamber: _chamber());

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(dialled, ['+61-7-4433-1111']);
    });

    testWidgets('the published emergency route wins over the other number', (
      tester,
    ) async {
      final dialled = await pumpTile(
        tester,
        chamber: _chamber(emergencyPhone: '+61-7-4433-2080'),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(dialled, ['+61-7-4433-2080']);
    });

    testWidgets('a hospital switchboard is a valid emergency route', (
      tester,
    ) async {
      // This looks backwards and is not. Several hospital units publish their
      // direct line for enquiries and route emergencies through the
      // switchboard, which pages the on-call hyperbaric physician; the direct
      // line rings an empty desk at 2am. `emergencyPhone` means "the route to
      // take in an emergency", not "the more specific number", so a reviewer
      // seeing a switchboard here should not swap the fields.
      final dialled = await pumpTile(
        tester,
        chamber: _chamber(
          phone: '+61-7-4433-2080', // unit's direct line, business hours
          emergencyPhone:
              '+61-7-4433-1111', // switchboard, pages the duty doctor
        ),
      );

      await tester.tap(find.byType(ListTile));
      await tester.pumpAndSettle();

      expect(dialled, ['+61-7-4433-1111']);
    });
  });

  group('capability labels', () {
    // A mismapped label here would tell a diver a wound-care clinic treats
    // diving injuries, so each value is pinned to its own string.
    const expected = {
      ChamberCapability.divingEmergency: 'Treats diving injuries',
      ChamberCapability.hyperbaricUnit: 'Hospital hyperbaric unit',
      ChamberCapability.elective: 'Elective therapy only',
      ChamberCapability.unknown: 'Capability unconfirmed',
    };

    for (final entry in expected.entries) {
      testWidgets('${entry.key.wireName} renders its own label', (
        tester,
      ) async {
        await pumpTile(tester, chamber: _chamber(capability: entry.key));

        expect(find.text(entry.value), findsOneWidget);
        for (final other in expected.entries) {
          if (other.key == entry.key) continue;
          expect(find.text(other.value), findsNothing);
        }
      });
    }
  });

  group('availability labels', () {
    const expected = {
      ChamberAvailability.h24: '24h',
      ChamberAvailability.onCall: 'On call',
      ChamberAvailability.businessHours: 'Business hours',
    };

    for (final entry in expected.entries) {
      testWidgets('${entry.key.wireName} renders its own label', (
        tester,
      ) async {
        await pumpTile(tester, chamber: _chamber(availability: entry.key));

        expect(find.text(entry.value), findsOneWidget);
      });
    }

    testWidgets('an unknown availability renders nothing at all', (
      tester,
    ) async {
      await pumpTile(
        tester,
        chamber: _chamber(availability: ChamberAvailability.unknown),
      );

      for (final label in expected.values) {
        expect(find.text(label), findsNothing);
      }
    });
  });

  testWidgets('a user-added chamber carries no capability label', (
    tester,
  ) async {
    // Capability is a claim about the bundled dataset's research. A chamber
    // the diver typed in themselves makes no such claim.
    const own = EmergencyChamber(
      id: 'mine',
      name: 'My Local Chamber',
      country: 'AU',
      phone: '+61-400-000-000',
      isBuiltIn: false,
    );
    await pumpTile(tester, chamber: own);

    expect(find.text('Capability unconfirmed'), findsNothing);
    expect(find.text('My Local Chamber'), findsOneWidget);
  });
}
