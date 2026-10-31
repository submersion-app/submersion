import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/pages/profile_editor_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #3909: dragging across the editor's chart is the way a diver reaches
/// the range operations, so these run on the whole page, chart to buttons.
void main() {
  final profile = List.generate(
    41,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: i < 20 ? i * 1.0 : 20.0),
  );
  late Dive dive;

  Future<void> pumpEditor(WidgetTester tester, EditorMode mode) async {
    tester.view.physicalSize = const Size(1000, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    dive = createTestDiveWithBottomTime().copyWith(profile: profile);
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          profileSeriesHistoryProvider(
            dive.id,
          ).overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, _) =>
                    ProfileEditorPage(diveId: dive.id, initialMode: mode),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> dragAcrossChart(WidgetTester tester) async {
    final rect = tester.getRect(find.byType(LineChart));
    final from = Offset(rect.left + rect.width * 0.3, rect.center.dy);
    final to = Offset(rect.left + rect.width * 0.7, rect.center.dy);
    final gesture = await tester.startGesture(from);
    for (var step = 1; step <= 10; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / 10)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pump();
  }

  FilledButton button(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  bool enabled(WidgetTester tester, String label) =>
      button(tester, label).onPressed != null;

  testWidgets('a drag in Select mode enables the range operations', (
    tester,
  ) async {
    await pumpEditor(tester, EditorMode.select);
    expect(
      find.text('Select a range on the chart to enable operations'),
      findsOneWidget,
    );
    for (final label in ['Depth +1m', 'Time +5s', 'Delete', 'Smooth']) {
      expect(enabled(tester, label), isFalse, reason: label);
    }

    await dragAcrossChart(tester);

    expect(
      find.text('Select a range on the chart to enable operations'),
      findsNothing,
    );
    for (final label in ['Depth +1m', 'Time +5s', 'Delete', 'Smooth']) {
      expect(enabled(tester, label), isTrue, reason: label);
    }
  });

  testWidgets('the chart shades the selection the drag made', (tester) async {
    await pumpEditor(tester, EditorMode.select);

    await dragAcrossChart(tester);

    final annotations = tester
        .widget<LineChart>(find.byType(LineChart))
        .data
        .rangeAnnotations
        .verticalRangeAnnotations;
    expect(annotations, hasLength(1));
    expect(annotations.single.x1, lessThan(annotations.single.x2));
  });

  testWidgets('a drag in Smooth mode enables Apply to selection', (
    tester,
  ) async {
    await pumpEditor(tester, EditorMode.smooth);
    expect(enabled(tester, 'Apply to Selection'), isFalse);

    await dragAcrossChart(tester);

    expect(enabled(tester, 'Apply to Selection'), isTrue);
  });

  testWidgets('a tap on the chart clears the selection', (tester) async {
    await pumpEditor(tester, EditorMode.select);
    await dragAcrossChart(tester);
    expect(enabled(tester, 'Delete'), isTrue);

    await tester.tapAt(tester.getCenter(find.byType(LineChart)));
    await tester.pump();

    expect(enabled(tester, 'Delete'), isFalse);
  });

  testWidgets('deleting the dragged range edits the profile', (tester) async {
    await pumpEditor(tester, EditorMode.select);
    await dragAcrossChart(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();

    expect(enabled(tester, 'Delete'), isFalse);
    expect(enabled(tester, 'Save'), isTrue);
  });
}
