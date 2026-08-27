import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Initial values for DiveEditPage create mode. All metric.
/// Built by the OCR scan flow; deliberately independent of ocr_import
/// so dive_log never imports that feature.
class DivePrefill {
  final int? diveNumber;
  final DateTime? dateTime;
  final bool hasTimeOfDay;
  final int? durationMinutes;
  final double? maxDepthMeters;
  final double? waterTempCelsius;
  final double? airTempCelsius;
  final int? rating;
  final String? notes;
  final DiveSite? site; // pre-resolved existing site, or null
  final double? startPressureBar;
  final double? endPressureBar;
  final double? o2Percent;
  final double? cylinderVolumeLiters;
  final double? weightKg;
  final String? photoPath; // source logbook photo to attach after save
  final String? importSource; // e.g. 'ocr'

  const DivePrefill({
    this.diveNumber,
    this.dateTime,
    this.hasTimeOfDay = false,
    this.durationMinutes,
    this.maxDepthMeters,
    this.waterTempCelsius,
    this.airTempCelsius,
    this.rating,
    this.notes,
    this.site,
    this.startPressureBar,
    this.endPressureBar,
    this.o2Percent,
    this.cylinderVolumeLiters,
    this.weightKg,
    this.photoPath,
    this.importSource,
  });
}
