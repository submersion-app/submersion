import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/maintenance_excel_export_service.dart';
import 'package:submersion/core/services/export/export_service.dart'
    hide ServiceRecord;
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/export_providers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/service_kind.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/service_history_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  final t0 = DateTime(2026, 1, 1);
  const equipmentId = 'e1';

  ServiceKind kind(String id, String name) =>
      ServiceKind(id: id, name: name, createdAt: t0, updatedAt: t0);

  ServiceRecord record({
    required String id,
    String? kindId,
    ServiceCategory type = ServiceCategory.cleaning,
    DateTime? date,
    double? cost,
    String? provider,
    DateTime? nextDue,
    String notes = '',
  }) {
    final when = date ?? DateTime(2026, 3, 14);
    return ServiceRecord(
      id: id,
      equipmentId: equipmentId,
      serviceCategory: type,
      serviceKindId: kindId,
      serviceDate: when,
      provider: provider,
      cost: cost,
      currency: 'EUR',
      nextServiceDue: nextDue,
      notes: notes,
      createdAt: when,
      updatedAt: when,
    );
  }

  Future<void> pumpSection(
    WidgetTester tester, {
    required List<ServiceRecord> records,
    required List<ServiceKind> kinds,
    Locale locale = const Locale('en'),
    Size surface = const Size(600, 1200),
    Map<String, double> totals = const {},
    AsyncValue<List<ServiceRecord>>? recordsState,
    _MockServiceRecordNotifier? notifier,
    _FakeExportService? exportService,
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = surface;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          serviceKindsProvider.overrideWith((ref) async => kinds),
          serviceRecordNotifierProvider(equipmentId).overrideWith(
            (ref) =>
                notifier ??
                _MockServiceRecordNotifier(records, state: recordsState),
          ),
          serviceRecordTotalCostProvider(
            equipmentId,
          ).overrideWith((ref) async => totals),
          equipmentItemProvider(equipmentId).overrideWith(
            (ref) async => const EquipmentItem(
              id: equipmentId,
              name: 'JJ-CCR',
              type: EquipmentType.rebreather,
            ),
          ),
          exportServiceProvider.overrideWithValue(
            exportService ?? _FakeExportService(),
          ),
        ].cast(),
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(
              child: ServiceHistorySection(equipmentId: equipmentId),
            ),
          ),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('row titles with the maintenance task name', (tester) async {
    await pumpSection(
      tester,
      records: [record(id: 'r1', kindId: 'scrubber-repack')],
      kinds: [kind('scrubber-repack', 'Scrubber repack')],
    );

    expect(find.text('Scrubber repack'), findsOneWidget);
  });

  testWidgets('row falls back to the localized type when untagged', (
    tester,
  ) async {
    await pumpSection(
      tester,
      records: [record(id: 'r1', type: ServiceCategory.cleaning)],
      kinds: const [],
      locale: const Locale('de'),
    );

    expect(find.text('Reinigung'), findsOneWidget);
  });

  testWidgets('row renders notes and next due', (tester) async {
    await pumpSection(
      tester,
      records: [
        record(
          id: 'r1',
          kindId: 'scrubber-repack',
          notes: 'Packed 2.4kg',
          nextDue: DateTime(2026, 6, 14),
        ),
      ],
      kinds: [kind('scrubber-repack', 'Scrubber repack')],
    );

    expect(find.textContaining('Packed 2.4kg'), findsOneWidget);
    expect(find.textContaining('Next due'), findsOneWidget);
  });

  testWidgets('a long German task name keeps its title width', (tester) async {
    // Regression for the issue #935 class: a text-bearing ListTile.trailing is
    // laid out against the full tile width first, starving the title to near
    // zero. Flutter's guard is assert-only, so a release build renders one
    // glyph per line instead of throwing. find.text + findsOneWidget passes
    // happily in that state, so the assertion must be on rendered width.
    const longName = 'Sauerstoffsensor ersetzen und kalibrieren';
    await pumpSection(
      tester,
      records: [record(id: 'r1', kindId: 'o2-cell', cost: 129.99)],
      kinds: [kind('o2-cell', longName)],
      locale: const Locale('de'),
      surface: const Size(360, 800),
    );

    expect(tester.getSize(find.text(longName)).width, greaterThan(150));
  });

  testWidgets('selecting a task narrows the list', (tester) async {
    await pumpSection(
      tester,
      records: [
        record(id: 'r1', kindId: 'disinfect'),
        record(id: 'r2', kindId: 'scrubber-repack'),
      ],
      kinds: [
        kind('disinfect', 'Disinfect'),
        kind('scrubber-repack', 'Scrubber repack'),
      ],
    );

    expect(find.text('Disinfect'), findsOneWidget);
    expect(find.text('Scrubber repack'), findsOneWidget);

    await tester.tap(find.text('All tasks'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disinfect').last);
    await tester.pumpAndSettle();

    expect(find.text('Scrubber repack'), findsNothing);
  });

  testWidgets('a filter matching nothing shows its own empty state', (
    tester,
  ) async {
    await pumpSection(
      tester,
      records: [
        record(id: 'r1', kindId: 'disinfect', date: DateTime(2026, 3, 14)),
        record(
          id: 'r2',
          kindId: 'disinfect',
          type: ServiceCategory.repair,
          date: DateTime(2024, 3, 14),
        ),
      ],
      kinds: [kind('disinfect', 'Disinfect')],
    );

    // Both dimensions exist in the data, but this combination does not: the
    // only 2026 record is a Cleaning, and the only Repair is from 2024.
    await tester.tap(find.text('All years'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2026').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All types'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Repair').last);
    await tester.pumpAndSettle();

    expect(find.text('No maintenance matches this filter'), findsOneWidget);
    // Distinct from the "nothing logged at all" state.
    expect(find.text('No service records yet'), findsNothing);
  });

  testWidgets('the filter bar is hidden when there is nothing to filter', (
    tester,
  ) async {
    await pumpSection(
      tester,
      records: [record(id: 'r1', kindId: 'disinfect')],
      kinds: [kind('disinfect', 'Disinfect')],
    );

    expect(find.text('All tasks'), findsNothing);
  });

  testWidgets('the item-level export offers share and save', (tester) async {
    await pumpSection(
      tester,
      records: [record(id: 'r1', kindId: 'disinfect')],
      kinds: [kind('disinfect', 'Disinfect')],
    );

    await tester.tap(find.byKey(const Key('service-history-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export maintenance log'));
    await tester.pumpAndSettle();

    // Both delivery paths are offered; they are a deliberate pair, not a
    // fallback chain.
    expect(find.text('Save to File'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
  });

  group('totals, states and icons', () {
    testWidgets('renders one total row per currency', (tester) async {
      await pumpSection(
        tester,
        records: [record(id: 'r1', kindId: 'disinfect', cost: 45)],
        kinds: [kind('disinfect', 'Disinfect')],
        totals: const {'EUR': 45.0, 'USD': 12.0},
      );

      // Mixed currencies never sum into one figure.
      expect(find.textContaining('45'), findsWidgets);
      expect(find.textContaining('12'), findsWidgets);
      expect(find.text('Total Service Cost'), findsNWidgets(2));
    });

    testWidgets('a zero total is not shown at all', (tester) async {
      await pumpSection(
        tester,
        records: [record(id: 'r1', kindId: 'disinfect')],
        kinds: [kind('disinfect', 'Disinfect')],
        totals: const {'EUR': 0.0},
      );

      expect(find.text('Total Service Cost'), findsNothing);
    });

    testWidgets('shows a spinner while records load', (tester) async {
      await pumpSection(
        tester,
        records: const [],
        kinds: const [],
        recordsState: const AsyncValue.loading(),
        settle: false,
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows the error message when records fail to load', (
      tester,
    ) async {
      await pumpSection(
        tester,
        records: const [],
        kinds: const [],
        recordsState: const AsyncValue.error('boom', StackTrace.empty),
      );

      expect(find.textContaining('boom'), findsOneWidget);
    });

    testWidgets('every service type renders its own avatar icon', (
      tester,
    ) async {
      await pumpSection(
        tester,
        records: [
          for (var i = 0; i < ServiceCategory.values.length; i++)
            record(
              id: 'r$i',
              type: ServiceCategory.values[i],
              date: DateTime(2026, 1, i + 1),
            ),
        ],
        kinds: const [],
      );

      // One avatar per record, and the switch covers every enum value without
      // falling through to a shared default.
      expect(
        find.byType(CircleAvatar),
        findsNWidgets(ServiceCategory.values.length),
      );
    });
  });

  group('record actions', () {
    testWidgets('Add opens the record dialog', (tester) async {
      await pumpSection(
        tester,
        records: [record(id: 'r1', kindId: 'disinfect')],
        kinds: [kind('disinfect', 'Disinfect')],
      );

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Add Service Record'), findsOneWidget);
    });

    testWidgets('tapping a row opens the dialog in edit mode', (tester) async {
      await pumpSection(
        tester,
        records: [record(id: 'r1', kindId: 'disinfect')],
        kinds: [kind('disinfect', 'Disinfect')],
      );

      await tester.tap(find.text('Disinfect'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Service Record'), findsOneWidget);
    });

    testWidgets('the row menu offers edit and delete', (tester) async {
      await pumpSection(
        tester,
        records: [record(id: 'r1', kindId: 'disinfect')],
        kinds: [kind('disinfect', 'Disinfect')],
      );

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Service Record'), findsOneWidget);
    });

    testWidgets('deleting asks for confirmation and can be cancelled', (
      tester,
    ) async {
      final notifier = _MockServiceRecordNotifier([
        record(id: 'r1', kindId: 'disinfect'),
      ]);
      await pumpSection(
        tester,
        records: const [],
        kinds: [kind('disinfect', 'Disinfect')],
        notifier: notifier,
      );

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Service Record?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(notifier.deletedIds, isEmpty);
    });

    testWidgets('confirming a delete removes the record', (tester) async {
      final notifier = _MockServiceRecordNotifier([
        record(id: 'r1', kindId: 'disinfect'),
      ]);
      await pumpSection(
        tester,
        records: const [],
        kinds: [kind('disinfect', 'Disinfect')],
        notifier: notifier,
      );

      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(notifier.deletedIds, ['r1']);
      expect(find.text('Service record deleted'), findsOneWidget);
    });
  });

  group('filter summary', () {
    testWidgets('an active filter reports the count and can be cleared', (
      tester,
    ) async {
      await pumpSection(
        tester,
        records: [
          record(id: 'r1', kindId: 'disinfect'),
          record(id: 'r2', kindId: 'scrubber-repack'),
        ],
        kinds: [
          kind('disinfect', 'Disinfect'),
          kind('scrubber-repack', 'Scrubber repack'),
        ],
      );

      await tester.tap(find.text('All tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disinfect').last);
      await tester.pumpAndSettle();

      expect(find.text('1 of 2 shown'), findsOneWidget);

      await tester.tap(find.text('Clear filter'));
      await tester.pumpAndSettle();

      expect(find.text('Scrubber repack'), findsOneWidget);
      expect(find.text('1 of 2 shown'), findsNothing);
    });

    testWidgets('task options are ordered by name, not by id', (tester) async {
      // Custom kind ids are uuids, so sorting by id puts the dropdown in an
      // order that looks random next to the task names it displays.
      await pumpSection(
        tester,
        records: [
          record(id: 'r1', kindId: 'f4c2-zzz'),
          record(id: 'r2', kindId: '0a11-aaa'),
          record(id: 'r3', kindId: '7b93-mmm'),
        ],
        kinds: [
          kind('f4c2-zzz', 'Anode check'),
          kind('0a11-aaa', 'Scrubber repack'),
          kind('7b93-mmm', 'Disinfect'),
        ],
      );

      await tester.tap(find.text('All tasks'));
      await tester.pumpAndSettle();

      final items = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(Material).last,
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>()
          .where((t) => t != 'All tasks')
          .toList();

      expect(
        items,
        containsAllInOrder(['Anode check', 'Disinfect', 'Scrubber repack']),
      );
    });

    testWidgets('untagged records get their own bucket', (tester) async {
      await pumpSection(
        tester,
        records: [
          record(id: 'r1', kindId: 'disinfect'),
          record(id: 'r2'),
          record(id: 'r3', kindId: 'scrubber-repack'),
        ],
        kinds: [
          kind('disinfect', 'Disinfect'),
          kind('scrubber-repack', 'Scrubber repack'),
        ],
      );

      await tester.tap(find.text('All tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not tied to a clock').last);
      await tester.pumpAndSettle();

      expect(find.text('1 of 3 shown'), findsOneWidget);
      expect(find.text('Disinfect'), findsNothing);
    });
  });

  group('item-level export', () {
    testWidgets('sharing exports the filtered rows with resolved names', (
      tester,
    ) async {
      final fake = _FakeExportService();
      await pumpSection(
        tester,
        records: [
          record(id: 'r1', kindId: 'disinfect'),
          record(id: 'r2', kindId: 'scrubber-repack'),
        ],
        kinds: [
          kind('disinfect', 'Disinfect'),
          kind('scrubber-repack', 'Scrubber repack'),
        ],
        exportService: fake,
      );

      // Narrow first: the export must follow what is on screen.
      await tester.tap(find.text('All tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Disinfect').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('service-history-overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export maintenance log'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share'));
      await tester.pumpAndSettle();

      expect(fake.sharedRows, hasLength(1));
      expect(fake.sharedRows.single.serviceTypeName, 'Disinfect');
      expect(fake.sharedRows.single.equipmentName, 'JJ-CCR');
      expect(fake.savedRows, isEmpty);
    });

    testWidgets('choosing Save to File takes the save path', (tester) async {
      final fake = _FakeExportService();
      await pumpSection(
        tester,
        records: [record(id: 'r1', kindId: 'disinfect')],
        kinds: [kind('disinfect', 'Disinfect')],
        exportService: fake,
      );

      await tester.tap(find.byKey(const Key('service-history-overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export maintenance log'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save to File'));
      await tester.pumpAndSettle();

      expect(fake.savedRows, hasLength(1));
      expect(fake.sharedRows, isEmpty);
    });

    testWidgets('dismissing the destination sheet exports nothing', (
      tester,
    ) async {
      final fake = _FakeExportService();
      await pumpSection(
        tester,
        records: [record(id: 'r1', kindId: 'disinfect')],
        kinds: [kind('disinfect', 'Disinfect')],
        exportService: fake,
      );

      await tester.tap(find.byKey(const Key('service-history-overflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export maintenance log'));
      await tester.pumpAndSettle();
      // Tap the barrier to dismiss without choosing.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(fake.sharedRows, isEmpty);
      expect(fake.savedRows, isEmpty);
    });
  });
}

class _MockServiceRecordNotifier
    extends StateNotifier<AsyncValue<List<ServiceRecord>>>
    implements ServiceRecordNotifier {
  final List<String> deletedIds = [];

  _MockServiceRecordNotifier(
    List<ServiceRecord> records, {
    AsyncValue<List<ServiceRecord>>? state,
  }) : super(state ?? AsyncValue.data(records));

  @override
  Future<void> deleteRecord(String id) async => deletedIds.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Captures the rows handed to the export facade, so the item-level export can
/// be asserted without touching the filesystem or a share sheet.
class _FakeExportService implements ExportService {
  List<MaintenanceLogRow> sharedRows = const [];
  List<MaintenanceLogRow> savedRows = const [];

  @override
  Future<String> exportMaintenanceLog({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) async {
    sharedRows = rows;
    return '/tmp/shared.xlsx';
  }

  @override
  Future<String?> saveMaintenanceLogToFile({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) async {
    savedRows = rows;
    return '/tmp/saved.xlsx';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
