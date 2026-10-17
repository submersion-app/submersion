import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/summary_pane_view.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_pane.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_scene.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_widget.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/summary/summary_pane_switcher.dart';

import '../../../../helpers/mock_providers.dart';
import 'site_summary_scene_facts_test.dart' show library;

void main() {
  Future<void> pumpPane(
    WidgetTester tester, {
    Future<List<SiteWithDiveCount>> Function()? sites,
    AppSettings settings = const AppSettings(),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(900, 700);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(settings),
    );
    final router = GoRouter(
      initialLocation: '/sites',
      routes: [
        GoRoute(
          path: '/sites',
          builder: (_, _) => const Scaffold(body: SiteSummaryPane()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          sitesWithCountsProvider.overrideWith(
            (ref) => (sites ?? () async => library)(),
          ),
        ].cast(),
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('shows the scene by default', (tester) async {
    await pumpPane(tester);

    expect(find.byType(SiteSummaryScene), findsOneWidget);
    expect(find.byType(SiteSummaryWidget), findsNothing);
  });

  testWidgets('shows the details when the setting says details', (
    tester,
  ) async {
    await pumpPane(
      tester,
      settings: const AppSettings(summaryPaneView: SummaryPaneView.details),
    );

    expect(find.byType(SiteSummaryWidget), findsOneWidget);
    expect(find.byType(SiteSummaryScene), findsNothing);
  });

  testWidgets('an empty library shows the details and keeps the toggle', (
    tester,
  ) async {
    await pumpPane(tester, sites: () async => []);

    expect(find.byType(SiteSummaryWidget), findsOneWidget);
    expect(find.byType(SummaryPaneToggle), findsOneWidget);
  });

  testWidgets('a loading library shows the scene, not the details', (
    tester,
  ) async {
    final never = Completer<List<SiteWithDiveCount>>();
    await pumpPane(tester, sites: () => never.future);

    expect(find.byType(SiteSummaryScene), findsOneWidget);
    expect(find.byType(SiteSummaryWidget), findsNothing);
  });
}
