import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_mirror_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/dive_sensor_summary_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_observation_providers.dart';
import 'package:submersion/features/gps_log/presentation/providers/gps_track_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/species_media_providers.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';

/// Starts loading what Dive Details' sections read, while the page slides in
/// and before those sections are built (issue #3489).
///
/// The sections wait for the slide, so on their own their data would only
/// start loading once it ended, putting a second wait after the first. A
/// listener loads a provider and keeps it alive without rebuilding the page
/// when it resolves, so the slide stays as light as it is without them. Call
/// it from build for as long as the sections are held back: once they watch
/// these providers themselves, the listeners are no longer needed.
///
/// The sections' reads live in this page and in their own widgets, so both
/// belong here. What the page's top level already watches, the dive and its
/// data sources, and the safety review that drives the profile analysis,
/// loads during the slide anyway.
void preloadDiveDetailSections(WidgetRef ref, String diveId) {
  void keep(ProviderListenable<Object?> provider) =>
      ref.listen(provider, (_, _) {});

  keep(sourceProfilesProvider(diveId));
  keep(
    sourceProfileAnalysisProvider((
      diveId: diveId,
      sourceId: ref.watch(activeDiveSourceProvider(diveId)),
    )),
  );
  keep(weeklyOtuProvider(diveId));
  keep(surfaceIntervalProvider(diveId));
  keep(diveSegmentCountProvider(diveId));
  keep(hasGasSwitchesProvider(diveId));
  keep(computersForDiveProvider(diveId));
  keep(buddiesForDiveProvider(diveId));
  keep(diveSightingsProvider(diveId));
  keep(diveSpeciesPhotoCountsProvider(diveId));
  keep(navTracksForDiveProvider(diveId));
  keep(signatureForDiveProvider(diveId));

  // Read by the section widgets themselves.
  keep(gasSwitchesProvider(diveId));
  keep(mediaForDiveProvider(diveId));
  keep(diveSensorSummaryProvider(diveId));
  keep(tankPressuresProvider(diveId));
  keep(cylinderSacProvider(diveId));
  keep(incidentsForDiveProvider(diveId));
  keep(coursesForDiveProvider(diveId));
  keep(observationsForDiveProvider(diveId));
  keep(siblingDivesProvider(diveId));
  keep(buddySignaturesForDiveProvider(diveId));
  keep(trackForDiveProvider(diveId));
}
