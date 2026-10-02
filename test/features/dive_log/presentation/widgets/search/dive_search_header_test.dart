import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_summary.dart';
import 'package:submersion/features/dive_log/domain/models/dive_filter_state.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_header.dart';
import 'package:submersion/features/query/presentation/providers/query_name_index_provider.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpHeader(
    WidgetTester tester, {
    DiveFilterState filter = const DiveFilterState(),
    bool open = true,
    List<DiveSummary> jump = const [],
    ValueChanged<DiveSummary>? onOpenDive,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          diveFilterProvider.overrideWith((ref) => filter),
          diveSearchBarOpenProvider.overrideWith((ref) => open),
          queryNameIndexProvider.overrideWith((ref) async => NameIndex.empty),
          diveJumpResultsProvider.overrideWith((ref, q) async => jump),
        ],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return DiveSearchHeader(onOpenDive: onOpenDive ?? (_) {});
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  DiveFilterState filterOf() => container.read(diveFilterProvider);

  TextField fieldOf(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(kDiveSearchFieldKey));

  testWidgets('hidden while closed and nothing is filtered', (tester) async {
    await pumpHeader(tester, open: false);
    expect(find.byKey(kDiveSearchFieldKey), findsNothing);
  });

  testWidgets('typing filters the list after the debounce', (tester) async {
    await pumpHeader(tester);
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(const Duration(milliseconds: 100));
    expect(filterOf().query, isNull, reason: 'still inside the debounce');
    await tester.pump(kDiveSearchDebounce);
    expect(filterOf().query, TextNode(['manta']));
  });

  testWidgets('invalid text shows an error and keeps the last query', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      filter: DiveFilterState(query: TextNode(['manta'])),
    );
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'depth >');
    await tester.pump(kDiveSearchDebounce);
    expect(filterOf().query, TextNode(['manta']));
    expect(fieldOf(tester).decoration?.errorText, isNotNull);
  });

  testWidgets('an outside query change re-prints the field', (tester) async {
    await pumpHeader(tester);
    container.read(diveFilterProvider.notifier).state = DiveFilterState(
      query: TextNode(['wreck']),
    );
    await tester.pumpAndSettle();
    expect(fieldOf(tester).controller!.text, 'wreck');
  });

  // Review Focus 1.
  testWidgets('another write inside the debounce keeps both changes', (
    tester,
  ) async {
    await pumpHeader(tester, filter: const DiveFilterState(minDepth: 30));
    await tester.enterText(find.byKey(kDiveSearchFieldKey), 'manta');
    await tester.pump(const Duration(milliseconds: 100));
    container.read(diveFilterProvider.notifier).state = filterOf().copyWith(
      axesSuspended: true,
    );
    await tester.pump();
    expect(fieldOf(tester).controller!.text, 'manta', reason: 'not reverted');
    await tester.pump(kDiveSearchDebounce);
    expect(filterOf().query, TextNode(['manta']));
    expect(filterOf().axesSuspended, isTrue);
  });

  testWidgets('a focus request puts the caret in the field', (tester) async {
    await pumpHeader(tester);
    container.read(diveSearchFocusPendingProvider.notifier).state = true;
    await tester.pumpAndSettle();
    expect(fieldOf(tester).focusNode!.hasFocus, isTrue);
    expect(container.read(diveSearchFocusPendingProvider), isFalse);
  });

  testWidgets('focusing the field opens the row', (tester) async {
    await pumpHeader(
      tester,
      open: false,
      filter: DiveFilterState(query: TextNode(['manta'])),
    );
    await tester.tap(find.byKey(kDiveSearchFieldKey));
    await tester.pump();
    expect(container.read(diveSearchBarOpenProvider), isTrue);
  });

  testWidgets('the refine button badges the panel axis count', (tester) async {
    await pumpHeader(
      tester,
      filter: DiveFilterState(minDepth: 30, query: TextNode(['manta'])),
    );
    final badge = find.descendant(
      of: find.byKey(kDiveSearchRefineKey),
      matching: find.byType(Badge),
    );
    expect(tester.widget<Badge>(badge).isLabelVisible, isTrue);
    expect(
      find.descendant(of: badge, matching: find.text('1')),
      findsOneWidget,
    );
  });
}
