import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/insights/data/repositories/insights_repository.dart';
import 'package:submersion/features/insights/presentation/pages/insights_conditions_page.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';
import 'package:submersion/features/insights/presentation/widgets/stat_section_card.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #1998: dives with no water type or entry method show as their own
/// Not recorded segment instead of vanishing from the chart.
void main() {
  DistributionSegment seg(String label, int count, double pct) =>
      DistributionSegment(label: label, count: count, percentage: pct);

  Future<void> pumpPage(
    WidgetTester tester, {
    List<DistributionSegment> waterType = const [],
    List<DistributionSegment> entryMethod = const [],
  }) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final base = await getBaseOverrides();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...base,
          visibilityDistributionProvider.overrideWith((ref) async => const []),
          siteTypeDistributionProvider.overrideWith((ref) async => const []),
          waterTypeDistributionProvider.overrideWith((ref) async => waterType),
          entryMethodDistributionProvider.overrideWith(
            (ref) async => entryMethod,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: InsightsConditionsPage(embedded: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inSection(String title, Finder matching) => find.descendant(
    of: find.ancestor(
      of: find.text(title),
      matching: find.byType(StatSectionCard),
    ),
    matching: matching,
  );

  List<Color> waterTypeSliceColors(WidgetTester tester) {
    final chart = tester.widget<PieChart>(
      inSection('Water Type', find.byType(PieChart)),
    );
    return [for (final s in chart.data.sections) s.color];
  }

  group('water type', () {
    testWidgets('shows dives with no water type as Not recorded', (
      tester,
    ) async {
      await pumpPage(
        tester,
        waterType: [
          seg('salt', 8, 40),
          seg('fresh', 11, 55),
          seg(kNotRecordedDistributionKey, 1, 5),
        ],
      );

      expect(
        inSection('Water Type', find.text('Not recorded')),
        findsOneWidget,
      );
      expect(find.text(kNotRecordedDistributionKey), findsNothing);
      final chart = tester.widget<PieChart>(
        inSection('Water Type', find.byType(PieChart)),
      );
      expect(chart.data.sections.map((s) => s.title), ['40%', '55%', '5%']);
    });

    testWidgets('gives every water type its own slice color', (tester) async {
      await pumpPage(
        tester,
        waterType: [
          seg('salt', 4, 40),
          seg('fresh', 3, 30),
          seg('brackish', 2, 20),
          seg(kNotRecordedDistributionKey, 1, 10),
        ],
      );

      final colors = waterTypeSliceColors(tester);
      expect(colors, hasLength(4));
      expect(colors.toSet(), hasLength(4));
    });

    testWidgets('gives an unrecognized key a color of its own', (tester) async {
      // Only a repository change could emit one; it must still get a slice
      // that does not pass for one of the known water types.
      await pumpPage(
        tester,
        waterType: [
          seg('salt', 1, 25),
          seg('fresh', 1, 25),
          seg('brackish', 1, 25),
          seg('mystery', 1, 25),
        ],
      );

      final colors = waterTypeSliceColors(tester);
      expect(colors.toSet(), hasLength(4));
      expect(inSection('Water Type', find.text('mystery')), findsOneWidget);
    });

    testWidgets('keeps a water type color when the order changes', (
      tester,
    ) async {
      await pumpPage(
        tester,
        waterType: [seg('salt', 2, 67), seg('fresh', 1, 33)],
      );
      final saltFirst = waterTypeSliceColors(tester).first;

      // Unmount first: a remounted ProviderScope would keep the cached list.
      await tester.pumpWidget(const SizedBox());
      await pumpPage(
        tester,
        waterType: [seg('fresh', 2, 67), seg('salt', 1, 33)],
      );
      final saltSecond = waterTypeSliceColors(tester)[1];

      expect(saltSecond, saltFirst);
    });
  });

  group('entry method', () {
    testWidgets('shows dives with no entry method as Not recorded', (
      tester,
    ) async {
      await pumpPage(
        tester,
        entryMethod: [
          seg('boat', 6, 60),
          seg(kNotRecordedDistributionKey, 4, 40),
        ],
      );

      expect(
        inSection('Entry Method', find.text('Not recorded')),
        findsOneWidget,
      );
      expect(find.text(kNotRecordedDistributionKey), findsNothing);
    });
  });
}
