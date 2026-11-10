import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/theme/app_colors.dart';
import 'package:submersion/features/demo_mode/presentation/providers/demo_mode_providers.dart';
import 'package:submersion/features/demo_mode/presentation/widgets/demo_mode_ribbon.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _screen = Size(390, 844);
const _cornerButton = ValueKey('cornerButton');

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pumpRibbon(
    WidgetTester tester, {
    required bool active,
    double statusBar = 0,
    TextDirection direction = TextDirection.ltr,
    VoidCallback? onCornerTap,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = _screen;
    tester.view.padding = FakeViewPadding(top: statusBar);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [demoModeActiveProvider.overrideWithValue(active)],
        child: MaterialApp(
          // Its own DEBUG ribbon is a Banner too, as in the app.
          debugShowCheckedModeBanner: false,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => Directionality(
            textDirection: direction,
            child: DemoModeRibbon(child: child!),
          ),
          home: Scaffold(
            body: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: EdgeInsets.only(top: statusBar),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: GestureDetector(
                    key: _cornerButton,
                    behavior: HitTestBehavior.opaque,
                    onTap: onCornerTap,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Banner ribbon(WidgetTester tester) => tester.widget<Banner>(
    find.descendant(
      of: find.byType(DemoModeRibbon),
      matching: find.byType(Banner),
    ),
  );

  testWidgets('no ribbon while demo mode is off', (tester) async {
    await pumpRibbon(tester, active: false);

    expect(find.byType(Banner), findsNothing);
    expect(find.byKey(_cornerButton), findsOneWidget);
  });

  testWidgets('an amber DEMO ribbon in the top-end corner in demo mode', (
    tester,
  ) async {
    await pumpRibbon(tester, active: true);

    final banner = ribbon(tester);
    expect(banner.message, l10n.demo_ribbon_label);
    expect(banner.location, BannerLocation.topEnd);
    expect(banner.color, AppColors.warning);
    expect(banner.textStyle.color, Colors.black87);
  });

  testWidgets('the ribbon takes no layout space from the page', (tester) async {
    await pumpRibbon(tester, active: true);

    expect(tester.getRect(find.byType(Scaffold)), Offset.zero & _screen);
  });

  testWidgets('the ribbon sits below the status bar, at the window edge', (
    tester,
  ) async {
    await pumpRibbon(tester, active: true, statusBar: 47);

    final rect = tester.getRect(find.byType(Banner));
    expect(rect.top, 47);
    expect(rect.right, _screen.width);
  });

  testWidgets('the ribbon follows a right-to-left layout to the left edge', (
    tester,
  ) async {
    await pumpRibbon(tester, active: true, direction: TextDirection.rtl);

    expect(tester.getRect(find.byType(Banner)).left, 0);
  });

  testWidgets('taps reach the control under the ribbon', (tester) async {
    var taps = 0;
    await pumpRibbon(tester, active: true, onCornerTap: () => taps++);

    // The middle of the ribbon, 40 px in from the corner along the diagonal.
    await tester.tapAt(const Offset(390 - 30, 30));
    expect(taps, 1);
  });

  testWidgets('a screen reader hears that demo mode is on', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpRibbon(tester, active: true);

    expect(find.bySemanticsLabel(l10n.demo_strip_label), findsOneWidget);
    semantics.dispose();
  });

  test('the app shows the ribbon over every screen', () {
    final app = File('lib/app.dart').readAsStringSync();
    final shell = File(
      'lib/shared/widgets/main_scaffold.dart',
    ).readAsStringSync();

    expect('DemoModeRibbon('.allMatches(app).length, 1);
    expect(shell, isNot(contains('DemoMode')));
  });
}
