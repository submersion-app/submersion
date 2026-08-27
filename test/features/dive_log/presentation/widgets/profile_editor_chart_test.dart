import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_editor_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  Future<void> setMapStyle(MapStyle style) async =>
      state = state.copyWith(mapStyle: style);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DiveProfilePoint> _makeProfile({int points = 10}) {
  return List.generate(
    points,
    (i) => DiveProfilePoint(
      timestamp: i * 30,
      depth: (i < points / 2 ? i * 3.0 : (points - i) * 3.0),
    ),
  );
}

Widget _buildChart() {
  final profile = _makeProfile();
  return ProviderScope(
    overrides: [
      settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 300,
          child: ProfileEditorChart(
            originalProfile: profile,
            editedProfile: profile,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ProfileEditorChart', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileEditorChart), findsOneWidget);
    });

    testWidgets('chart data changes are not implicitly animated', (
      tester,
    ) async {
      await tester.pumpWidget(_buildChart());
      await tester.pumpAndSettle();

      // Editing rebuilds the chart data (adding a waypoint shifts marker
      // indices; range selection shading tracks the pointer). fl_chart's
      // default 150ms lerp would slide markers between unrelated positions
      // and lag the selection behind the cursor, so the editor must render
      // every data change immediately.
      final chart = tester.widget<LineChart>(find.byType(LineChart));
      expect(chart.duration, Duration.zero);
    });
  });
}
