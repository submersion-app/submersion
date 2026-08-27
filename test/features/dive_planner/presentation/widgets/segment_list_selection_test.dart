import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/segment_list.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Widget harness() => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: const SingleChildScrollView(child: SegmentList()),
  );

  ListTile tileAt(WidgetTester tester, int index) =>
      tester.widgetList<ListTile>(find.byType(ListTile)).elementAt(index);

  testWidgets('provider selection highlights the matching tile', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SegmentList)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();

    final segments = container.read(divePlanNotifierProvider).segments;
    expect(segments.length, greaterThanOrEqualTo(2));

    container.read(selectedSegmentIdProvider.notifier).state = segments[1].id;
    await tester.pumpAndSettle();

    expect(tileAt(tester, 0).selected, isFalse);
    expect(tileAt(tester, 1).selected, isTrue);
  });

  testWidgets('tapping a tile drives the selection provider', (tester) async {
    await tester.pumpWidget(harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SegmentList)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    await tester.pumpAndSettle();
    final segments = container.read(divePlanNotifierProvider).segments;

    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    expect(container.read(selectedSegmentIdProvider), segments.first.id);
  });
}
