import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _FakeSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _FakeSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _testProfile() => List.generate(
  61,
  (i) => DiveProfilePoint(
    timestamp: i * 10,
    depth: i < 30 ? i.toDouble() : (60 - i).toDouble(),
  ),
);

Widget _wrap(Widget child) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => _FakeSettingsNotifier())],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('plot fills a bounded-height parent', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 800,
          height: 600,
          child: DiveProfileChart(
            profile: _testProfile(),
            diveDuration: const Duration(minutes: 10),
            maxDepth: 30,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plotHeight = tester.getSize(find.byType(LineChart).first).height;
    // Legend row takes some height; the plot must get the rest -- far more
    // than the old fixed 200.
    expect(plotHeight, greaterThan(400));
  });

  testWidgets('plot keeps 200px default when height is unbounded', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        ListView(
          children: [
            DiveProfileChart(
              profile: _testProfile(),
              diveDuration: const Duration(minutes: 10),
              maxDepth: 30,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    final plotHeight = tester.getSize(find.byType(LineChart).first).height;
    expect(plotHeight, 200);
  });

  testWidgets('legendLeading renders in the legend row', (tester) async {
    await tester.pumpWidget(
      _wrap(
        SizedBox(
          width: 800,
          height: 600,
          child: DiveProfileChart(
            profile: _testProfile(),
            diveDuration: const Duration(minutes: 10),
            maxDepth: 30,
            legendLeading: const Text('LEADING-MARKER'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('LEADING-MARKER'), findsOneWidget);
  });
}
