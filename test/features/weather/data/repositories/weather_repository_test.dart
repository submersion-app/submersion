import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/weather/data/repositories/weather_repository.dart';
import 'package:submersion/features/weather/data/services/weather_service.dart';
import 'package:submersion/features/weather/domain/entities/weather_data.dart';

@GenerateMocks([WeatherService, DiveRepository])
import 'weather_repository_test.mocks.dart';

void main() {
  late MockWeatherService mockWeatherService;
  late MockDiveRepository mockDiveRepository;
  late WeatherRepository weatherRepository;

  setUp(() {
    mockWeatherService = MockWeatherService();
    mockDiveRepository = MockDiveRepository();
    weatherRepository = WeatherRepository(
      weatherService: mockWeatherService,
      diveRepository: mockDiveRepository,
    );
  });

  group('fetchAndSaveWeather', () {
    final testDive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2024, 6, 15, 10, 0),
      airTemp: null,
      surfacePressure: null,
    );

    final testWeatherData = WeatherData(
      windSpeed: 3.5,
      windDirection: CurrentDirection.northEast,
      cloudCover: CloudCover.partlyCloudy,
      precipitation: Precipitation.none,
      humidity: 75.0,
      airTemp: 28.0,
      surfacePressure: 1.013,
      description: 'Partly Cloudy, 28C',
    );

    test('fetches weather and updates dive', () async {
      when(
        mockDiveRepository.getDiveById('dive-1'),
      ).thenAnswer((_) async => testDive);
      when(
        mockWeatherService.fetchWeather(
          latitude: 28.5,
          longitude: -80.6,
          date: DateTime(2024, 6, 15),
          entryTime: DateTime(2024, 6, 15, 10, 0),
        ),
      ).thenAnswer((_) async => testWeatherData);
      when(mockDiveRepository.updateDive(any)).thenAnswer((_) async {});

      await weatherRepository.fetchAndSaveWeather(
        diveId: 'dive-1',
        latitude: 28.5,
        longitude: -80.6,
        dateTime: DateTime(2024, 6, 15, 10, 0),
      );

      final captured =
          verify(mockDiveRepository.updateDive(captureAny)).captured.single
              as Dive;
      expect(captured.windSpeed, 3.5);
      expect(captured.cloudCover, CloudCover.partlyCloudy);
      expect(captured.weatherSource, WeatherSource.openMeteo);
      expect(captured.weatherFetchedAt, isNotNull);
      // airTemp should be populated (was null)
      expect(captured.airTemp, 28.0);
      // surfacePressure should be populated (was null)
      expect(captured.surfacePressure, 1.013);
    });

    test('does not overwrite existing airTemp', () async {
      final diveWithAirTemp = Dive(
        id: 'dive-2',
        dateTime: DateTime(2024, 6, 15, 10, 0),
        airTemp: 30.0, // Already set
        surfacePressure: null,
      );

      when(
        mockDiveRepository.getDiveById('dive-2'),
      ).thenAnswer((_) async => diveWithAirTemp);
      when(
        mockWeatherService.fetchWeather(
          latitude: anyNamed('latitude'),
          longitude: anyNamed('longitude'),
          date: anyNamed('date'),
          entryTime: anyNamed('entryTime'),
        ),
      ).thenAnswer((_) async => testWeatherData);
      when(mockDiveRepository.updateDive(any)).thenAnswer((_) async {});

      await weatherRepository.fetchAndSaveWeather(
        diveId: 'dive-2',
        latitude: 28.5,
        longitude: -80.6,
        dateTime: DateTime(2024, 6, 15, 10, 0),
      );

      final captured =
          verify(mockDiveRepository.updateDive(captureAny)).captured.single
              as Dive;
      // Should keep existing airTemp (30.0), not overwrite with API value (28.0)
      expect(captured.airTemp, 30.0);
    });

    test('does not update dive when service returns null', () async {
      when(
        mockDiveRepository.getDiveById('dive-3'),
      ).thenAnswer((_) async => testDive);
      when(
        mockWeatherService.fetchWeather(
          latitude: anyNamed('latitude'),
          longitude: anyNamed('longitude'),
          date: anyNamed('date'),
          entryTime: anyNamed('entryTime'),
        ),
      ).thenAnswer((_) async => null);

      await weatherRepository.fetchAndSaveWeather(
        diveId: 'dive-3',
        latitude: 28.5,
        longitude: -80.6,
        dateTime: DateTime(2024, 6, 15, 10, 0),
      );

      verifyNever(mockDiveRepository.updateDive(any));
    });
  });
}
