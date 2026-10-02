import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/search/dive_search_action.dart';

import '../../../../../helpers/mock_providers.dart';
import '../../../../../helpers/test_app.dart';

void main() {
  late ProviderContainer container;

  Future<void> pump(WidgetTester tester, DiveFilterState filter) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [...base, diveFilterProvider.overrideWith((ref) => filter)],
        child: Builder(
          builder: (context) {
            container = ProviderScope.containerOf(context);
            return const DiveSearchAction();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const action = kDiveSearchActionKey;

  testWidgets('opens the row and asks for focus', (tester) async {
    await pump(tester, const DiveFilterState());
    await tester.tap(find.byKey(action));
    await tester.pump();
    expect(container.read(diveSearchBarOpenProvider), isTrue);
    expect(container.read(diveSearchFocusPendingProvider), isTrue);
  });

  testWidgets('a second press on an idle open row closes it', (tester) async {
    await pump(tester, const DiveFilterState());
    await tester.tap(find.byKey(action));
    await tester.pump();
    await tester.tap(find.byKey(action));
    await tester.pump();
    expect(container.read(diveSearchBarOpenProvider), isFalse);
  });

  testWidgets('with a search active a press focuses instead of closing', (
    tester,
  ) async {
    await pump(tester, const DiveFilterState(minDepth: 30));
    await tester.tap(find.byKey(action));
    await tester.pump();
    expect(container.read(diveSearchBarOpenProvider), isTrue);
    expect(container.read(diveSearchFocusPendingProvider), isTrue);
  });

  testWidgets('badged while anything is filtered', (tester) async {
    await pump(tester, const DiveFilterState(minDepth: 30));
    expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    expect(find.byTooltip('Search dives'), findsOneWidget);
  });
}
