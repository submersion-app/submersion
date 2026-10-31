import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/transfer/presentation/widgets/inventory_report_sheet.dart';
import 'package:submersion/features/transfer/presentation/widgets/report_sheet_scaffold.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

EquipmentLocation _place(String id, {bool archived = false}) =>
    EquipmentLocation(
      id: id,
      name: id,
      kind: EquipmentLocationKind.storage,
      isArchived: archived,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  InventoryReportOptions? result;
  var closed = false;

  Future<void> open(
    WidgetTester tester, {
    List<EquipmentLocation> places = const [],
  }) async {
    result = null;
    closed = false;
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          equipmentLocationsProvider.overrideWith((ref) async => places),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await InventoryReportSheet.show(context);
                  closed = true;
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

  Future<void> finish(WidgetTester tester) async {
    await tester.tap(find.byKey(ReportSheetScaffold.continueKey));
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to gear type, all locations, prices on', (
    tester,
  ) async {
    await open(tester, places: [_place('Garage')]);
    await finish(tester);

    expect(result, const InventoryReportOptions());
  });

  testWidgets('turning prices off returns showPrices false', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(InventoryReportSheet.pricesKey));
    await tester.pumpAndSettle();
    await finish(tester);

    expect(result?.showPrices, isFalse);
  });

  testWidgets('choosing location grouping returns it', (tester) async {
    await open(tester);
    await tester.tap(find.text('Location'));
    await tester.pumpAndSettle();
    await finish(tester);

    expect(result?.grouping, InventoryGrouping.location);
  });

  testWidgets('picking a place returns its id', (tester) async {
    await open(tester, places: [_place('Garage')]);
    await tester.tap(find.byKey(InventoryReportSheet.locationKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garage').last);
    await tester.pumpAndSettle();
    await finish(tester);

    expect(result?.locationId, 'Garage');
  });

  testWidgets('the location dropdown hides archived places', (tester) async {
    await open(
      tester,
      places: [_place('Garage'), _place('Old shed', archived: true)],
    );
    await tester.tap(find.byKey(InventoryReportSheet.locationKey));
    await tester.pumpAndSettle();

    expect(find.text('Old shed'), findsNothing);
  });

  testWidgets('with no places there is no location dropdown', (tester) async {
    await open(tester);
    expect(find.byKey(InventoryReportSheet.locationKey), findsNothing);
  });

  testWidgets('cancelling returns nothing', (tester) async {
    await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
    expect(result, isNull);
  });
}
