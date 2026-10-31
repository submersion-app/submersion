import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/providers/entity_table_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _TableConfigNotifier extends EntityTableConfigNotifier<DiveCenterField> {
  _TableConfigNotifier(EntityTableViewConfig<DiveCenterField> config)
    : super(
        defaultConfig: config,
        fieldFromName: DiveCenterFieldAdapter.instance.fieldFromName,
      );
}

class _ListNotifier extends StateNotifier<AsyncValue<List<DiveCenter>>>
    implements DiveCenterListNotifier {
  _ListNotifier(List<DiveCenter> centers) : super(AsyncValue.data(centers));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

final _now = DateTime(2026, 1, 1);

DiveCenter _center(String name) =>
    DiveCenter(id: name, name: name, createdAt: _now, updatedAt: _now);

const _alpha = 'Alpha';
const _bravo = 'Bravo';
const _charlie = 'Charlie';

const _counts = {_alpha: 2, _bravo: 41, _charlie: 17};

EntityTableViewConfig<DiveCenterField> _tableConfig({
  DiveCenterField? sortField,
}) => EntityTableViewConfig<DiveCenterField>(
  columns: [
    EntityTableColumnConfig(field: DiveCenterField.centerName, isPinned: true),
    EntityTableColumnConfig(field: DiveCenterField.diveCount),
  ],
  sortField: sortField,
  sortAscending: false,
);

Future<void> _pump(
  WidgetTester tester, {
  required ListViewMode viewMode,
  required FutureOr<Map<String, int>> Function() counts,
  EntityTableViewConfig<DiveCenterField>? tableConfig,
  SortState<DiveCenterSortField> sort = const SortState(
    field: DiveCenterSortField.name,
    direction: SortDirection.descending,
  ),
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        diveCenterListNotifierProvider.overrideWith(
          (ref) => _ListNotifier([
            _center(_alpha),
            _center(_bravo),
            _center(_charlie),
          ]),
        ),
        diveCenterListViewModeProvider.overrideWith((ref) => viewMode),
        diveCenterTableConfigProvider.overrideWith(
          (ref) => _TableConfigNotifier(tableConfig ?? _tableConfig()),
        ),
        diveCenterSortProvider.overrideWithValue(sort),
        diveCenterDiveCountsProvider.overrideWith((ref) => counts()),
        diveCenterDiveCountProvider.overrideWith((ref, id) => _counts[id] ?? 0),
      ],
      child: const DiveCenterListContent(showAppBar: true),
    ),
  );
}

/// The center names as they stand on screen, top to bottom.
List<String> _namesTopToBottom(WidgetTester tester) {
  final names = [_alpha, _bravo, _charlie].toList();
  names.sort(
    (a, b) => tester
        .getTopLeft(find.text(a).first)
        .dy
        .compareTo(tester.getTopLeft(find.text(b).first).dy),
  );
  return names;
}

ProviderContainer _containerOf(WidgetTester tester) =>
    ProviderScope.containerOf(
      tester.element(find.byType(DiveCenterListContent)),
    );

void main() {
  group('table mode', () {
    testWidgets('fills every row from the one map of counts', (tester) async {
      await _pump(
        tester,
        viewMode: ListViewMode.table,
        counts: () => const {_bravo: 41},
        // The per-center values differ on purpose: the table must not read
        // them, or it is back to one provider per row.
      );
      await tester.pumpAndSettle();

      expect(find.text('41'), findsOneWidget);
      expect(find.text('17'), findsNothing);
      // Centers absent from the map have no dives.
      expect(find.text('0'), findsNWidgets(2));
    });

    testWidgets('holds its spinner until the first counts arrive', (
      tester,
    ) async {
      final counts = Completer<Map<String, int>>();
      await _pump(
        tester,
        viewMode: ListViewMode.table,
        counts: () => counts.future,
        tableConfig: _tableConfig(sortField: DiveCenterField.diveCount),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_alpha), findsNothing);

      counts.complete(_counts);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_namesTopToBottom(tester), [_bravo, _charlie, _alpha]);
    });

    testWidgets('keeps the old numbers on screen during a refresh', (
      tester,
    ) async {
      final refreshed = Completer<Map<String, int>>();
      var reads = 0;
      await _pump(
        tester,
        viewMode: ListViewMode.table,
        counts: () => reads++ == 0 ? _counts : refreshed.future,
      );
      await tester.pumpAndSettle();
      expect(find.text('41'), findsOneWidget);

      _containerOf(tester).invalidate(diveCenterDiveCountsProvider);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('41'), findsOneWidget);

      refreshed.complete(const {_bravo: 42});
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('shows zero counts when the count read fails', (tester) async {
      await _pump(
        tester,
        viewMode: ListViewMode.table,
        counts: () => throw StateError('count read failed'),
      );
      await tester.pumpAndSettle();

      expect(find.text(_alpha), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
    });
  });

  group('list mode', () {
    const byCount = SortState(
      field: DiveCenterSortField.diveCount,
      direction: SortDirection.descending,
    );

    testWidgets('Dive Count sorts by the real counts', (tester) async {
      await _pump(
        tester,
        viewMode: ListViewMode.compact,
        counts: () => _counts,
        sort: byCount,
      );
      await tester.pumpAndSettle();

      expect(_namesTopToBottom(tester), [_bravo, _charlie, _alpha]);
    });

    testWidgets('Dive Count waits for the counts before placing rows', (
      tester,
    ) async {
      final counts = Completer<Map<String, int>>();
      await _pump(
        tester,
        viewMode: ListViewMode.compact,
        counts: () => counts.future,
        sort: byCount,
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(_alpha), findsNothing);

      counts.complete(_counts);
      await tester.pumpAndSettle();

      expect(_namesTopToBottom(tester), [_bravo, _charlie, _alpha]);
    });

    testWidgets('a name sort does not wait for the counts', (tester) async {
      final counts = Completer<Map<String, int>>();
      await _pump(
        tester,
        viewMode: ListViewMode.compact,
        counts: () => counts.future,
      );
      // A bounded pump: a spinner here would never settle.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(_namesTopToBottom(tester), [_alpha, _bravo, _charlie]);
    });
  });
}
