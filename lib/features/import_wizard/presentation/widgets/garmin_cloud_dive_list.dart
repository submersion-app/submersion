import 'package:submersion/core/services/garmin_connect/garmin_dive_mapper.dart';
import 'package:submersion/features/import_wizard/presentation/widgets/cloud_import_dive_summary.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Builds the same title/subtitle text shown for a Garmin dive both in the
/// fetch step's inline selection list and in the shared Review step, so the
/// two stay in sync without duplicating the formatting.
({String title, String subtitle}) formatGarminDiveSummary(
  GarminParsedDive parsed,
  AppSettings settings,
) => formatCloudDiveSummary(parsed.dive, settings);
