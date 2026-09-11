import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_sort_sheet.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsRepository extends AppSettingsRepository {
  _FakeSettingsRepository() {
    addTearDown(settingsTicks.close);
  }

  EquipmentArrangement? stored;
  final List<EquipmentArrangement> written = [];
  final StreamController<void> settingsTicks = StreamController<void>();

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() async => stored;

  @override
  Future<void> setEquipmentArrangement(EquipmentArrangement arrangement) async {
    written.add(arrangement);
    stored = arrangement;
  }

  @override
  Stream<void> watchSettingsChanges() => settingsTicks.stream;
}

void main() {
  late _FakeSettingsRepository fake;
  late ProviderContainer container;

  Future<void> pumpSheet(
    WidgetTester tester, {
    bool showGrouping = true,
  }) async {
    // Tall enough that the grouping controls and every sort field fit, so
    // the tests read what the sheet offers rather than how it scrolls.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    fake = _FakeSettingsRepository();
    container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(fake)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEquipmentListSortSheet(
                  context,
                  showGrouping: showGrouping,
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('offers the shared grouping controls above the sort fields', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Sort Equipment'), findsOneWidget);
    expect(find.text('Group by type'), findsOneWidget);
    expect(find.text('Order types by'), findsOneWidget);
    expect(find.text('Head to toe'), findsOneWidget);
    for (final label in ['Name', 'Purchase Date', 'Last Service']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Service Due'), findsOneWidget);
  });

  testWidgets('does not offer Type, which "Order types by" now owns', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Type'), findsNothing);
  });

  testWidgets('picking a field sorts the list and keeps the sheet open', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Service Due'));
    await tester.pumpAndSettle();

    expect(
      container.read(equipmentSortProvider).field,
      EquipmentSortField.serviceDue,
    );
    // Several axes live in one sheet, so a pick must not dismiss it.
    expect(find.text('Group by type'), findsOneWidget);
  });

  testWidgets('the header arrow sets the item direction', (tester) async {
    await pumpSheet(tester);

    // The header toggle is the first descending segment; the second belongs
    // to the type order.
    await tester.tap(find.byIcon(SortDirection.descending.icon).first);
    await tester.pumpAndSettle();

    expect(
      container.read(equipmentSortProvider),
      const SortState(
        field: EquipmentSortField.name,
        direction: SortDirection.descending,
      ),
    );
    expect(fake.written, isEmpty, reason: 'the type axis was not touched');
  });

  testWidgets('the grouping switch writes the shared arrangement', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Group by type'));
    await tester.pumpAndSettle();

    expect(fake.written.single.groupByType, isFalse);
  });

  testWidgets('the current field carries the check mark', (tester) async {
    await pumpSheet(tester);

    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Name'),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('the close button dismisses the sheet', (tester) async {
    // A pick no longer closes the sheet and it opens near full height, so
    // without this there is no obvious way out on a phone with no back key.
    await pumpSheet(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Sort Equipment'), findsNothing);
  });

  testWidgets('the table-mode sheet leaves the grouping out', (tester) async {
    // The table stays flat with its own column sort, so grouping controls
    // there would do nothing visible.
    await pumpSheet(tester, showGrouping: false);

    expect(find.text('Group by type'), findsNothing);
    expect(find.text('Order types by'), findsNothing);
    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Service Due'), findsOneWidget);
  });
}
