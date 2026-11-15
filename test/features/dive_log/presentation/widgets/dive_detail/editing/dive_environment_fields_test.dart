import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/dive_detail_sections.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_fields.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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

/// The values the Environment card edits, and the two rules that act on
/// them without a widget: the exit method following the entry method, and
/// a fetched forecast written into a sitting (issue #4527).
void main() {
  final bare = Dive(id: 'dive', dateTime: DateTime(2024, 6, 1, 10));
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
    weatherCode: 2,
    currentDirection: CurrentDirection.north,
    currentStrength: CurrentStrength.light,
    swellHeight: 1.5,
    surfaceConditions: 'Calm',
    entryMethod: EntryMethod.shore,
    exitMethod: EntryMethod.boat,
  );

  EditSession<Dive> sessionOver(Dive dive) {
    final session = EditSession<Dive>(dive);
    addTearDown(session.dispose);
    return session;
  }

  group('the card and its fields', () {
    // Each entry clears one value through its field and reads it back.
    final clears = <String, (Dive Function(Dive), Object? Function(Dive))>{
      'airTemp': ((d) => diveAirTempField.write(d, null), (d) => d.airTemp),
      'windSpeed': (
        (d) => diveWindSpeedField.write(d, null),
        (d) => d.windSpeed,
      ),
      'windDirection': (
        (d) => diveWindDirectionField.write(d, null),
        (d) => d.windDirection,
      ),
      'cloudCover': (
        (d) => diveCloudCoverField.write(d, null),
        (d) => d.cloudCover,
      ),
      'precipitation': (
        (d) => divePrecipitationField.write(d, null),
        (d) => d.precipitation,
      ),
      'humidity': ((d) => diveHumidityField.write(d, null), (d) => d.humidity),
      'weatherDescription': (
        (d) => diveWeatherDescriptionField.write(d, null),
        (d) => d.weatherDescription,
      ),
      'weatherSource': (
        (d) => diveWeatherSourceField.write(d, null),
        (d) => d.weatherSource,
      ),
      'weatherFetchedAt': (
        (d) => diveWeatherFetchedAtField.write(d, null),
        (d) => d.weatherFetchedAt,
      ),
      'currentDirection': (
        (d) => diveCurrentDirectionField.write(d, null),
        (d) => d.currentDirection,
      ),
      'currentStrength': (
        (d) => diveCurrentStrengthField.write(d, null),
        (d) => d.currentStrength,
      ),
      'swellHeight': (
        (d) => diveSwellHeightField.write(d, null),
        (d) => d.swellHeight,
      ),
      'surfaceConditions': (
        (d) => diveSurfaceConditionsField.write(d, null),
        (d) => d.surfaceConditions,
      ),
      'entryMethod': (
        (d) => diveEntryMethodField.write(d, null),
        (d) => d.entryMethod,
      ),
      'exitMethod': (
        (d) => diveExitMethodField.write(d, null),
        (d) => d.exitMethod,
      ),
      'weatherCode': (
        (d) => diveWeatherCodeField.write(d, null),
        (d) => d.weatherCode,
      ),
    };

    test('there are sixteen fields, all on the Environment card', () {
      expect(clears, hasLength(16));
      expect(
        {
          diveAirTempField.cardId,
          diveWindSpeedField.cardId,
          diveWindDirectionField.cardId,
          diveCloudCoverField.cardId,
          divePrecipitationField.cardId,
          diveHumidityField.cardId,
          diveWeatherDescriptionField.cardId,
          diveWeatherSourceField.cardId,
          diveWeatherFetchedAtField.cardId,
          diveCurrentDirectionField.cardId,
          diveCurrentStrengthField.cardId,
          diveSwellHeightField.cardId,
          diveSurfaceConditionsField.cardId,
          diveEntryMethodField.cardId,
          diveExitMethodField.cardId,
          diveWeatherCodeField.cardId,
        },
        {_cardId},
      );
    });

    test('field ids are unique', () {
      final ids = [
        diveAirTempField.id,
        diveWindSpeedField.id,
        diveWindDirectionField.id,
        diveCloudCoverField.id,
        divePrecipitationField.id,
        diveHumidityField.id,
        diveWeatherDescriptionField.id,
        diveWeatherSourceField.id,
        diveWeatherFetchedAtField.id,
        diveCurrentDirectionField.id,
        diveCurrentStrengthField.id,
        diveSwellHeightField.id,
        diveSurfaceConditionsField.id,
        diveEntryMethodField.id,
        diveExitMethodField.id,
        diveWeatherCodeField.id,
        diveAltitudeField.id,
        diveSurfacePressureField.id,
        diveNotesField.id,
        diveTagsField.id,
      ];
      expect(ids.toSet(), hasLength(ids.length));
    });

    for (final entry in clears.entries) {
      test('${entry.key} clears with null and leaves the rest alone', () {
        final (clear, read) = entry.value;
        expect(read(full), isNotNull);

        final cleared = clear(full);

        expect(read(cleared), isNull);
        for (final other in clears.entries.where((e) => e.key != entry.key)) {
          expect(
            other.value.$2(cleared),
            other.value.$2(full),
            reason: other.key,
          );
        }
      });
    }

    test('a field writes its value', () {
      expect(diveAirTempField.write(bare, 19).airTemp, 19);
      expect(
        diveEntryMethodField.write(bare, EntryMethod.ladder).entryMethod,
        EntryMethod.ladder,
      );
      expect(
        diveSurfaceConditionsField.write(bare, 'Choppy').surfaceConditions,
        'Choppy',
      );
    });

    test('surface conditions are trimmed, and blank is null', () {
      expect(
        diveSurfaceConditionsField.write(bare, '  Choppy ').surfaceConditions,
        'Choppy',
      );
      expect(
        diveSurfaceConditionsField.write(full, '   ').surfaceConditions,
        isNull,
      );
    });

    // An import can leave space around a description. The editor reads its
    // text trimmed, so the stored words have to count as the same words.
    test('a description is the same whatever space is around it', () {
      final session = sessionOver(bare.copyWith(weatherDescription: 'Sunny '));

      session.set(diveWeatherDescriptionField, 'Sunny');

      expect(session.isDirty, isFalse);
    });

    test('a description is trimmed, and blank is null', () {
      expect(
        diveWeatherDescriptionField.write(bare, '  Sunny ').weatherDescription,
        'Sunny',
      );
      expect(
        diveWeatherDescriptionField.write(full, '   ').weatherDescription,
        isNull,
      );
    });

    test('the card is left out when nothing is logged', () {
      final card = diveEditCards[DiveDetailSectionId.environment]!;

      expect(card.id, _cardId);
      expect(card.isEmpty(bare), isTrue);
      expect(card.isEmpty(bare.copyWith(airTemp: 20)), isFalse);
      expect(
        card.isEmpty(bare.copyWith(exitMethod: EntryMethod.boat)),
        isFalse,
      );
      // A surface pressure shows on this card too.
      expect(card.isEmpty(bare.copyWith(surfacePressure: 1.0)), isFalse);
    });
  });

  // The exit method mirrors the entry method until the diver edits the exit
  // directly. Whether it still mirrors is for the editor to remember.
  group('setEntryMethod', () {
    final shoreBoth = bare.copyWith(
      entryMethod: EntryMethod.shore,
      exitMethod: EntryMethod.shore,
    );

    test('an exit that follows takes the entry it is given', () {
      final session = sessionOver(shoreBoth);

      setEntryMethod(session, EntryMethod.boat, exitFollows: true);

      expect(session.valueOf(diveEntryMethodField), EntryMethod.boat);
      expect(session.valueOf(diveExitMethodField), EntryMethod.boat);
    });

    test('an unset exit that follows is filled', () {
      final session = sessionOver(bare);

      setEntryMethod(session, EntryMethod.shore, exitFollows: true);

      expect(session.valueOf(diveEntryMethodField), EntryMethod.shore);
      expect(session.valueOf(diveExitMethodField), EntryMethod.shore);
    });

    test('clearing the entry clears an exit that follows', () {
      final session = sessionOver(shoreBoth);

      setEntryMethod(session, null, exitFollows: true);

      expect(session.working.entryMethod, isNull);
      expect(session.working.exitMethod, isNull);
    });

    test('an exit that no longer follows is left alone, even when it '
        'matches', () {
      final session = sessionOver(shoreBoth);

      setEntryMethod(session, EntryMethod.boat, exitFollows: false);

      expect(session.valueOf(diveEntryMethodField), EntryMethod.boat);
      expect(session.valueOf(diveExitMethodField), EntryMethod.shore);
    });

    test('an exit the diver cleared stays cleared', () {
      final session = sessionOver(
        bare.copyWith(entryMethod: EntryMethod.shore),
      );

      setEntryMethod(session, EntryMethod.boat, exitFollows: false);

      expect(session.valueOf(diveExitMethodField), isNull);
    });

    test('setting the entry back leaves the sitting clean', () {
      final session = sessionOver(bare);

      setEntryMethod(session, EntryMethod.shore, exitFollows: true);
      setEntryMethod(session, null, exitFollows: true);

      expect(session.isDirty, isFalse);
    });

    // What the dive form decides when it loads a dive.
    test('a stored exit follows the entry when it is unset or equal to it', () {
      expect(exitFollowsEntry(bare), isTrue);
      expect(
        exitFollowsEntry(bare.copyWith(entryMethod: EntryMethod.shore)),
        isTrue,
      );
      expect(exitFollowsEntry(shoreBoth), isTrue);
      expect(
        exitFollowsEntry(shoreBoth.copyWith(exitMethod: EntryMethod.boat)),
        isFalse,
      );
    });
  });

  // The read card writes a fetched dive's description from its forecast and
  // ignores the stored words. Words the diver types have to be shown, so
  // typing them makes the weather the diver's own.
  group('weatherDescriptionEdited', () {
    final fetched = full.copyWith(weatherSource: WeatherSource.openMeteo);

    test('a description typed on fetched weather makes it manual', () {
      final session = sessionOver(fetched)
        ..set(diveWeatherDescriptionField, 'Squalls');

      weatherDescriptionEdited(session);

      expect(session.working.weatherSource, WeatherSource.manual);
    });

    // With no words stored the card writes the description from the
    // forecast whatever the source, so clearing needs no change of source,
    // and the weather keeps saying where it came from.
    test('clearing it leaves fetched weather fetched', () {
      final session = sessionOver(fetched)
        ..set(diveWeatherDescriptionField, null);

      weatherDescriptionEdited(session);

      expect(session.working.weatherSource, WeatherSource.openMeteo);
    });

    test('clearing words typed in this sitting makes it fetched again', () {
      final session = sessionOver(fetched)
        ..set(diveWeatherDescriptionField, 'Squalls');
      weatherDescriptionEdited(session);

      session.set(diveWeatherDescriptionField, null);
      weatherDescriptionEdited(session);

      expect(session.working.weatherSource, WeatherSource.openMeteo);
    });

    test('typing the stored words back leaves the sitting clean', () {
      final session = sessionOver(fetched)
        ..set(diveWeatherDescriptionField, 'Squalls');
      weatherDescriptionEdited(session);

      session.set(diveWeatherDescriptionField, 'Fine');
      weatherDescriptionEdited(session);

      expect(session.isDirty, isFalse);
    });

    test('weather that was never fetched keeps its source', () {
      final session = sessionOver(bare.copyWith(weatherDescription: 'Fine'))
        ..set(diveWeatherDescriptionField, 'Squalls');

      weatherDescriptionEdited(session);

      expect(session.working.weatherSource, isNull);
    });

    test('a fetch after the edit is fetched weather again', () {
      final session = sessionOver(fetched)
        ..set(diveWeatherDescriptionField, 'Squalls');
      weatherDescriptionEdited(session);

      applyFetchedWeather(session, _forecast, now: DateTime(2024, 6, 3));

      expect(session.working.weatherSource, WeatherSource.openMeteo);
    });
  });

  // The read card names the sky from the forecast's code before cloud cover
  // and precipitation, and leaves precipitation out when there is a code.
  // A sky the diver changes would then be described as the forecast had it.
  group('weatherSkyEdited', () {
    final fetched = full.copyWith(
      weatherSource: WeatherSource.openMeteo,
      weatherCode: 80,
      precipitation: Precipitation.rain,
    );

    test('a changed precipitation drops the code', () {
      final session = sessionOver(fetched)
        ..set(divePrecipitationField, Precipitation.none);

      weatherSkyEdited(session);

      expect(session.working.weatherCode, isNull);
    });

    test('a changed cloud cover drops the code', () {
      final session = sessionOver(fetched)
        ..set(diveCloudCoverField, CloudCover.overcast);

      weatherSkyEdited(session);

      expect(session.working.weatherCode, isNull);
    });

    test('the other fetched values and the source stay', () {
      final session = sessionOver(fetched)
        ..set(divePrecipitationField, Precipitation.none);

      weatherSkyEdited(session);

      expect(session.working.weatherSource, WeatherSource.openMeteo);
      expect(session.working.cloudCover, fetched.cloudCover);
    });

    test('setting the sky back restores the code and leaves the sitting '
        'clean', () {
      final session = sessionOver(fetched)
        ..set(divePrecipitationField, Precipitation.none);
      weatherSkyEdited(session);

      session.set(divePrecipitationField, Precipitation.rain);
      weatherSkyEdited(session);

      expect(session.working.weatherCode, 80);
      expect(session.isDirty, isFalse);
    });

    test('the code of a fetch made in this sitting is not put back', () {
      final session = sessionOver(fetched);
      applyFetchedWeather(session, _forecast, now: DateTime(2024, 6, 3));
      session.set(diveWeatherCodeField, 3);
      session.set(divePrecipitationField, Precipitation.none);
      weatherSkyEdited(session);

      session.set(divePrecipitationField, Precipitation.rain);
      session.set(diveCloudCoverField, fetched.cloudCover);
      weatherSkyEdited(session);

      expect(session.working.weatherCode, isNull);
    });
  });

  group('applyFetchedWeather', () {
    final now = DateTime(2024, 6, 3, 9);

    test('overwrites the weather values that came back', () {
      final session = sessionOver(full);

      applyFetchedWeather(session, _forecast, now: now);

      final dive = session.working;
      expect(dive.windSpeed, 5);
      expect(dive.windDirection, CurrentDirection.northWest);
      expect(dive.cloudCover, CloudCover.overcast);
      expect(dive.precipitation, Precipitation.drizzle);
      expect(dive.humidity, 70);
    });

    test('leaves a value alone when the forecast has none for it', () {
      final session = sessionOver(full);

      applyFetchedWeather(session, const WeatherData(humidity: 70), now: now);

      final dive = session.working;
      expect(dive.humidity, 70);
      expect(dive.windSpeed, 4);
      expect(dive.windDirection, CurrentDirection.east);
      expect(dive.cloudCover, CloudCover.clear);
      expect(dive.precipitation, Precipitation.none);
      expect(dive.weatherDescription, 'Fine');
    });

    test('a description replaces the stored one only when it has words', () {
      final withWords = sessionOver(full);
      applyFetchedWeather(
        withWords,
        const WeatherData(description: 'Rain later'),
        now: now,
      );
      expect(withWords.working.weatherDescription, 'Rain later');

      final empty = sessionOver(full);
      applyFetchedWeather(empty, const WeatherData(description: ''), now: now);
      expect(empty.working.weatherDescription, 'Fine');
    });

    test('fills air temperature and surface pressure only when empty', () {
      final empty = sessionOver(bare);
      applyFetchedWeather(empty, _forecast, now: now);
      expect(empty.working.airTemp, 24);
      expect(empty.working.surfacePressure, 1.009);

      final set = sessionOver(bare.copyWith(airTemp: 21, surfacePressure: 0.9));
      applyFetchedWeather(set, _forecast, now: now);
      expect(set.working.airTemp, 21);
      expect(set.working.surfacePressure, 0.9);
    });

    test('a value the diver typed this sitting counts as set', () {
      final session = sessionOver(bare)..set(diveAirTempField, 19.0);

      applyFetchedWeather(session, _forecast, now: now);

      expect(session.working.airTemp, 19);
    });

    test('stamps the source and the time', () {
      final session = sessionOver(full);

      applyFetchedWeather(session, const WeatherData(), now: now);

      expect(session.working.weatherSource, WeatherSource.openMeteo);
      expect(session.working.weatherFetchedAt, now);
    });

    test('marks the Altitude card changed when it filled the pressure', () {
      final session = sessionOver(bare);

      applyFetchedWeather(session, _forecast, now: now);

      expect(session.changedCardIds, {_cardId, 'altitude'});
    });

    // The read card writes its description from the code, so an old one
    // would go on describing weather the fetch has just replaced.
    test('stores the weather code the forecast came with', () {
      final session = sessionOver(full.copyWith(weatherCode: 61));

      applyFetchedWeather(session, const WeatherData(weatherCode: 3), now: now);

      expect(session.working.weatherCode, 3);
    });

    test('a forecast with no code clears an old one', () {
      final session = sessionOver(full.copyWith(weatherCode: 61));

      applyFetchedWeather(session, const WeatherData(humidity: 70), now: now);

      expect(session.working.weatherCode, isNull);
      expect(session.working.humidity, 70);
    });

    test('touches nothing but the weather', () {
      final session = sessionOver(full);

      applyFetchedWeather(session, _forecast, now: now);

      final dive = session.working;
      expect(dive.currentDirection, CurrentDirection.north);
      expect(dive.currentStrength, CurrentStrength.light);
      expect(dive.swellHeight, 1.5);
      expect(dive.surfaceConditions, 'Calm');
      expect(dive.entryMethod, EntryMethod.shore);
      expect(dive.exitMethod, EntryMethod.boat);
      expect(dive.altitude, isNull);
    });
  });
}
