import 'package:submersion/core/services/garmin_connect/garmin_dive_mapper.dart';
import 'package:submersion/core/utils/unit_formatter_settings.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/downloaded_dive_summary.dart';

/// Builds the same title/subtitle text shown for a Garmin dive both in the
/// fetch step's inline selection list and in the shared Review step, so the
/// two stay in sync without duplicating the formatting.
({String title, String subtitle}) formatGarminDiveSummary(
  GarminParsedDive parsed,
  UnitFormatterSettings settings,
) => formatDownloadedDiveSummary(parsed.dive, settings);
