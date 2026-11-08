import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// Whether [diveId]'s analysis, or the decoded inputs it reads, is loaded.
///
/// A pass over many dives checks this before it starts, so it releases only
/// what it loaded itself and leaves an open page's data alone.
bool isDiveAnalysisLoaded(ProviderContainer container, String diveId) =>
    container.exists(profileAnalysisProvider(diveId)) ||
    container.exists(diveAnalysisSeriesProvider(diveId)) ||
    container.exists(analysisDiveProvider(diveId)) ||
    container.exists(sourceProfilesProvider(diveId));

/// Drops [diveId]'s analysis and the decoded inputs it read.
///
/// Each of these holds an unused entry for `diveDataRetention`, so a pass
/// over many dives that shows none of them (the deco classification, the
/// safety review sweep) would otherwise keep every dive it analysed in that
/// window (#4254). Invalidating an entry nothing listens to disposes it at
/// once; one that something does listen to rebuilds for it instead. A dive
/// with several sources also read its per-source buckets.
void releaseDiveAnalysis(Ref ref, String diveId) {
  ref.invalidate(profileAnalysisProvider(diveId));
  ref.invalidate(diveAnalysisSeriesProvider(diveId));
  ref.invalidate(analysisDiveProvider(diveId));
  ref.invalidate(sourceProfilesProvider(diveId));
  ref.invalidate(diveDataSourcesProvider(diveId));
}
