import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_group_tile.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/show_refine_panel.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

final _target = StateProvider<DiveFilterState>(
  (ref) => const DiveFilterState(minDepth: 30),
);

void main() {
  late ProviderContainer container;

  Future<void> pumpHost(
    WidgetTester tester,
    Size size, {
    Locale locale = const Locale('en'),
    bool settle = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return Row(
                  children: [
                    const Text('the list'),
                    ElevatedButton(
                      onPressed: () => showRefinePanel(
                        context,
                        filterProvider: _target,
                        builder: () => const Text('panel body'),
                      ),
                      child: const Text('open'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('opens as a bottom sheet on a phone', (tester) async {
    await pumpHost(tester, const Size(390, 844));
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('panel body'), findsOneWidget);
  });

  // Review Focus 5.
  testWidgets('opens as a right-side panel on a wide layout', (tester) async {
    await pumpHost(tester, const Size(1280, 800));
    expect(find.byType(BottomSheet), findsNothing);
    final panel = tester.getRect(find.text('panel body'));
    expect(panel.left, greaterThanOrEqualTo(1280 - kRefinePanelSideWidth));
    expect(find.text('the list'), findsOneWidget);
    // A tap on the dimmed list area closes it and applies nothing.
    await tester.tapAt(const Offset(200, 400));
    await tester.pumpAndSettle();
    expect(find.text('panel body'), findsNothing);
    expect(container.read(_target), const DiveFilterState(minDepth: 30));
  });

  testWidgets('a group tile summarizes and expands when set', (tester) async {
    Widget tile(int n) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: RefineGroupTile(
          title: 'Date',
          activeCount: n,
          child: const Text('group body'),
        ),
      ),
    );
    await tester.pumpWidget(tile(0));
    await tester.pumpAndSettle();
    expect(find.text('Any'), findsOneWidget);
    expect(find.text('group body'), findsNothing);
    await tester.pumpWidget(Container());
    await tester.pumpWidget(tile(2));
    await tester.pumpAndSettle();
    expect(find.text('2 set'), findsOneWidget);
    expect(find.text('group body'), findsOneWidget);
  });

  // Code review: in RTL the panel sits at the left, so it slides in from
  // the left edge, not across the list from the right.
  testWidgets('in RTL the side panel slides in from the left', (tester) async {
    await pumpHost(
      tester,
      const Size(1280, 800),
      locale: const Locale('he'),
      settle: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getRect(find.text('panel body')).left, lessThan(0));
    await tester.pumpAndSettle();
  });
}
