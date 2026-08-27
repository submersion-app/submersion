import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_deco_section.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/presentation/panes/plan_setup_accordion.dart';
import 'package:submersion/features/planner/presentation/providers/planner_layout_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/ccr_settings_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/test_app.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _harness() => testApp(
  overrides: [settingsProvider.overrideWith((ref) => _TestSettingsNotifier())],
  locale: const Locale('en'),
  child: const SingleChildScrollView(child: PlanSetupAccordion()),
);

void main() {
  testWidgets('renders all sections collapsed; CCR hidden on OC plans', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(6));
    expect(find.byType(CcrSettingsSection), findsNothing);
    expect(find.byType(PlanDecoSection), findsNothing);
  });

  testWidgets('tapping a section expands its content', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Decompression'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanDecoSection), findsOneWidget);
  });

  testWidgets('sections with text fields expand without PageStorage crash', (
    tester,
  ) async {
    // Regression: ExpansionTile + PageStorageKey persisted a bool that the
    // reserve TextField's Scrollable read back as a double scroll offset.
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gas'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsWidgets);

    await tester.tap(find.text('Environment'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('CCR section appears for CCR plans', (tester) async {
    await tester.pumpWidget(_harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    container
        .read(divePlanNotifierProvider.notifier)
        .updateMode(domain.PlanMode.ccr);
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsNWidgets(7));
    expect(find.text('CCR'), findsOneWidget);
  });

  testWidgets('setup focus expands the requested section and clears', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    container.read(setupFocusSectionProvider.notifier).state = 'deco';
    await tester.pumpAndSettle();
    expect(find.byType(PlanDecoSection), findsOneWidget);
    expect(container.read(setupFocusSectionProvider), isNull);
  });

  testWidgets('setup focus on an unavailable section still clears', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PlanSetupAccordion)),
    );
    // 'ccr' has no section on an OC plan (no controller registered). The focus
    // must still be consumed, or it would re-schedule work on every rebuild.
    container.read(setupFocusSectionProvider.notifier).state = 'ccr';
    await tester.pumpAndSettle();
    expect(container.read(setupFocusSectionProvider), isNull);
  });
}
