import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/reports/service_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/transfer/presentation/widgets/report_sheet_scaffold.dart';
import 'package:submersion/features/transfer/presentation/widgets/service_report_sheet.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Trip _trip(String name, DateTime start) => Trip(
  id: name,
  name: name,
  startDate: start,
  endDate: start,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

EquipmentItem _item(String name, {EquipmentStatus? status}) => EquipmentItem(
  id: name,
  name: name,
  type: EquipmentType.regulator,
  status: status ?? EquipmentStatus.active,
);

void main() {
  ServiceReportOptions? result;

  Future<void> open(WidgetTester tester) async {
    result = null;
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          allTripsProvider.overrideWith(
            (ref) async => [
              _trip('Old trip', DateTime(2020)),
              _trip('New trip', DateTime(2026)),
            ],
          ),
          allEquipmentProvider.overrideWith(
            (ref) async => [
              _item('Regulator'),
              _item('Retired reg', status: EquipmentStatus.retired),
              _item('Wish reg', status: EquipmentStatus.wanted),
            ],
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await ServiceReportSheet.show(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> chooseScope(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(ServiceReportSheet.gearKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  FilledButton continueButton(WidgetTester tester) =>
      tester.widget(find.byKey(ReportSheetScaffold.continueKey));

  Future<void> finish(WidgetTester tester) async {
    await tester.tap(find.byKey(ReportSheetScaffold.continueKey));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to all gear, history on, costs on', (tester) async {
    await open(tester);
    await finish(tester);

    expect(result, const ServiceReportOptions());
  });

  testWidgets('packed for a trip shows the trip picker, newest first', (
    tester,
  ) async {
    await open(tester);
    await chooseScope(tester, 'Packed for a trip');
    await tester.tap(find.byKey(ServiceReportSheet.tripKey));
    await tester.pumpAndSettle();

    final top = tester.getTopLeft(find.text('New trip').last).dy;
    final lower = tester.getTopLeft(find.text('Old trip').last).dy;
    expect(top, lessThan(lower));
  });

  testWidgets('continue stays disabled until a trip is picked', (tester) async {
    await open(tester);
    await chooseScope(tester, 'Packed for a trip');
    expect(continueButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(ServiceReportSheet.tripKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New trip').last);
    await tester.pumpAndSettle();
    await finish(tester);

    expect(
      result,
      const ServiceReportOptions(
        scope: ServiceReportScope.trip,
        tripId: 'New trip',
      ),
    );
  });

  testWidgets('continue stays disabled until an item is picked', (
    tester,
  ) async {
    await open(tester);
    await chooseScope(tester, 'One item');
    expect(continueButton(tester).onPressed, isNull);

    await tester.tap(find.byKey(ServiceReportSheet.itemKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Regulator').last);
    await tester.pumpAndSettle();
    await finish(tester);

    expect(result?.itemId, 'Regulator');
    expect(result?.tripId, isNull);
  });

  testWidgets('one item lists retired gear and hides wishlist gear', (
    tester,
  ) async {
    await open(tester);
    await chooseScope(tester, 'One item');
    await tester.tap(find.byKey(ServiceReportSheet.itemKey));
    await tester.pumpAndSettle();

    expect(find.text('Retired reg'), findsWidgets);
    expect(find.text('Wish reg'), findsNothing);
  });

  testWidgets('costs can be turned off', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(ServiceReportSheet.costsKey));
    await tester.pumpAndSettle();
    await finish(tester);

    expect(result?.showCosts, isFalse);
  });

  testWidgets('turning history off disables the costs switch', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(ServiceReportSheet.historyKey));
    await tester.pumpAndSettle();

    final costs = tester.widget<SwitchListTile>(
      find.byKey(ServiceReportSheet.costsKey),
    );
    expect(costs.onChanged, isNull);
    await finish(tester);
    expect(result?.includeHistory, isFalse);
  });
}
