import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_sort_sheet.dart';
import 'package:submersion/features/settings/data/repositories/app_settings_repository.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsRepository extends AppSettingsRepository {
  _FakeSettingsRepository() {
    // Not awaited: closing a single-subscription controller that never had a
    // listener returns a future that never completes, and the table-mode
    // sheet rightly never starts the notifier that would listen.
    addTearDown(() => unawaited(settingsTicks.close()));
  }

  EquipmentArrangement? stored;
  int reads = 0;
  final List<EquipmentArrangement> written = [];
  final StreamController<void> settingsTicks = StreamController<void>();

  /// When set, writes wait until the test completes them, so several taps
  /// can land while an earlier write is still in flight.
  bool holdWrites = false;
  final List<Completer<void>> heldWrites = [];

  @override
  Future<EquipmentArrangement?> getEquipmentArrangement() async {
    reads++;
    return stored;
  }

  @override
  Future<void> setEquipmentArrangement(EquipmentArrangement arrangement) async {
    if (holdWrites) {
      final gate = Completer<void>();
      heldWrites.add(gate);
      await gate.future;
    }
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
    EquipmentArrangement? stored,
  }) async {
    // Tall enough that the grouping controls and every sort field fit, so
    // the tests read what the sheet offers rather than how it scrolls.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    fake = _FakeSettingsRepository()..stored = stored;
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

  testWidgets('a direction and a field picked in one frame both survive', (
    tester,
  ) async {
    // The sheet stays open, and its callbacks outlive the build they came
    // from. Two taps before the next frame must each build on the sort as
    // it is now, not on the one the sheet last rendered.
    await pumpSheet(tester);

    await tester.tap(find.byIcon(SortDirection.descending.icon).first);
    await tester.tap(find.text('Service Due'));
    await tester.pumpAndSettle();

    expect(
      container.read(equipmentSortProvider),
      const SortState(
        field: EquipmentSortField.serviceDue,
        direction: SortDirection.descending,
      ),
    );
  });

  testWidgets('the type-order arrow reverses the headings (toe to head)', (
    tester,
  ) async {
    // The second descending segment belongs to "Order types by"; it reverses
    // the headings without touching the item direction in the header.
    await pumpSheet(tester);

    await tester.tap(find.byIcon(SortDirection.descending.icon).last);
    await tester.pumpAndSettle();

    expect(fake.written.single.typeOrderDescending, isTrue);
    expect(
      container.read(equipmentSortProvider).direction,
      SortDirection.ascending,
    );
  });

  testWidgets('the grouping switch writes the shared arrangement', (
    tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Group by type'));
    await tester.pumpAndSettle();

    expect(fake.written.single.groupByType, isFalse);
  });

  testWidgets('quick changes to the grouping all survive', (tester) async {
    // The sheet stays open for several changes, but the arrangement only
    // publishes once its write lands. A second tap made while the first
    // write is in flight must build on the first change, not on the
    // arrangement the sheet last rendered, or the later write silently
    // undoes the earlier one.
    await pumpSheet(tester);
    fake.holdWrites = true;

    await tester.tap(find.text('Group by type'));
    await tester.pump();
    await tester.tap(find.text('Head to toe'));
    await tester.pump();
    while (fake.heldWrites.isNotEmpty) {
      fake.heldWrites.removeAt(0).complete();
      await tester.pumpAndSettle();
    }

    expect(fake.stored?.groupByType, isFalse);
    expect(fake.stored?.typeOrder, EquipmentTypeOrder.headToToe);
  });

  testWidgets('tapping the grouping switch twice quickly turns it back on', (
    tester,
  ) async {
    // The switch shows the saved arrangement, which only moves once a write
    // lands. Two taps before then must toggle twice, off and back on, not
    // both ask for "off".
    await pumpSheet(tester);
    fake.holdWrites = true;

    await tester.tap(find.text('Group by type'));
    await tester.pump();
    await tester.tap(find.text('Group by type'));
    await tester.pump();
    while (fake.heldWrites.isNotEmpty) {
      fake.heldWrites.removeAt(0).complete();
      await tester.pumpAndSettle();
    }

    expect(fake.written.map((a) => a.groupByType).toList(), [false, true]);
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

  testWidgets('the fields read "Then by" while types order first, even flat', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      stored: EquipmentArrangement.defaults.copyWith(groupByType: false),
    );

    expect(find.text('Then by'), findsOneWidget);
    expect(find.text('Sort by'), findsNothing);
  });

  testWidgets('the fields read "Sort by" when nothing orders the types', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      stored: EquipmentArrangement.defaults.copyWith(
        typeOrder: EquipmentTypeOrder.none,
      ),
    );

    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Then by'), findsNothing);
  });

  testWidgets('the table-mode sheet leaves the grouping out', (tester) async {
    // The table stays flat with its own column sort, so grouping controls
    // there would do nothing visible.
    await pumpSheet(tester, showGrouping: false);

    expect(find.text('Group by type'), findsNothing);
    expect(find.text('Order types by'), findsNothing);
    expect(find.text('Sort by'), findsOneWidget);
    expect(find.text('Service Due'), findsOneWidget);
    // The table never uses the arrangement, so its sheet must not start
    // the arrangement notifier's settings read and subscription either.
    expect(fake.reads, 0);
  });
}
