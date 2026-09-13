import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/formatters/dive_type_label_resolver.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_table_view.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

import '../../../../helpers/test_app.dart';

/// The desktop table's Dive Type column used to call
/// `DiveField.extractFromDive` without a `diveTypeLabel`, so it fell back to
/// `Dive.diveTypeNames`: a custom type showed its slug capitalized
/// (`search_recovery` -> `Search recovery`) instead of the diver's own name,
/// and a built-in type stayed English under every locale. The table now takes
/// the same resolver the list tiles use, for both its cells and its sort.
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

void main() {
  DiveTypeEntity builtIn(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    isBuiltIn: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  DiveTypeEntity custom(String id, String name) => DiveTypeEntity(
    id: id,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Dive diveWith(String id, int number, List<String> typeIds) => Dive(
    id: id,
    dateTime: DateTime(2026, 3, 15),
    diveNumber: number,
    diveTypeIds: typeIds,
  );

  Widget table({
    required List<Dive> dives,
    required List<DiveTypeEntity> types,
    Locale locale = const Locale('en'),
    DiveField? sortField,
  }) {
    return testApp(
      locale: locale,
      overrides: [
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
        diveTypesProvider.overrideWith((ref) async => types),
        tableViewConfigProvider.overrideWith(
          (ref) => _TestTableConfigNotifier(
            TableViewConfig(
              columns: [
                TableColumnConfig(field: DiveField.diveNumber, isPinned: true),
                TableColumnConfig(field: DiveField.diveTypeName, width: 200),
              ],
              sortField: sortField,
            ),
          ),
        ),
      ],
      // Built through the production helper, as dive_list_content does, so
      // these cases cover the provider -> label seam too.
      child: Consumer(
        builder: (context, ref, _) => DiveTableView(
          dives: dives,
          onDiveTap: (_) {},
          diveTypeLabelResolver: watchDiveTypeLabelResolver(ref, context.l10n),
        ),
      ),
    );
  }

  testWidgets('a custom type renders under the name the diver gave it', (
    tester,
  ) async {
    await tester.pumpWidget(
      table(
        dives: [
          diveWith('d1', 1, ['search_recovery']),
        ],
        types: [custom('search_recovery', 'Search & Recovery')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search & Recovery'), findsOneWidget);
    expect(find.text('Search recovery'), findsNothing);
  });

  testWidgets('a collision-suffixed custom id renders the diver name', (
    tester,
  ) async {
    await tester.pumpWidget(
      table(
        dives: [
          diveWith('d1', 1, ['search_recovery_1a2b3c4d']),
        ],
        types: [custom('search_recovery_1a2b3c4d', 'Search & Recovery')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search & Recovery'), findsOneWidget);
    expect(find.textContaining('1a2b3c4d'), findsNothing);
  });

  testWidgets('a built-in type is localized', (tester) async {
    await tester.pumpWidget(
      table(
        locale: const Locale('de'),
        dives: [
          diveWith('d1', 1, ['wreck']),
        ],
        types: [builtIn('wreck', 'Wreck')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wracktauchen'), findsOneWidget);
    expect(find.text('Wreck'), findsNothing);
  });

  testWidgets('sorting by dive type orders rows by the resolved label', (
    tester,
  ) async {
    // Slug order is the reverse of label order, and the dives arrive in slug
    // order, so a comparator still reading slug capitalizations would leave
    // "Zulu" on top.
    await tester.pumpWidget(
      table(
        sortField: DiveField.diveTypeName,
        dives: [
          diveWith('d1', 1, ['alpha_x']),
          diveWith('d2', 2, ['zulu_x']),
        ],
        types: [custom('alpha_x', 'Zulu'), custom('zulu_x', 'Alpha')],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.text('Alpha')).dy,
      lessThan(tester.getTopLeft(find.text('Zulu')).dy),
    );
  });
}
