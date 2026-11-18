import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_text_suggestion_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_card_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_fields.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weather/data/services/elevation_service.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../../../helpers/mock_providers.dart';
import '../../../../../../helpers/test_database.dart';

http.Client _noNetwork() => MockClient((_) async => http.Response('', 500));

/// Answers a weather fetch from a fixed forecast, or with nothing, or by
/// failing, and can hold the answer until released.
class _FakeWeather extends WeatherService {
  _FakeWeather({this.data, this.gate, this.fail = false})
    : super(client: _noNetwork());

  final WeatherData? data;
  final Completer<void>? gate;
  final bool fail;
  final asked =
      <({double latitude, double longitude, DateTime date, DateTime entry})>[];

  @override
  Future<WeatherData?> fetchWeather({
    required double latitude,
    required double longitude,
    required DateTime date,
    required DateTime entryTime,
  }) async {
    asked.add((
      latitude: latitude,
      longitude: longitude,
      date: date,
      entry: entryTime,
    ));
    await gate?.future;
    if (fail) throw StateError('offline');
    return data;
  }
}

class _FakeElevation extends ElevationService {
  _FakeElevation({this.result, this.gate}) : super(client: _noNetwork());

  final double? result;
  final Completer<void>? gate;
  int calls = 0;

  @override
  Future<double?> fetchElevation({
    required double latitude,
    required double longitude,
  }) async {
    calls++;
    await gate?.future;
    return result;
  }
}

const _cardId = 'environment';

const _forecast = WeatherData(
  windSpeed: 5,
  windDirection: CurrentDirection.northWest,
  cloudCover: CloudCover.overcast,
  precipitation: Precipitation.drizzle,
  humidity: 70,
  airTemp: 24,
  surfacePressure: 1.009,
);

