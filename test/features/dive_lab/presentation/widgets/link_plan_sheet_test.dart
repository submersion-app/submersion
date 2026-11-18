import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/link_plan_sheet.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/providers/plan_repository_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  domain.DivePlanSummary summary(
    String id,
    DateTime updated, {
    String? linkedDiveId,
    int? linkedDiveNumber,
  }) => domain.DivePlanSummary(
    id: id,
    name: 'Plan $id',
    updatedAt: updated,
    linkedDiveId: linkedDiveId,
    linkedDiveNumber: linkedDiveNumber,
  );

  Future<void> pump(
    WidgetTester tester,
    List<domain.DivePlanSummary> plans, {
    String diveId = 'dive-1',
  }) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divePlanSummariesProvider.overrideWith((ref) async => plans),
        ],
        locale: const Locale('en'),
        child: LinkPlanSheet(diveId: diveId),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  List<String> titles(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      (tile.title! as Text).data!,
  ];

  testWidgets('lists free plans newest first, then linked ones', (
    tester,
  ) async {
    await pump(tester, [
      summary('c', DateTime(2026, 3)),
      summary(
        'b',
        DateTime(2026, 2),
        linkedDiveId: 'other',
        linkedDiveNumber: 9,
      ),
      summary('a', DateTime(2026, 1)),
    ]);

    expect(titles(tester), ['Plan c', 'Plan a', 'Plan b']);
  });

  testWidgets('a linked plan is greyed and says which dive it belongs to', (
    tester,
  ) async {
    await pump(tester, [
      summary(
        'b',
        DateTime(2026, 2),
        linkedDiveId: 'other',
        linkedDiveNumber: 9,
      ),
    ]);

    expect(find.textContaining('Dived as #9'), findsOneWidget);
    final title = tester.widget<Text>(find.text('Plan b'));
    final tile = Theme.of(tester.element(find.byType(ListTile)));
    expect(title.style?.color, tile.colorScheme.outline);
  });

  testWidgets('the list stays up while it reloads', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final source = StateProvider<int>((_) => 0);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divePlanSummariesProvider.overrideWith((ref) async {
            if (ref.watch(source) > 0) {
              await Future<void>.delayed(const Duration(seconds: 1));
            }
            return [summary('a', DateTime(2026))];
          }),
        ],
        locale: const Locale('en'),
        child: const LinkPlanSheet(diveId: 'dive-1'),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Plan a'), findsOneWidget);

    ProviderScope.containerOf(
      tester.element(find.byType(LinkPlanSheet)),
    ).read(source.notifier).state++;
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Plan a'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('a short list keeps the sheet short', (tester) async {
    tester.view.physicalSize = const Size(420, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          divePlanSummariesProvider.overrideWith(
            (ref) async => [summary('a', DateTime(2026))],
          ),
        ],
        locale: const Locale('en'),
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showModalBottomSheet<String>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => const LinkPlanSheet(diveId: 'dive-1'),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Plan a'), findsOneWidget);
    expect(tester.getSize(find.byType(LinkPlanSheet)).height, lessThan(300));
  });

  testWidgets('says so when no plans are saved', (tester) async {
    await pump(tester, const []);

    expect(find.text('No saved plans yet'), findsOneWidget);
  });
}
