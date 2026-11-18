import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_content.dart';

import '../../../../helpers/test_app.dart';
import 'dive_list_trip_grouping_test.dart' show groupingOverrides, makeDive;

/// Holds the open dive the way the master-detail scaffold does.
class _SplitHost extends StatefulWidget {
  const _SplitHost({required this.opened, this.initial});

  final List<String?> opened;
  final String? initial;

  @override
  State<_SplitHost> createState() => _SplitHostState();
}

class _SplitHostState extends State<_SplitHost> {
  late String? selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    return DiveListContent(
      showAppBar: false,
      selectedId: selected,
      onItemSelected: (id) {
        widget.opened.add(id);
        setState(() => selected = id);
      },
    );
  }
}

Finder _row(String id) =>
    find.byWidgetPredicate((w) => w is DiveListTile && w.diveId == id);

/// Opening another dive leaves the one the pane shows: unsaved work held
/// there is asked about first, and the dive already open asks nothing
/// (issue #4527).
void main() {
  final dives = [makeDive('d1'), makeDive('d2'), makeDive('d3')];
  late AppExitGuard guard;
  late int asked;
  late bool answer;

  Future<List<String?>> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    guard = AppExitGuard(
      retryExit: () async {},
      preventWindowClose: (_) async {},
      revealWindow: () async {},
    );
    asked = 0;
    answer = false;
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () async {
          asked++;
          return answer;
        },
      ),
    );
    final opened = <String?>[];
    final overrides = await groupingOverrides(dives);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          appExitGuardProvider.overrideWithValue(guard),
        ],
        child: _SplitHost(opened: opened, initial: 'd1'),
      ),
    );
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('an empty list\'s Log manually asks before replacing the pane', (
    tester,
  ) async {
    // A filter can empty the list while the pane still shows a dive.
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    guard = AppExitGuard(
      retryExit: () async {},
      preventWindowClose: (_) async {},
      revealWindow: () async {},
    );
    asked = 0;
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () async {
          asked++;
          return false;
        },
      ),
    );
    final router = GoRouter(
      initialLocation: '/dives?selected=d1',
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, state) => Scaffold(
            body: DiveListContent(
              showAppBar: false,
              selectedId: state.uri.queryParameters['selected'],
              onItemSelected: (_) {},
            ),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    final overrides = await groupingOverrides(const []);
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          appExitGuardProvider.overrideWithValue(guard),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Log Your First Dive'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log Dive Manually'));
    await tester.pumpAndSettle();

    expect(asked, 1);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/dives?selected=d1',
    );
  });

  testWidgets('the dive already open asks nothing', (tester) async {
    final opened = await pump(tester);

    await tester.tap(_row('d1'));
    await tester.pumpAndSettle();

    expect(asked, 0);
    expect(opened, ['d1']);
  });

  testWidgets('another dive asks first, and Keep editing opens nothing', (
    tester,
  ) async {
    final opened = await pump(tester);

    await tester.tap(_row('d2'));
    await tester.pumpAndSettle();

    expect(asked, 1);
    expect(opened, isEmpty);
  });

  testWidgets('a refused arrow move leaves the cursor on the open dive', (
    tester,
  ) async {
    final opened = await pump(tester);
    // Focus the list on the open row without asking anything.
    await tester.tap(_row('d1'));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(asked, 1);

    answer = true;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // From d1 again, not from the refused d2.
    expect(opened, ['d1', 'd2']);
  });
}