/// The Environment card of the dive page, edited in place (issue #4527).
void main() {
  final bare = Dive(id: 'dive', dateTime: DateTime(2024, 6, 1, 10));
  const reef = DiveSite(
    id: 'site-1',
    name: 'Reef',
    location: GeoPoint(-16.5, 145.8),
  );
  final full = bare.copyWith(
    airTemp: 21,
    windSpeed: 4,
    windDirection: CurrentDirection.east,
    cloudCover: CloudCover.clear,
    precipitation: Precipitation.none,
    humidity: 60,
    weatherDescription: 'Fine',
    weatherSource: WeatherSource.manual,
    weatherFetchedAt: DateTime(2024, 6, 2),
    currentDirection: CurrentDirection.north,
    currentStrength: CurrentStrength.light,
    swellHeight: 1.5,
    surfaceConditions: 'Calm',
    entryMethod: EntryMethod.shore,
    exitMethod: EntryMethod.boat,
  );

  group('the editor', () {
    setUp(setUpTestDatabase);
    tearDown(tearDownTestDatabase);

    Future<RecordEditController<Dive>> pumpEditor(
      WidgetTester tester,
      Dive dive, {
      AppSettings settings = const AppSettings(),
      WeatherService? weather,
      ElevationService? elevation,
      bool showEditor = true,
      RecordEditController<Dive>? controller,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(tester.view.reset);
      final edit =
          controller ??
          (RecordEditController<Dive>(onSave: (_) async {})
            ..unlock(dive)
            ..openCard(_cardId));
      if (controller == null) addTearDown(edit.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(
              settingsNotifier: MockSettingsNotifier(settings),
            ),
            weatherServiceProvider.overrideWithValue(weather ?? _FakeWeather()),
            elevationServiceProvider.overrideWithValue(
              elevation ?? _FakeElevation(),
            ),
            diveTextSuggestionsProvider.overrideWith(
              (ref, field) async => const <String>[],
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: RecordEditScope<Dive>(
                  controller: edit,
                  child: showEditor
                      ? DiveEnvironmentCardEditor(session: edit.session!)
                      : const SizedBox(key: ValueKey('gone')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return edit;
    }

    AppLocalizations l10nOf(WidgetTester tester) =>
        AppLocalizations.of(tester.element(find.byType(Scaffold)));

    Finder fetchButton() => find.ancestor(
      of: find.text('Fetch Weather'),
      matching: find.byWidgetPredicate((w) => w is TextButton),
    );

    bool fetchEnabled(WidgetTester tester) =>
        tester.widget<TextButton>(fetchButton()).onPressed != null;

    /// The text field of the row labelled [label], once that row is open.
    Finder fieldOf(String label) => find.descendant(
      of: find.widgetWithText(FormRow, label),
      matching: find.byType(TextFormField),
    );

    Future<void> tapFetch(WidgetTester tester) async {
      await tester.tap(find.text('Fetch Weather'));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('rows show in the order of the read card', (tester) async {
      await pumpEditor(tester, full.copyWith(surfacePressure: 0.87));
      final l10n = l10nOf(tester);

      final labels = [
        l10n.diveLog_detail_subsection_weather.toUpperCase(),
        l10n.diveLog_edit_label_airTemp,
        l10n.diveLog_edit_label_surfacePressure,
        l10n.diveLog_edit_label_windSpeed,
        l10n.diveLog_edit_label_windDirection,
        l10n.diveLog_edit_label_cloudCover,
        l10n.diveLog_edit_label_precipitation,
        l10n.diveLog_edit_label_humidity,
        l10n.diveLog_edit_label_weatherDescription,
        l10n.diveLog_detail_subsection_diveConditions.toUpperCase(),
        l10n.diveLog_edit_label_currentDirection,
        l10n.diveLog_edit_label_currentStrength,
        l10n.diveLog_edit_label_swellHeight,
        l10n.diveLog_edit_label_surfaceConditions,
        l10n.diveLog_edit_label_entryMethod,
        l10n.diveLog_edit_label_exitMethod,
      ];
      final tops = [
        for (final label in labels) tester.getTopLeft(find.text(label)).dy,
      ];
      for (var i = 1; i < tops.length; i++) {
        expect(
          tops[i],
          greaterThan(tops[i - 1]),
          reason: '${labels[i]} should sit below ${labels[i - 1]}',
        );
      }
    });

    testWidgets('values show in the diver\'s units and the sitting is clean', (
      tester,
    ) async {
      final controller = await pumpEditor(
        tester,
        full,
        settings: const AppSettings(
          depthUnit: DepthUnit.feet,
          temperatureUnit: TemperatureUnit.fahrenheit,
        ),
      );

      // Worked out by hand: 21 C is 69.8 F; 1.5 m is 4.92 ft, shown to one
      // place.
      expect(find.text('69.8 °F'), findsOneWidget);
      expect(find.text('4.9 ft'), findsOneWidget);
      expect(find.text('60 %'), findsOneWidget);
      expect(controller.isDirty, isFalse);
    });

    // The read card shows a temperature to one decimal, without a trailing
    // zero. A row that showed fewer could not be used to round the value.
    testWidgets('air temperature shows the decimals the read card shows', (
      tester,
    ) async {
      final controller = await pumpEditor(tester, full.copyWith(airTemp: 21.4));
      expect(find.text('21.4 °C'), findsOneWidget);

      await tester.tap(find.text('21.4 °C'));
      await tester.pump();
      await tester.enterText(
        fieldOf(l10nOf(tester).diveLog_edit_label_airTemp),
        '21',
      );
      await tester.pump();

      expect(controller.session!.valueOf(diveAirTempField), 21);
    });

    testWidgets('a whole air temperature shows no decimals', (tester) async {
      await pumpEditor(tester, full);

      expect(find.text('21 °C'), findsOneWidget);
    });

    // The read card shows "18 km/h"; the row showed "18.0 km/h" beside it.
    testWidgets('a whole wind speed shows no decimals', (tester) async {
      await pumpEditor(tester, full.copyWith(windSpeed: 5));

      expect(find.text('18 km/h'), findsOneWidget);
    });

    // A wind speed with a decimal keeps it, so the row can still round it.
    testWidgets('a wind speed with a decimal keeps it', (tester) async {
      await pumpEditor(tester, full);

      expect(find.text('14.4 km/h'), findsOneWidget);
    });

    testWidgets('typing an air temperature in Fahrenheit stores Celsius', (
      tester,
    ) async {
      final controller = await pumpEditor(
        tester,
        full,
        settings: const AppSettings(
          temperatureUnit: TemperatureUnit.fahrenheit,
        ),
      );

      final airTemp = fieldOf(l10nOf(tester).diveLog_edit_label_airTemp);
      await tester.tap(find.text('69.8 °F'));
      await tester.pump();
      await tester.enterText(airTemp, '50');
      await tester.pump();

      expect(controller.session!.valueOf(diveAirTempField), closeTo(10, 0.001));
    });

    testWidgets('a negative humidity is refused, a negative air '
        'temperature is not', (tester) async {
      final controller = await pumpEditor(tester, full);
      final l10n = l10nOf(tester);
      final humidity = fieldOf(l10n.diveLog_edit_label_humidity);
      final airTemp = fieldOf(l10n.diveLog_edit_label_airTemp);

      await tester.tap(find.text('60 %'));
      await tester.pump();
      await tester.enterText(humidity, '-5');
      await tester.pump();
      expect(controller.invalidCardIds, {_cardId});
      await tester.enterText(humidity, '55');
      await tester.pump();
      expect(controller.invalidCardIds, isEmpty);

      await tester.tap(find.text('21 °C'));
      await tester.pump();
      await tester.enterText(airTemp, '-5');
      await tester.pump();
      expect(controller.invalidCardIds, isEmpty);
      expect(controller.session!.valueOf(diveAirTempField), -5);
    });

    testWidgets('a stored surface pressure shows as a row that cannot be '
        'typed in', (tester) async {
      final controller = await pumpEditor(
        tester,
        full.copyWith(surfacePressure: 0.87),
      );

      final label = l10nOf(tester).diveLog_edit_label_surfacePressure;
      expect(find.text('870 mbar'), findsOneWidget);
      await tester.tap(find.text('870 mbar'));
      await tester.pump();

      expect(find.widgetWithText(FormRow, label), findsOneWidget);
      expect(fieldOf(label), findsNothing);
      expect(controller.isDirty, isFalse);
    });

    // The pressure is edited on the Altitude card, so its row here leads
    // there: the card is opened, brought in from the Add strip if the page
    // was leaving it out, and asked to scroll into view.
    testWidgets('the surface pressure row opens the Altitude card', (
      tester,
    ) async {
      final controller = await pumpEditor(
        tester,
        full.copyWith(surfacePressure: 0.87),
      );

      await tester.tap(find.text('870 mbar'));
      await tester.pump();

      final altitude = diveSurfacePressureField.cardId;
      expect(controller.openCardIds, containsAll([_cardId, altitude]));
      expect(controller.revealRequest?.cardId, altitude);
      expect(controller.isDirty, isFalse);
    });

    testWidgets('with no surface pressure there is no such row', (
      tester,
    ) async {
      await pumpEditor(tester, full);

      expect(
        find.text(l10nOf(tester).diveLog_edit_label_surfacePressure),
        findsNothing,
      );
    });

    testWidgets('typing a description sets it, and emptying clears it', (
      tester,
    ) async {
      final controller = await pumpEditor(tester, full);

      final description = fieldOf(
        l10nOf(tester).diveLog_edit_label_weatherDescription,
      );
      await tester.tap(find.text('Fine'));
      await tester.pump();
      await tester.enterText(description, 'Windy');
      await tester.pump();
      expect(controller.session!.valueOf(diveWeatherDescriptionField), 'Windy');

      await tester.enterText(description, '');
      await tester.pump();
      expect(controller.session!.working.weatherDescription, isNull);
    });

    // The read card shows a fetched dive's forecast, not its stored words.
    // Words the diver types here must be the ones it shows afterwards.
    testWidgets('a description typed on fetched weather makes the weather '
        'the diver\'s own', (tester) async {
      final controller = await pumpEditor(
        tester,
        full.copyWith(weatherSource: WeatherSource.openMeteo),
      );

      await tester.tap(find.text('Fine'));
      await tester.pump();
      await tester.enterText(
        fieldOf(l10nOf(tester).diveLog_edit_label_weatherDescription),
        'Squalls',
      );
      await tester.pump();

      expect(controller.session!.working.weatherDescription, 'Squalls');
      expect(controller.session!.working.weatherSource, WeatherSource.manual);
    });

    testWidgets('a sky picked on fetched weather drops the forecast code', (
      tester,
    ) async {
      final controller = await pumpEditor(
        tester,
        full.copyWith(weatherSource: WeatherSource.openMeteo, weatherCode: 80),
      );
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.diveLog_edit_label_precipitation));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Snow'));
      await tester.pumpAndSettle();

      expect(controller.session!.working.precipitation, Precipitation.snow);
      expect(controller.session!.working.weatherCode, isNull);
    });

    testWidgets('the entry row hints the site method when the dive has none', (
      tester,
    ) async {
      const jetty = DiveSite(
        id: 'site-1',
        name: 'Pier',
        entryMethods: [EntryMethod.jetty],
      );
      final controller = await pumpEditor(tester, bare.copyWith(site: jetty));

      // Entry shows the site's method as its hint; exit has no such hint.
      expect(find.text('Jetty/Dock'), findsOneWidget);
      expect(find.text('Not specified'), findsWidgets);
      expect(controller.session!.valueOf(diveEntryMethodField), isNull);
      expect(controller.isDirty, isFalse);

      // In the sheet the hint is not a choice: clearing keeps its own name,
      // and the site's method is listed once, as the method it is.
      await tester.tap(
        find.text(l10nOf(tester).diveLog_edit_label_entryMethod),
      );
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Not specified'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Jetty/Dock'), findsOneWidget);
    });

    testWidgets('an exit the diver cleared stays cleared when the entry '
        'changes', (tester) async {
      final controller = await pumpEditor(
        tester,
        bare.copyWith(
          entryMethod: EntryMethod.shore,
          exitMethod: EntryMethod.shore,
        ),
      );
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.diveLog_edit_label_exitMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Not specified'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.diveLog_edit_label_entryMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Boat'));
      await tester.pumpAndSettle();

      expect(controller.session!.working.entryMethod, EntryMethod.boat);
      expect(controller.session!.working.exitMethod, isNull);
    });

    testWidgets('an exit picked to match the entry no longer follows it', (
      tester,
    ) async {
      final controller = await pumpEditor(
        tester,
        bare.copyWith(
          entryMethod: EntryMethod.shore,
          exitMethod: EntryMethod.boat,
        ),
      );
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.diveLog_edit_label_exitMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Shore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.diveLog_edit_label_entryMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Ladder'));
      await tester.pumpAndSettle();

      expect(controller.session!.working.entryMethod, EntryMethod.ladder);
      expect(controller.session!.working.exitMethod, EntryMethod.shore);
    });

    // Whether the exit follows is settled when the editor opens. A change
    // underneath that makes the two alike afterwards does not link them.
    testWidgets('an exit that did not follow when editing began does not '
        'start to', (tester) async {
      final stored = bare.copyWith(
        entryMethod: EntryMethod.shore,
        exitMethod: EntryMethod.boat,
      );
      final controller = await pumpEditor(tester, stored);
      final l10n = l10nOf(tester);

      controller.storedChanged(stored.copyWith(exitMethod: EntryMethod.shore));
      await tester.pump();
      await tester.tap(find.text(l10n.diveLog_edit_label_entryMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Ladder'));
      await tester.pumpAndSettle();

      expect(controller.session!.working.entryMethod, EntryMethod.ladder);
      expect(controller.session!.working.exitMethod, EntryMethod.shore);
    });

    // The direct edit belongs to the sitting, not to the editor: closing
    // the card and opening it again does not link the two (plan 4).
    testWidgets('an exit picked equal to the entry stays the diver\'s after '
        'a reopen', (tester) async {
      final stored = bare.copyWith(
        entryMethod: EntryMethod.shore,
        exitMethod: EntryMethod.boat,
      );
      final controller = await pumpEditor(tester, stored);
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.diveLog_edit_label_exitMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Shore'));
      await tester.pumpAndSettle();
      await pumpEditor(
        tester,
        stored,
        controller: controller,
        showEditor: false,
      );
      await pumpEditor(tester, stored, controller: controller);
      await tester.tap(find.text(l10n.diveLog_edit_label_entryMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Ladder'));
      await tester.pumpAndSettle();

      expect(controller.session!.working.entryMethod, EntryMethod.ladder);
      expect(controller.session!.working.exitMethod, EntryMethod.shore);
    });

    testWidgets('picking an entry method carries a linked exit with it', (
      tester,
    ) async {
      final controller = await pumpEditor(tester, bare);
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.diveLog_edit_label_entryMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shore').last);
      await tester.pumpAndSettle();

      expect(controller.session!.working.entryMethod, EntryMethod.shore);
      expect(controller.session!.working.exitMethod, EntryMethod.shore);
    });

    testWidgets('picking an exit method leaves the entry alone', (
      tester,
    ) async {
      final controller = await pumpEditor(
        tester,
        bare.copyWith(entryMethod: EntryMethod.shore),
      );
      final l10n = l10nOf(tester);

      await tester.tap(find.text(l10n.diveLog_edit_label_exitMethod));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ladder').last);
      await tester.pumpAndSettle();

      expect(controller.session!.working.entryMethod, EntryMethod.shore);
      expect(controller.session!.working.exitMethod, EntryMethod.ladder);
    });

    group('Fetch', () {
      testWidgets('is disabled for a dive whose site has no coordinates', (
        tester,
      ) async {
        await pumpEditor(
          tester,
          bare.copyWith(
            site: const DiveSite(id: 's', name: 'Somewhere'),
          ),
        );
        expect(fetchEnabled(tester), isFalse);

        await pumpEditor(tester, bare);
        expect(fetchEnabled(tester), isFalse);
      });

      testWidgets('asks for the site and the dive date', (tester) async {
        final weather = _FakeWeather(data: _forecast);
        await pumpEditor(
          tester,
          bare.copyWith(site: reef, entryTime: DateTime(2024, 6, 1, 14, 30)),
          weather: weather,
        );
        expect(fetchEnabled(tester), isTrue);

        await tapFetch(tester);

        final asked = weather.asked.single;
        expect(asked.latitude, -16.5);
        expect(asked.longitude, 145.8);
        expect(asked.date, DateTime(2024, 6, 1, 10));
        expect(asked.entry, DateTime(2024, 6, 1, 14, 30));
      });

      testWidgets('fills the rows and says so', (tester) async {
        final controller = await pumpEditor(
          tester,
          bare.copyWith(site: reef),
          weather: _FakeWeather(data: _forecast),
        );

        await tapFetch(tester);

        expect(find.text('Weather data loaded'), findsOneWidget);
        // 5 m/s is 18 km/h.
        expect(find.text('18 km/h'), findsOneWidget);
        expect(find.text('24 °C'), findsOneWidget);
        expect(find.text('70 %'), findsOneWidget);
        expect(find.text('1009 mbar'), findsOneWidget);
        final dive = controller.session!.working;
        expect(dive.weatherSource, WeatherSource.openMeteo);
        expect(dive.weatherFetchedAt, isNotNull);
        expect(dive.cloudCover, CloudCover.overcast);
      });

      testWidgets('asks first when weather values are already set', (
        tester,
      ) async {
        final weather = _FakeWeather(data: _forecast);
        final controller = await pumpEditor(
          tester,
          full.copyWith(site: reef),
          weather: weather,
        );
        final l10n = l10nOf(tester);

        await tapFetch(tester);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text(l10n.diveLog_edit_fetchWeatherConfirm),
          ),
          // Asked once: the question is the dialog's title, with no body
          // repeating it.
          findsOneWidget,
        );
        await tester.tap(find.text(l10n.common_action_cancel));
        await tester.pumpAndSettle();

        expect(weather.asked, isEmpty);
        expect(controller.isDirty, isFalse);

        await tapFetch(tester);
        await tester.tap(find.text(l10n.common_action_ok));
        await tester.pumpAndSettle();

        expect(weather.asked, hasLength(1));
        expect(controller.session!.working.humidity, 70);
      });

      testWidgets('does not ask when only an air temperature is set', (
        tester,
      ) async {
        final weather = _FakeWeather(data: _forecast);
        final controller = await pumpEditor(
          tester,
          bare.copyWith(site: reef, airTemp: 21),
          weather: weather,
        );

        await tapFetch(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(weather.asked, hasLength(1));
        // Filled only when empty: the typed temperature stays.
        expect(controller.session!.working.airTemp, 21);
      });

      testWidgets('with no forecast says so and changes nothing', (
        tester,
      ) async {
        final controller = await pumpEditor(
          tester,
          bare.copyWith(site: reef),
          weather: _FakeWeather(),
        );

        await tapFetch(tester);

        expect(
          find.text('Weather data unavailable for this date'),
          findsOneWidget,
        );
        expect(controller.isDirty, isFalse);
        expect(fetchEnabled(tester), isTrue);
      });

      testWidgets('that fails says it is unavailable and changes nothing', (
        tester,
      ) async {
        final controller = await pumpEditor(
          tester,
          bare.copyWith(site: reef),
          weather: _FakeWeather(fail: true),
        );

        await tapFetch(tester);

        expect(tester.takeException(), isNull);
        expect(
          find.text('Weather data unavailable for this date'),
          findsOneWidget,
        );
        expect(controller.isDirty, isFalse);
        expect(fetchEnabled(tester), isTrue);
      });

      testWidgets('shows busy while it runs and not after', (tester) async {
        final gate = Completer<void>();
        await pumpEditor(
          tester,
          bare.copyWith(site: reef),
          weather: _FakeWeather(data: _forecast, gate: gate),
        );

        await tapFetch(tester);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(fetchEnabled(tester), isFalse);

        gate.complete();
        await tester.pump();
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(fetchEnabled(tester), isTrue);
      });

      testWidgets('that returns after the editor has gone sets nothing', (
        tester,
      ) async {
        final gate = Completer<void>();
        final dive = bare.copyWith(site: reef);
        final controller = await pumpEditor(
          tester,
          dive,
          weather: _FakeWeather(data: _forecast, gate: gate),
        );
        await tapFetch(tester);

        await pumpEditor(
          tester,
          dive,
          showEditor: false,
          controller: controller,
        );
        gate.complete();
        await tester.pump();
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('gone')), findsOneWidget);
        expect(controller.isDirty, isFalse);
      });

      // A forecast is for one place and one time. The dive can change
      // underneath while it is fetched; one asked for another site or date
      // is not written onto it.
      for (final (name, moved) in [
        (
          'site',
          (Dive d) => d.copyWith(
            site: const DiveSite(
              id: 'site-2',
              name: 'Quarry',
              location: GeoPoint(51.2, -2.5),
            ),
          ),
        ),
        ('date', (Dive d) => d.copyWith(dateTime: DateTime(2024, 7, 1, 10))),
      ]) {
        testWidgets('a forecast for a $name the dive no longer has is '
            'dropped', (tester) async {
          final gate = Completer<void>();
          final dive = bare.copyWith(site: reef);
          final controller = await pumpEditor(
            tester,
            dive,
            weather: _FakeWeather(data: _forecast, gate: gate),
          );
          await tapFetch(tester);

          controller.storedChanged(moved(dive));
          gate.complete();
          await tester.pumpAndSettle();

          expect(controller.session!.working.humidity, isNull);
          expect(controller.session!.working.weatherSource, isNull);
          expect(controller.isDirty, isFalse);
        });
      }

      testWidgets('an altitude found after the editor has gone is dropped', (
        tester,
      ) async {
        final gate = Completer<void>();
        final dive = bare.copyWith(site: reef);
        final controller = await pumpEditor(
          tester,
          dive,
          weather: _FakeWeather(data: _forecast),
          elevation: _FakeElevation(result: 12, gate: gate),
        );
        // The forecast is in; the altitude lookup it started is waiting.
        await tapFetch(tester);
        expect(controller.session!.working.humidity, 70);

        await pumpEditor(
          tester,
          dive,
          showEditor: false,
          controller: controller,
        );
        gate.complete();
        await tester.pump();
        await tester.pump();

        expect(controller.session!.valueOf(diveAltitudeField), isNull);
        expect(controller.session!.hasHeldWrites, isFalse);
      });

      testWidgets('a forecast that arrives while the sitting is being saved '
          'is dropped, and nothing is claimed', (tester) async {
        final gate = Completer<void>();
        final controller = await pumpEditor(
          tester,
          bare.copyWith(site: reef),
          weather: _FakeWeather(data: _forecast, gate: gate),
        );
        await tapFetch(tester);

        controller.session!.freeze();
        gate.complete();
        await tester.pump();
        await tester.pump();

        expect(find.text('Weather data loaded'), findsNothing);
        controller.session!.thaw();
        expect(controller.isDirty, isFalse);
        expect(fetchEnabled(tester), isTrue);
      });

      testWidgets('looks the altitude up afterwards when the dive has none', (
        tester,
      ) async {
        final elevation = _FakeElevation(result: 12);
        final controller = await pumpEditor(
          tester,
          bare.copyWith(site: reef),
          weather: _FakeWeather(data: _forecast),
          elevation: elevation,
        );
        expect(elevation.calls, 0);

        await tapFetch(tester);

        expect(elevation.calls, 1);
        expect(controller.session!.valueOf(diveAltitudeField), 12);
      });
    });
  });
}
