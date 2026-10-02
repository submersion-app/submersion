import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/shared/selection/select_items_menu_entries.dart';
import 'package:submersion/shared/selection/table_selection_owner.dart';

import '../../helpers/test_app.dart';

final _viewMode = StateProvider<ListViewMode>((ref) => ListViewMode.table);

class _Page extends ConsumerStatefulWidget {
  const _Page();

  @override
  ConsumerState<_Page> createState() => _PageState();
}

class _PageState extends ConsumerState<_Page> with TableSelectionOwner {
  @override
  Widget build(BuildContext context) {
    resetTableSelectionOffTable(_viewMode);
    return Scaffold(
      appBar: AppBar(
        actions: [
          PopupMenuButton<String>(
            key: const ValueKey('overflow'),
            itemBuilder: (context) => [
              ...tableSelectItemsEntries(context),
              const PopupMenuItem(value: 'other', child: Text('Other')),
            ],
          ),
        ],
      ),
      body: Text(tableSelection.value.isActive ? 'active' : 'inactive'),
    );
  }
}

void main() {
  late ProviderContainer container;

  Future<_PageState> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      testApp(locale: const Locale('en'), child: const _Page()),
    );
    container = ProviderScope.containerOf(tester.element(find.byType(_Page)));
    return tester.state<_PageState>(find.byType(_Page));
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('overflow')));
    await tester.pumpAndSettle();
  }

  testWidgets('offers "Select items", which enters selection', (tester) async {
    final page = await pump(tester);
    await openMenu(tester);

    await tester.tap(find.byKey(selectItemsMenuKey));
    await tester.pumpAndSettle();

    expect(page.tableSelection.value.isActive, isTrue);
  });

  testWidgets('leaves the entry out while selecting', (tester) async {
    final page = await pump(tester);
    page.tableSelection.enterExplicit();
    await openMenu(tester);

    expect(find.byKey(selectItemsMenuKey), findsNothing);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('ends the selection when the view mode leaves table', (
    tester,
  ) async {
    final page = await pump(tester);
    page.tableSelection.enterExplicit();

    container.read(_viewMode.notifier).state = ListViewMode.compact;
    await tester.pump();

    expect(page.tableSelection.value.isActive, isFalse);
  });

  testWidgets('keeps the selection while the mode stays table', (tester) async {
    final page = await pump(tester);
    page.tableSelection.enterExplicit();

    container.read(_viewMode.notifier).state = ListViewMode.table;
    await tester.pump();

    expect(page.tableSelection.value.isActive, isTrue);
  });
}
