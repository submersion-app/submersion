import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/dashboard/presentation/panels/coming_due_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/gear_service_panel.dart';
import 'package:submersion/features/dashboard/presentation/panels/next_trip_panel.dart';
import 'package:submersion/features/dashboard/presentation/providers/gauge_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_data.dart';
import 'package:submersion/features/dashboard/presentation/providers/home_panel_providers.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/presentation/document_l10n.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_schedule.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import 'panel_harness.dart';

ServiceClockStatus _clock(ServiceClockSeverity severity, {DateTime? due}) =>
    ServiceClockStatus(
      schedule: ServiceSchedule(
        id: 's',
        equipmentId: 'e',
        serviceKindId: 'k',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      kind: ServiceKind(
        id: 'k',
        name: 'Annual',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
      anchor: DateTime(2026),
      dueDate: due,
      severity: severity,
      now: DateTime.now(),
    );

final _trip = Trip(
  id: 't1',
  name: 'Bonaire',
  startDate: DateTime.now().add(const Duration(days: 23)),
  endDate: DateTime.now().add(const Duration(days: 30)),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('gear service', () {
    testWidgets('names each item with its time left, overdue first', (
      tester,
    ) async {
      final nav = await pumpPanel(
        tester,
        const GearServicePanel(),
        overrides: [
          homeGearServiceProvider.overrideWith(
            (ref) async => [
              GearServiceBar(
                itemId: 'reg',
                itemName: 'Regulator, Apeks XTX50',
                status: _clock(ServiceClockSeverity.overdue),
                fraction: 1,
              ),
              GearServiceBar(
                itemId: 'bcd',
                itemName: 'BCD',
                status: _clock(
                  ServiceClockSeverity.ok,
                  due: DateTime.now().add(const Duration(days: 40, hours: 1)),
                ),
                fraction: 0.4,
              ),
            ],
          ),
        ],
      );
      expect(find.text('Regulator, Apeks XTX50'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('40 d'), findsOneWidget);
      await tester.tap(find.byType(GearServicePanel));
      await tester.pumpAndSettle();
      expect(nav.location, startsWith('/equipment'));
    });

    testWidgets('with nothing due, a tap opens all the gear, not a '
        'due-soon list that would be empty', (tester) async {
      final nav = await pumpPanel(
        tester,
        const GearServicePanel(),
        overrides: [
          homeGearServiceProvider.overrideWith(
            (ref) async => [
              GearServiceBar(
                itemId: 'bcd',
                itemName: 'BCD',
                status: _clock(
                  ServiceClockSeverity.ok,
                  due: DateTime.now().add(const Duration(days: 200)),
                ),
                fraction: 0.4,
              ),
            ],
          ),
        ],
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(GearServicePanel)),
      );
      // A filter left over from the equipment list must not hide the gear.
      container.read(equipmentFilterProvider.notifier).state =
          const EquipmentFilterState(serviceDue: ServiceDueFilter.dueSoon);
      await tester.tap(find.byType(GearServicePanel));
      await tester.pumpAndSettle();
      expect(nav.location, '/equipment');
      expect(container.read(equipmentFilterProvider).serviceDue, isNull);
    });

    testWidgets('with no gear it offers to add some', (tester) async {
      final nav = await pumpPanel(
        tester,
        const GearServicePanel(),
        overrides: [
          homeGearServiceProvider.overrideWith((ref) async => []),
          homeHasGearProvider.overrideWith((ref) async => false),
        ],
      );
      expect(find.text('Add gear to track its service'), findsOneWidget);
      await tester.tap(find.byType(GearServicePanel));
      await tester.pumpAndSettle();
      expect(nav.location, '/equipment/new');
    });

    testWidgets('gear with no service schedule is not told to add gear', (
      tester,
    ) async {
      final nav = await pumpPanel(
        tester,
        const GearServicePanel(),
        overrides: [
          homeGearServiceProvider.overrideWith((ref) async => []),
          homeHasGearProvider.overrideWith((ref) async => true),
        ],
      );
      expect(find.text('Add gear to track its service'), findsNothing);
      expect(find.text('No service clocks'), findsOneWidget);
      await tester.tap(find.byType(GearServicePanel));
      await tester.pumpAndSettle();
      expect(nav.location, '/equipment');
    });

    testWidgets('says nothing to a screen reader while loading', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPanel(
        tester,
        const GearServicePanel(),
        overrides: [
          homeGearServiceProvider.overrideWith(
            (ref) => Completer<List<GearServiceBar>>().future,
          ),
          homeHasGearProvider.overrideWith((ref) async => false),
        ],
      );
      expect(find.bySemanticsLabel('Gear service'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a long gear name stays on one line at phone width', (
      tester,
    ) async {
      await pumpPanel(
        tester,
        const GearServicePanel(),
        width: 360,
        overrides: [
          homeGearServiceProvider.overrideWith(
            (ref) async => [
              GearServiceBar(
                itemId: 'x',
                itemName:
                    'A regulator with an extremely long descriptive name indeed',
                status: _clock(ServiceClockSeverity.dueSoon),
                fraction: 0.9,
              ),
            ],
          ),
        ],
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('coming due', () {
    testWidgets('lists items soonest first and opens one', (tester) async {
      final nav = await pumpPanel(
        tester,
        const ComingDuePanel(),
        overrides: [
          homeComingDueProvider.overrideWith(
            (ref) async => [
              ComingDueItem(
                kind: ComingDueKind.certification,
                id: 'c1',
                name: 'Nitrox',
                due: DateTime(2026, 12, 1),
              ),
              ComingDueItem(
                kind: ComingDueKind.insurance,
                id: null,
                name: 'DAN',
                due: DateTime(2027, 3, 14),
              ),
            ],
          ),
        ],
      );
      expect(find.text('Nitrox'), findsOneWidget);
      expect(find.text('DAN'), findsOneWidget);
      await tester.tap(find.text('DAN'));
      await tester.pumpAndSettle();
      expect(nav.location, '/documents?type=insurance');
    });

    testWidgets('an untitled document goes by its type', (tester) async {
      await pumpPanel(
        tester,
        const ComingDuePanel(),
        overrides: [
          homeComingDueProvider.overrideWith(
            (ref) async => [
              ComingDueItem(
                kind: ComingDueKind.document,
                id: 'd1',
                name: '',
                due: DateTime(2027, 3, 14),
                documentType: DocumentType.permit,
              ),
            ],
          ),
        ],
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.text(documentTypeLabel(l10n, DocumentType.permit)),
        findsOneWidget,
      );
    });

    testWidgets('an item due today is not drawn as lapsed', (tester) async {
      final now = DateTime.now();
      await pumpPanel(
        tester,
        const ComingDuePanel(),
        overrides: [
          homeComingDueProvider.overrideWith(
            (ref) async => [
              ComingDueItem(
                kind: ComingDueKind.certification,
                id: 'old',
                name: 'Lapsed',
                due: DateTime(now.year, now.month, now.day - 1),
              ),
              ComingDueItem(
                kind: ComingDueKind.document,
                id: 'p',
                name: 'Passport',
                due: DateTime(now.year, now.month, now.day),
                documentType: DocumentType.permit,
              ),
            ],
          ),
        ],
      );
      final error = Theme.of(
        tester.element(find.byType(ComingDuePanel)),
      ).colorScheme.error;
      Color? iconColor(IconData icon) =>
          tester.widget<Icon>(find.byIcon(icon)).color;
      expect(iconColor(Icons.card_membership_outlined), error);
      expect(iconColor(Icons.folder_copy_outlined), isNot(error));
    });

    testWidgets('says nothing to a screen reader while loading', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpPanel(
        tester,
        const ComingDuePanel(),
        overrides: [
          homeComingDueProvider.overrideWith(
            (ref) => Completer<List<ComingDueItem>>().future,
          ),
        ],
      );
      expect(find.bySemanticsLabel('Coming due'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('nothing due says so', (tester) async {
      await pumpPanel(
        tester,
        const ComingDuePanel(),
        overrides: [homeComingDueProvider.overrideWith((ref) async => [])],
      );
      expect(find.text('Nothing due in the next year'), findsOneWidget);
    });
  });

  group('next trip', () {
    testWidgets('shows the trip, countdown and checklist', (tester) async {
      final nav = await pumpPanel(
        tester,
        const NextTripPanel(),
        overrides: [
          dashboardGaugesProvider.overrideWith(
            (ref) async => DashboardGauges(
              hasGear: true,
              insurance: null,
              noFlyStatus: null,
              daysSinceLastDive: null,
              nextTrip: _trip,
            ),
          ),
          homeTripChecklistProvider.overrideWith(
            (ref) async => (trip: _trip, done: 6, total: 14),
          ),
        ],
      );
      expect(find.text('Bonaire'), findsOneWidget);
      expect(find.textContaining('6 / 14'), findsOneWidget);
      await tester.tap(find.byType(NextTripPanel));
      await tester.pumpAndSettle();
      expect(nav.location, '/trips/t1');
    });

    testWidgets('builds nothing without a trip', (tester) async {
      await pumpPanel(
        tester,
        const NextTripPanel(),
        overrides: [
          dashboardGaugesProvider.overrideWith(
            (ref) async => const DashboardGauges(
              hasGear: true,
              insurance: null,
              noFlyStatus: null,
              daysSinceLastDive: null,
            ),
          ),
          homeTripChecklistProvider.overrideWith((ref) async => null),
        ],
      );
      expect(find.text('NEXT TRIP'), findsNothing);
    });
  });
}
