import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, DiveFilterState filter) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveFilterProvider.overrideWith((ref) => filter),
          diveSearchBarOpenProvider.overrideWith((ref) => true),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith((ref, q) async => const []),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return DiveSearchHeader(onOpenDive: (_) {});
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('closing an idle row just collapses it', (tester) async {
    await pump(tester, const DiveFilterState());
    await tester.tap(find.byKey(kDiveSearchCloseKey));
    await tester.pumpAndSettle();
    expect(find.byKey(kDiveSearchFieldKey), findsNothing);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('closing an active search clears it, and Undo brings it back', (
    tester,
  ) async {
    final active = DiveFilterState(minDepth: 30, query: TextNode(['manta']));
    await pump(tester, active);
    await tester.tap(find.byKey(kDiveSearchCloseKey));
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider), const DiveFilterState());
    // The row has collapsed; Undo comes from the snackbar alone.
    expect(find.byKey(kDiveSearchFieldKey), findsNothing);
    expect(find.text('Search cleared'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider), active);
    expect(find.byKey(kDiveSearchFieldKey), findsOneWidget);
  });

  testWidgets('Escape in the field closes like the button', (tester) async {
    await pump(tester, DiveFilterState(query: TextNode(['manta'])));
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(container.read(diveFilterProvider), const DiveFilterState());
  });
}
