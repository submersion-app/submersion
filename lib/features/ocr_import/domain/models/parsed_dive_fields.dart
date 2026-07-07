import 'package:equatable/equatable.dart';

/// Parser output. All values metric: meters, bar, celsius, liters, kg.
/// Null means "not confidently extracted" — never guessed.
class ParsedDiveFields extends Equatable {
  final int? diveNumber;
  final DateTime? date; // date component; time merged in when found
  final bool hasTimeOfDay; // true when [date] includes a real Time In
  final int? durationMinutes;
  final double? maxDepthMeters;
  final double? waterTempCelsius;
  final double? airTempCelsius;
  final double? startPressureBar;
  final double? endPressureBar;
  final double? o2Percent;
  final double? cylinderVolumeLiters;
  final double? weightKg;
  final String? siteName;
  final String? locationText; // country/region line when distinct from site
  final String? notes;
  final int? rating; // 1-5, only when written as text/number

  /// Extracted but unmappable values (visibility, buddy, divemaster,
  /// unresolved site name...). Rendered as a notes appendix by the flow.
  final Map<String, String> unmapped;

  const ParsedDiveFields({
    this.diveNumber,
    this.date,
    this.hasTimeOfDay = false,
    this.durationMinutes,
    this.maxDepthMeters,
    this.waterTempCelsius,
    this.airTempCelsius,
    this.startPressureBar,
    this.endPressureBar,
    this.o2Percent,
    this.cylinderVolumeLiters,
    this.weightKg,
    this.siteName,
    this.locationText,
    this.notes,
    this.rating,
    this.unmapped = const {},
  });

  bool get isEmpty =>
      diveNumber == null &&
      date == null &&
      durationMinutes == null &&
      maxDepthMeters == null &&
      waterTempCelsius == null &&
      airTempCelsius == null &&
      startPressureBar == null &&
      endPressureBar == null &&
      o2Percent == null &&
      cylinderVolumeLiters == null &&
      weightKg == null &&
      siteName == null &&
      locationText == null &&
      notes == null &&
      rating == null &&
      unmapped.isEmpty;

  @override
  List<Object?> get props => [
    diveNumber,
    date,
    hasTimeOfDay,
    durationMinutes,
    maxDepthMeters,
    waterTempCelsius,
    airTempCelsius,
    startPressureBar,
    endPressureBar,
    o2Percent,
    cylinderVolumeLiters,
    weightKg,
    siteName,
    locationText,
    notes,
    rating,
    unmapped,
  ];
}
