import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Issue #643: the active-filter bar rendered the dive type's stored `name`,
/// which is seeded as an English literal, so the chip stayed English under
/// every locale. It now resolves through `localizedName` with the built-in
/// table as a fallback for a type whose row has not loaded.
class _MockPaginatedNotifier
    extends StateNotifier<AsyncValue<PaginatedDiveListState>>
    implements PaginatedDiveListNotifier {
  _MockPaginatedNotifier(List<DiveSummary> dives)
    : super(
        AsyncValue.data(PaginatedDiveListState(dives: dives, hasMore: false)),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  Future<Widget> buildContent({
    required String diveTypeId,
    required Locale locale,
    DiveTypeEntity? resolvedType,
  }) async {
    final summaries = [
      DiveSummary.fromDive(
        Dive(id: 'd1', dateTime: DateTime(2026, 3, 15), diveNumber: 1),
      ),
    ];
    final base = await getBaseOverrides();

    return testApp(
      locale: locale,
      overrides: [
        ...base,
        diveListViewModeProvider.overrideWith((ref) => ListViewMode.compact),
        diveFilterProvider.overrideWith(
          (ref) => DiveFilterState(diveTypeId: diveTypeId),
        ),
        diveTypeProvider.overrideWith((ref, id) async => resolvedType),
        paginatedDiveListProvider.overrideWith(
          (ref) => _MockPaginatedNotifier(summaries),
        ),
      ],
      child: const DiveListContent(showAppBar: false),
    );
  }

  testWidgets('a built-in dive-type filter chip is localized', (tester) async {
    await tester.pumpWidget(
      await buildContent(
        diveTypeId: 'wreck',
        locale: const Locale('de'),
        resolvedType: builtIn('wreck', 'Wreck'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wracktauchen'), findsOneWidget);
    expect(find.text('Wreck'), findsNothing);
  });

  testWidgets('a custom dive-type filter chip keeps the diver name', (
    tester,
  ) async {
    await tester.pumpWidget(
      await buildContent(
        diveTypeId: 'muck_x1',
        locale: const Locale('de'),
        resolvedType: custom('muck_x1', 'Muck'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Muck'), findsOneWidget);
  });

  testWidgets('falls back to the built-in table when the row is unresolved', (
    tester,
  ) async {
    // diveTypeProvider yields null (row not loaded / not present), so tier 2
    // has to supply the label rather than leaking the raw slug.
    await tester.pumpWidget(
      await buildContent(diveTypeId: 'night', locale: const Locale('de')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nachttauchen'), findsOneWidget);
  });

  testWidgets('an unknown slug falls back to the id itself', (tester) async {
    await tester.pumpWidget(
      await buildContent(
        diveTypeId: 'not_a_builtin',
        locale: const Locale('de'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('not_a_builtin'), findsOneWidget);
  });

  testWidgets('English still shows the seeded English literal', (tester) async {
    await tester.pumpWidget(
      await buildContent(
        diveTypeId: 'wreck',
        locale: const Locale('en'),
        resolvedType: builtIn('wreck', 'Wreck'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Wreck'), findsOneWidget);
  });
}
