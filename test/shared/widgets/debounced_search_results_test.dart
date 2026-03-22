import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';

void main() {
  group('DebouncedSearchResults', () {
    /// Builds a test harness that renders [DebouncedSearchResults] inside a
    /// [ProviderScope]. The [queryNotifier] lets us swap the query from
    /// outside, and [asyncNotifier] lets us control what the provider returns.
    Widget buildSubject({
      required ValueNotifier<String> queryNotifier,
      required ValueNotifier<AsyncValue<List<String>>> asyncNotifier,
      Widget Function(BuildContext)? emptyQueryBuilder,
    }) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<String>(
              valueListenable: queryNotifier,
              builder: (context, query, _) {
                return SizedBox(
                  height: 400,
                  child: DebouncedSearchResults<String>(
                    query: query,
                    watchProvider: (ref, q) => asyncNotifier.value,
                    dataBuilder: (context, items) => ListView(
                      children: items
                          .map(
                            (item) => ListTile(
                              key: ValueKey(item),
                              title: Text(item),
                            ),
                          )
                          .toList(),
                    ),
                    emptyBuilder: (context, q) => Text('No results for "$q"'),
                    errorBuilder: (context, error) => Text('Error: $error'),
                    emptyQueryBuilder: emptyQueryBuilder,
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    testWidgets('shows results after debounce period', (
      WidgetTester tester,
    ) async {
      final queryNotifier = ValueNotifier<String>('');
      final asyncNotifier = ValueNotifier<AsyncValue<List<String>>>(
        const AsyncValue.data(['Apple', 'Apricot']),
      );

      await tester.pumpWidget(
        buildSubject(
          queryNotifier: queryNotifier,
          asyncNotifier: asyncNotifier,
        ),
      );

      // Start with empty query -- nothing visible
      expect(find.text('Apple'), findsNothing);

      // Set a query; results should NOT appear immediately (debounce)
      queryNotifier.value = 'ap';
      await tester.pump(); // rebuild with new query, timer starts

      expect(find.text('Apple'), findsNothing);

      // Advance past the 300ms debounce
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Apricot'), findsOneWidget);
    });

    testWidgets(
      'shows cached results with LinearProgressIndicator during loading',
      (WidgetTester tester) async {
        final queryNotifier = ValueNotifier<String>('fruit');
        final asyncNotifier = ValueNotifier<AsyncValue<List<String>>>(
          const AsyncValue.data(['Banana', 'Blueberry']),
        );

        await tester.pumpWidget(
          buildSubject(
            queryNotifier: queryNotifier,
            asyncNotifier: asyncNotifier,
          ),
        );

        // The initial query is set at construction, so debounced query starts
        // equal to it. Results appear immediately.
        await tester.pump();
        expect(find.text('Banana'), findsOneWidget);

        // Now simulate a new search that is still loading
        asyncNotifier.value = const AsyncValue.loading();
        queryNotifier.value = 'berry';
        await tester.pump(); // trigger rebuild, starts debounce timer
        await tester.pump(const Duration(milliseconds: 300)); // debounce fires

        // Cached results should still be visible
        expect(find.text('Banana'), findsOneWidget);
        expect(find.text('Blueberry'), findsOneWidget);
        // And a LinearProgressIndicator should be showing
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('immediately clears when query becomes empty', (
      WidgetTester tester,
    ) async {
      final queryNotifier = ValueNotifier<String>('fruit');
      final asyncNotifier = ValueNotifier<AsyncValue<List<String>>>(
        const AsyncValue.data(['Cherry']),
      );

      await tester.pumpWidget(
        buildSubject(
          queryNotifier: queryNotifier,
          asyncNotifier: asyncNotifier,
        ),
      );
      await tester.pump();
      expect(find.text('Cherry'), findsOneWidget);

      // Clear the query -- should disappear immediately, no 300ms wait
      queryNotifier.value = '';
      await tester.pump(); // single frame, no timer advance

      expect(find.text('Cherry'), findsNothing);
    });

    testWidgets(
      'shows emptyQueryBuilder widget when provided and query is empty',
      (WidgetTester tester) async {
        final queryNotifier = ValueNotifier<String>('');
        final asyncNotifier = ValueNotifier<AsyncValue<List<String>>>(
          const AsyncValue.data([]),
        );

        await tester.pumpWidget(
          buildSubject(
            queryNotifier: queryNotifier,
            asyncNotifier: asyncNotifier,
            emptyQueryBuilder: (context) => const Text('Type to search'),
          ),
        );
        await tester.pump();

        expect(find.text('Type to search'), findsOneWidget);
      },
    );

    testWidgets(
      'shows SizedBox.shrink when no emptyQueryBuilder and query is empty',
      (WidgetTester tester) async {
        final queryNotifier = ValueNotifier<String>('');
        final asyncNotifier = ValueNotifier<AsyncValue<List<String>>>(
          const AsyncValue.data([]),
        );

        await tester.pumpWidget(
          buildSubject(
            queryNotifier: queryNotifier,
            asyncNotifier: asyncNotifier,
          ),
        );
        await tester.pump();

        // The harness wraps content in a SizedBox(height: 400), so filter to
        // only the shrink variant (width == 0 && height == 0).
        final shrinkFinder = find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 0.0 && widget.height == 0.0,
        );
        expect(shrinkFinder, findsOneWidget);
      },
    );

    testWidgets('shows emptyBuilder when search returns empty list', (
      WidgetTester tester,
    ) async {
      final queryNotifier = ValueNotifier<String>('xyz');
      final asyncNotifier = ValueNotifier<AsyncValue<List<String>>>(
        const AsyncValue.data([]),
      );

      await tester.pumpWidget(
        buildSubject(
          queryNotifier: queryNotifier,
          asyncNotifier: asyncNotifier,
        ),
      );
      await tester.pump();

      expect(find.text('No results for "xyz"'), findsOneWidget);
    });

    testWidgets('shows errorBuilder on error', (WidgetTester tester) async {
      final queryNotifier = ValueNotifier<String>('fail');
      final asyncNotifier = ValueNotifier<AsyncValue<List<String>>>(
        AsyncValue.error('Network timeout', StackTrace.current),
      );

      await tester.pumpWidget(
        buildSubject(
          queryNotifier: queryNotifier,
          asyncNotifier: asyncNotifier,
        ),
      );
      await tester.pump();

      expect(find.text('Error: Network timeout'), findsOneWidget);
    });
  });
}
