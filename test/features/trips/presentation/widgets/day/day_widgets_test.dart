import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/trips/domain/services/day_conditions.dart';
import 'package:submersion/features/trips/domain/services/day_plan_progress.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_conditions_line.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_format.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_plan_line.dart';
import 'package:submersion/features/trips/presentation/widgets/day/day_weather_badge.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_card_shape.dart';
import 'package:submersion/features/trips/presentation/widgets/day/today_chip.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

const _metric = UnitFormatter(AppSettings());

String _lineText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('day-conditions-line'))).data!;

void main() {
  test('runtime reads hours and minutes', () {
    expect(formatDayRuntime(const Duration(minutes: 102)), '1h 42m');
    expect(formatDayRuntime(const Duration(minutes: 45)), '45m');
  });

  testWidgets('today chip says Today', (tester) async {
    await _pump(tester, const TodayChip());
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('conditions line shows ranges and single values', (tester) async {
    await _pump(
      tester,
      const DayConditionsLine(
        conditions: DayConditions(
          minWaterTemp: 26,
          maxWaterTemp: 28,
          legacyVisibility: VisibilityBand.good,
          minCurrent: CurrentStrength.light,
          maxCurrent: CurrentStrength.light,
        ),
        units: _metric,
      ),
    );
    final text = _lineText(tester);
    expect(text, contains('Water 26°C to 28°C'));
    expect(text, contains('Vis Good'));
    expect(text, contains('Current Light'));
    expect(text, isNot(contains('Light to Light')));
  });

  testWidgets('conditions line follows imperial units', (tester) async {
    const imperial = UnitFormatter(
      AppSettings(
        temperatureUnit: TemperatureUnit.fahrenheit,
        depthUnit: DepthUnit.feet,
      ),
    );
    await _pump(
      tester,
      const DayConditionsLine(
        conditions: DayConditions(
          minWaterTemp: 26,
          maxWaterTemp: 26,
          minVisibilityMeters: 12,
          maxVisibilityMeters: 20,
        ),
        units: imperial,
      ),
    );
    final text = _lineText(tester);
    expect(text, contains('Water 79°F'));
    expect(text, contains('Vis 39ft to 66ft'));
    expect(text, isNot(contains('°C')));
  });

  testWidgets('empty conditions render nothing', (tester) async {
    await _pump(
      tester,
      const DayConditionsLine(conditions: DayConditions(), units: _metric),
    );
    expect(find.byKey(const Key('day-conditions-line')), findsNothing);
  });

  testWidgets('plan line reads progress, or a plan when upcoming', (
    tester,
  ) async {
    await _pump(
      tester,
      const Column(
        children: [
          DayPlanLine(
            progress: DayPlanProgress(planned: 3, logged: 4, upcoming: false),
          ),
          DayPlanLine(
            progress: DayPlanProgress(planned: 1, logged: 0, upcoming: false),
          ),
          DayPlanLine(
            progress: DayPlanProgress(planned: 2, logged: 0, upcoming: true),
          ),
        ],
      ),
    );
    expect(find.text('4 of 3 planned dives'), findsOneWidget);
    expect(find.text('0 of 1 planned dive'), findsOneWidget);
    expect(find.text('2 dives planned'), findsOneWidget);
  });

  testWidgets('weather badge shows the air temperature', (tester) async {
    await _pump(
      tester,
      const DayWeatherBadge(
        weather: TripStoryDayWeather(airTemp: 29),
        units: _metric,
      ),
    );
    expect(find.text('29°C'), findsOneWidget);
  });

  test('a badge renders only when it has an icon or a temperature', () {
    expect(DayWeatherBadge.rendersAnything(null), isFalse);
    expect(
      DayWeatherBadge.rendersAnything(
        const TripStoryDayWeather(precipitation: Precipitation.none),
      ),
      isFalse,
    );
    expect(
      DayWeatherBadge.rendersAnything(
        const TripStoryDayWeather(cloudCover: CloudCover.clear),
      ),
      isTrue,
    );
  });

  group('today card shape', () {
    test("keeps the theme's card corners and adds a primary edge", () {
      final theme = ThemeData(
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      );
      final shape = todayCardShape(theme);
      expect(shape.borderRadius, BorderRadius.circular(20));
      expect(shape.side.color, theme.colorScheme.primary);
      expect(shape.side.width, 2);
    });

    test('a planned day keeps the same corners with its quiet edge', () {
      final theme = ThemeData(
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
      );
      final side = BorderSide(color: theme.colorScheme.outlineVariant);
      final shape = dayCardShape(theme, side);
      expect(shape.borderRadius, BorderRadius.circular(4));
      expect(shape.side, side);
    });

    test('falls back to the Material card radius without a themed shape', () {
      expect(
        todayCardShape(ThemeData()).borderRadius,
        BorderRadius.circular(12),
      );
    });
  });
}
