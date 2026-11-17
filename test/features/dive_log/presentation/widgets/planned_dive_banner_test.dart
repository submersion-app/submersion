import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_banner.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_links.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The planned dive banner keeps its text readable at phone width with both
/// of its actions (issue #3565, phase 2b).
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required double width,
    String? operationReason,
    VoidCallback? onMarkLogged,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          planForLoggedDiveProvider('d1').overrideWith((ref) async => 'p1'),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: PlannedDiveBanner(
              diveId: 'd1',
              onMarkLogged: onMarkLogged ?? () {},
              operationReason: operationReason,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [360.0, 400.0, 1200.0]) {
    testWidgets('at ${width.round()} px the text keeps most of the width', (
      tester,
    ) async {
      await pump(tester, width: width);

      expect(find.text('Open in planner'), findsOneWidget);
      expect(find.text('Mark as logged'), findsOneWidget);
      final body = tester.getSize(
        find.textContaining('Awaiting dive computer data'),
      );
      expect(body.width, greaterThan(width * 0.6));
    });
  }

  testWidgets('a banner operation with a reason is disabled and says why', (
    tester,
  ) async {
    var marked = 0;
    await pump(
      tester,
      width: 1200,
      operationReason: 'Unlock to use this',
      onMarkLogged: () => marked++,
    );

    final mark = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Mark as logged'),
    );
    expect(mark.onPressed, isNull);
    expect(find.byTooltip('Unlock to use this'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Open in planner'),
          )
          .onPressed,
      isNotNull,
    );
    expect(marked, 0);
  });

  testWidgets('the banner is the same height with and without a reason', (
    tester,
  ) async {
    await pump(tester, width: 400);
    final free = tester.getSize(find.byType(PlannedDiveBanner)).height;
    await pump(tester, width: 400, operationReason: 'Unlock to use this');
    expect(tester.getSize(find.byType(PlannedDiveBanner)).height, free);
  });
}
