import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/trips/domain/entities/trip_story_day.dart';
import 'package:submersion/features/weather/presentation/providers/weather_providers.dart';

/// One historical-weather lookup for a contentless trip day.
///
/// Value equality makes this a stable Riverpod family key, so scrolling a day
/// header out of the sliver tree and back in reuses the same in-memory result.
class SurfaceDayWeatherRequest extends Equatable {
  final DateTime date;
  final double latitude;
  final double longitude;

  const SurfaceDayWeatherRequest({
    required this.date,
    required this.latitude,
    required this.longitude,
  });

  DateTime get localNoon => DateTime(date.year, date.month, date.day, 12);

  @override
  List<Object?> get props => [date, latitude, longitude];
}

/// Best-effort historical weather for a trip surface day.
///
/// Intentionally not auto-disposed: a trip story can repeatedly mount and
/// unmount day slivers while scrolling, and each request should be fetched at
/// most once during the provider container's lifetime.
final surfaceDayWeatherProvider =
    FutureProvider.family<TripStoryDayWeather?, SurfaceDayWeatherRequest>((
      ref,
      request,
    ) async {
      final weather = await ref
          .watch(weatherServiceProvider)
          .fetchWeather(
            latitude: request.latitude,
            longitude: request.longitude,
            date: DateTime(
              request.date.year,
              request.date.month,
              request.date.day,
            ),
            entryTime: request.localNoon,
            useLocationTimezone: true,
          );
      if (weather == null) return null;

      return TripStoryDayWeather(
        airTemp: weather.airTemp,
        cloudCover: weather.cloudCover,
        precipitation: weather.precipitation,
      );
    });
