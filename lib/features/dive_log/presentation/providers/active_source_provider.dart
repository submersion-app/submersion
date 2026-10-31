import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// The data source whose data drives the dive detail page (chart, stat
/// chips, deco and tissue cards). Null means "the primary source" so the
/// page needs no async initialization. View state only: switching the
/// active source never writes isPrimary; that changes solely via the
/// explicit "Set as primary" action. autoDispose: leaving the dive resets
/// the selection, so reopening a dive always starts at the primary source.
final activeDiveSourceProvider = StateProvider.autoDispose
    .family<String?, String>((ref, diveId) => null);

/// Source IDs currently overlaid on the profile chart for comparison.
/// The active source is never a member; activating a source removes it.
final overlaySourcesProvider = StateProvider.autoDispose
    .family<Set<String>, String>((ref, diveId) => const {});

/// The series the profile chart draws for [diveId] on a multi-source dive:
/// the active source's own profile, or the primary's when nothing is
/// selected (or the selection went stale after a split).
///
/// Null in exactly three cases, all of which send callers to `dive.profile`:
/// - a single-source dive, where `dive.profile` IS that source's series;
/// - sources that never overlap in time, which are the consecutive halves of
///   one dive a Combine stitched together rather than rival recordings of it,
///   so the whole merged series is the dive and drawing one source would hide
///   the rest (#1451);
/// - before the data sources have loaded at all, where the arrangement cannot
///   yet be known and `dive.profile` may still be the merged union for a
///   frame.
///
/// A RELOAD is not one of those cases: see the reads below.
///
/// Once the dive is known to have two or more sources this never returns
/// null: while the per-source profiles are still loading (or the resolved
/// source has no entry) it returns an EMPTY profile for that source, so the
/// chart shows its empty-state placeholder for a frame instead of flashing
/// the merged union.
///
/// This is the one rule behind every chart surface (detail page, fullscreen,
/// dive-list panel). `dive.profile` is the merged union of EVERY source's
/// samples interleaved by timestamp; on a consolidated dive that union
/// alternates between two computers' readings sample by sample, so any
/// surface that draws it renders a full-band sawtooth (#543).
final activeSourceProfileProvider = Provider.autoDispose
    .family<SourceProfile?, String>((ref, diveId) {
      // AsyncValue.value, not the valueOrNull polyfill. The polyfill is built
      // on `when`, whose defaults are skipLoadingOnRefresh: true but
      // skipLoadingOnReload: FALSE, so it drops to null whenever a dependency
      // changes. Both reads here reload on the dive detail change tick (the
      // first-view safety review write, a media write, any dive edit), and a
      // null there made a consolidated dive look single-source for that
      // frame: this provider returned null, callers drew `dive.profile`, and
      // the merged union flashed its sawtooth back onto the chart (#543).
      // .value retains the previous value across a reload and still yields
      // null (rather than throwing) on an error with nothing cached, so the
      // fall-back behaviour on failure is unchanged.
      final dataSources =
          ref.watch(diveDataSourcesProvider(diveId)).value ??
          const <DiveDataSource>[];
      final sourceProfiles =
          ref.watch(sourceProfilesProvider(diveId)).value ??
          const <String, SourceProfile>{};
      // usesPerSourceRendering, not a source count: it is the rule every
      // profile surface shares, and it excludes the sequential halves of a
      // Combine (#1451). Profiles that have not loaded yet carry no spans, so
      // this reads true on the first build and the branch below draws the
      // resolved source's empty placeholder rather than flashing the union.
      if (!usesPerSourceRendering(dataSources, sourceProfiles.values)) {
        return null;
      }
      final activeSourceId = ref.watch(activeDiveSourceProvider(diveId));
      final primary =
          dataSources.where((s) => s.isPrimary).firstOrNull ??
          dataSources.first;
      final active = activeSourceId == null
          ? primary
          : dataSources.where((s) => s.id == activeSourceId).firstOrNull ??
                primary;
      return sourceProfiles[active.id] ??
          SourceProfile(
            sourceId: active.id,
            computerId: active.computerId,
            isEdited: false,
            points: const [],
          );
    });

/// The dive's data sources, empty until they load.
///
/// Selects the list, so the loading flag of a refresh rebuilds nothing. This
/// provider refreshes on every analysis-input tick, and the widgets reading it
/// only want a new list when there is one.
List<DiveDataSource> watchDiveDataSources(WidgetRef ref, String diveId) =>
    ref.watch(diveDataSourcesProvider(diveId).select((a) => a.valueOrNull)) ??
    const [];

/// The series the chart draws for [dive], resolved by the same one rule the
/// chart itself uses (#543): the active source's own points on a multi-source
/// dive, dive.profile otherwise. Whatever indexes the chart (the point count,
/// the range panel, the readouts that follow the cursor) must read this, so
/// it reads the same series the curve was drawn from.
List<DiveProfilePoint> watchChartProfile(WidgetRef ref, Dive dive) =>
    ref.watch(activeSourceProfileProvider(dive.id))?.points ?? dive.profile;
