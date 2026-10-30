import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/theme/full_themes/submersion_theme.dart';
import 'package:submersion/features/dive_log/data/services/profile_markers_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_editor_chart.dart';
import 'package:submersion/features/dive_log/presentation/widgets/range_selection_overlay.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

// Marker dots and range grips wore a fixed white ring to punch them out of
// the lines beneath. On a dark chart that ring glared as a bright halo; it
// should be the colour behind the chart instead: the page, or the card it
// sits on.
// Presets give cards their own colour (Console dark's #1A2230 card on a
// #141A22 page), and these charts usually sit on a card.
const _cardColour = Color(0xFF1A2230);
final _theme = submersionDark.copyWith(
  cardTheme: const CardThemeData(color: _cardColour),
);

List<DiveProfilePoint> _profile() => List.generate(
  20,
  (i) => DiveProfilePoint(
    timestamp: i * 30,
    depth: i < 10 ? i * 2.0 : (19 - i) * 2.0,
  ),
);

Widget _host(bool onCard, Widget chart) => ProviderScope(
  overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
  child: MaterialApp(
    theme: _theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: onCard ? Card(child: chart) : chart,
      ),
    ),
  ),
);

/// The ring colour of every two-pixel-ringed dot the chart paints.
List<Color> _ringColors(WidgetTester tester) => [
  for (final bar
      in tester
          .widget<LineChart>(find.byType(LineChart).first)
          .data
          .lineBarsData)
    if (bar.dotData.show)
      for (var i = 0; i < bar.spots.length; i++)
        if (bar.dotData.getDotPainter(bar.spots[i], 0, bar, i)
            case FlDotCirclePainter(strokeWidth: 2, :final strokeColor))
          strokeColor,
];

void main() {
  for (final onCard in [false, true]) {
    final backdrop = onCard ? _cardColour : _theme.colorScheme.surface;
    final where = onCard ? 'on a card' : 'on the page';

    testWidgets(
      'the max depth and gas switch dots ring in the backdrop colour $where',
      (tester) async {
        await tester.pumpWidget(
          _host(
            onCard,
            DiveProfileChart(
              profile: _profile(),
              showMaxDepthMarker: true,
              markers: const [
                ProfileMarker(
                  timestamp: 270,
                  depth: 18,
                  type: ProfileMarkerType.maxDepth,
                ),
              ],
              gasSwitches: [
                GasSwitchWithTank(
                  gasSwitch: GasSwitch(
                    id: 'gs1',
                    diveId: 'd1',
                    timestamp: 300,
                    tankId: 't1',
                    depth: 12,
                    createdAt: DateTime.utc(2026),
                  ),
                  tankName: 'Stage',
                  gasMix: 'EAN50',
                  o2Fraction: 0.5,
                ),
              ],
              tooltipPresentation: TooltipPresentation.external,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rings = _ringColors(tester);
        expect(rings, hasLength(2), reason: 'max depth and gas switch dots');
        expect(rings, everyElement(backdrop));
      },
    );

    testWidgets('a drawn waypoint rings in the backdrop colour $where', (
      tester,
    ) async {
      final profile = _profile();
      await tester.pumpWidget(
        _host(
          onCard,
          ProfileEditorChart(
            originalProfile: profile,
            editedProfile: profile,
            mode: EditorMode.draw,
            waypoints: const [ProfileWaypoint(timestamp: 90, depth: 6)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rings = _ringColors(tester);
      expect(rings, isNotEmpty);
      expect(rings, everyElement(backdrop));
    });

    testWidgets('the range grips ring in the backdrop colour $where', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          onCard,
          DiveProfileChart(
            profile: _profile(),
            rangeSelection: (
              startSeconds: 60,
              endSeconds: 480,
              maxSeconds: 570,
            ),
            onRangeChanged: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final gripBorders = [
        for (final box in tester.widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(RangeSelectionOverlay),
            matching: find.byType(DecoratedBox),
          ),
        ))
          if (box.decoration case BoxDecoration(
            shape: BoxShape.circle,
            border: Border(:final top),
          ))
            top.color,
      ];
      expect(gripBorders, hasLength(4), reason: 'two grips per handle');
      expect(gripBorders, everyElement(backdrop));
    });
  }
}
