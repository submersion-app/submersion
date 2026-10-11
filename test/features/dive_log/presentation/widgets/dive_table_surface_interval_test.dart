import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_table_view.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _TestTableConfigNotifier extends TableViewConfigNotifier {
  _TestTableConfigNotifier(TableViewConfig config) {
    state = config;
  }
}

/// The table shows the computed surface interval the detail page shows
/// (#2984), not the stored-only "--".
void main() {
  testWidgets('surface interval shows the computed value, not "--"', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          tableViewConfigProvider.overrideWith(
            (ref) => _TestTableConfigNotifier(
              TableViewConfig(
                columns: [
                  TableColumnConfig(
                    field: DiveField.diveNumber,
                    isPinned: true,
                  ),
                  TableColumnConfig(field: DiveField.surfaceInterval),
                ],
              ),
            ),
          ),
          diveSurfaceIntervalsProvider.overrideWith(
            (ref) async => const {'d2': Duration(minutes: 65)},
          ),
        ],
        child: DiveTableView(
          dives: [
            Dive(
              id: 'd1',
              dateTime: DateTime.utc(2026, 4, 1, 8),
              diveNumber: 1,
            ),
            Dive(
              id: 'd2',
              dateTime: DateTime.utc(2026, 4, 1, 11),
              diveNumber: 2,
            ),
          ],
          diveTypeLabelResolver: Dive.diveTypeDisplayName,
          onDiveTap: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1h 5m'), findsOneWidget);
  });
  testWidgets('an interval cell has no menu until the computed map loads', (
    tester,
  ) async {
    // While loading, d1 shows "--" though its interval may be computed:
    // "no value" there could drop it once the map arrives.
    final pending = Completer<Map<String, Duration?>>();
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
          tableViewConfigProvider.overrideWith(
            (ref) => _TestTableConfigNotifier(
              TableViewConfig(
                columns: [
                  TableColumnConfig(
                    field: DiveField.diveNumber,
                    isPinned: true,
                  ),
                  TableColumnConfig(field: DiveField.surfaceInterval),
                ],
              ),
            ),
          ),
          diveSurfaceIntervalsProvider.overrideWith((ref) => pending.future),
          allDiveComputersProvider.overrideWith((ref) async => const []),
        ],
        child: DiveTableView(
          dives: [
            Dive(
              id: 'd1',
              dateTime: DateTime.utc(2026, 4, 1, 8),
              diveNumber: 1,
            ),
          ],
          diveTypeLabelResolver: Dive.diveTypeDisplayName,
          onDiveTap: (_) {},
        ),
      ),
    );
    await tester.pump();
    bool longPressAboveBlank() => tester
        .widgetList<GestureDetector>(
          find.ancestor(
            of: find.text('--'),
            matching: find.byType(GestureDetector),
          ),
        )
        .any((d) => d.onLongPressStart != null);
    expect(find.text('--'), findsOneWidget);
    expect(longPressAboveBlank(), isFalse);

    pending.complete(const {'d1': null});
    await tester.pumpAndSettle();
    expect(longPressAboveBlank(), isTrue);
  });
}
