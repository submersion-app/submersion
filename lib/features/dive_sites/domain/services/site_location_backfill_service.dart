import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/geocoding/place_lookup.dart';
import 'package:submersion/core/services/location_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_lookup_memory.dart';

/// Outcome of one backfill run.
class BackfillSummary {
  const BackfillSummary({
    required this.total,
    required this.updated,
    required this.unchanged,
    required this.failed,
    this.cancelled = false,
    this.offline = false,
  });

  final int total;
  final int updated;
  final int unchanged;
  final int failed;
  final bool cancelled;

  /// The geocoder could not be reached on the first request, so the run
  /// stopped before collecting one failure per site.
  final bool offline;
}

/// The sites a run would look up, and how many more it leaves out because
/// an earlier lookup already found nothing for their empty fields.
class BackfillCandidates {
  const BackfillCandidates({required this.sites, this.alreadyLookedUp = 0});

  final List<DiveSite> sites;

  /// Sites with empty fields that a [SiteLocationLookupMode.fillMissing]
  /// run skips: OpenStreetMap had nothing for them at these coordinates
  /// (issue #4992). Always 0 for a refresh, which asks about every site.
  final int alreadyLookedUp;
}

/// What a run writes to the sites it looks up (issue #1187).
enum SiteLocationLookupMode {
  /// Only blank country, region, town and body of water are filled, so a
  /// hand-typed or deliberately cleared value survives.
  fillMissing,

  /// Every site with coordinates is looked up again and a differing value is
  /// replaced, which brings a database geocoded in more than one place name
  /// language back to a single language.
  refreshAll,
}

/// Looks up country, region, town and body of water for every site that has
/// coordinates (issue #1187). What is written depends on [mode]; the rule
/// itself lives in `mergeLocationDetails` behind
/// [SiteRepository.applyLocationDetails]. Request spacing is the location
/// service's concern.
class SiteLocationBackfillService {
  SiteLocationBackfillService({
    required SiteRepository sites,
    required LocationService location,
    required String languageCode,
    required this.mode,
    SiteLookupMemory? memory,
  }) : _sites = sites,
       _location = location,
       _languageCode = languageCode,
       _memory = memory;

  final SiteRepository _sites;
  final LocationService _location;
  final String _languageCode;

  /// What earlier lookups could not fill, so a fill-missing run does not ask
  /// OpenStreetMap the same question again (issue #4992). Without one,
  /// every site with an empty field is offered every time.
  final SiteLookupMemory? _memory;

  /// What this run writes to the sites it looks up.
  final SiteLocationLookupMode mode;
  static final _log = LoggerService.forClass(SiteLocationBackfillService);

  /// A site a [SiteLocationLookupMode.fillMissing] run would look up:
  /// coordinates present and at least one of the four fields blank.
  static bool needsLookup(DiveSite site) =>
      site.location != null && blankLocationFields(site).isNotEmpty;

  /// Whether [mode] would look this site up. A refresh asks about every
  /// site that has coordinates, however complete it already looks, because
  /// a filled field may hold a name in the wrong language.
  static bool wants(DiveSite site, SiteLocationLookupMode mode) =>
      mode == SiteLocationLookupMode.refreshAll
      ? site.location != null
      : needsLookup(site);

  /// The sites a run looks up. A shared library site this profile may not
  /// edit is left out: whatever the lookup found, nothing would be written
  /// to it (issue #2567). A fill-missing run also leaves out a site an
  /// earlier lookup could not complete, unless it has moved or had a field
  /// cleared since (issue #4992).
  Future<BackfillCandidates> candidates({String? diverId}) async {
    final all = await _sites.getAllSites(diverId: diverId);
    final notes = await _readNotes();
    final stamper = LibraryEditStamper();
    final sites = <DiveSite>[];
    var alreadyLookedUp = 0;
    for (final site in all) {
      if (!wants(site, mode)) continue;
      if (site.sharedLibraryId != null &&
          !await stamper.mayEdit(site.id, actingDiverId: diverId)) {
        continue;
      }
      if (mode == SiteLocationLookupMode.fillMissing &&
          (notes[site.id]?.covers(site) ?? false)) {
        alreadyLookedUp++;
        continue;
      }
      sites.add(site);
    }
    await _dropNotesForMissingSites(notes, all);
    return BackfillCandidates(sites: sites, alreadyLookedUp: alreadyLookedUp);
  }

  Future<Map<String, SiteLookupNote>> _readNotes() async {
    final memory = _memory;
    if (memory == null) return {};
    try {
      return await memory.read();
    } catch (e, stackTrace) {
      _log.warning(
        'Could not read site lookup notes; every incomplete site is offered',
        error: e,
        stackTrace: stackTrace,
      );
      return {};
    }
  }

  Future<void> _writeNotes(Map<String, SiteLookupNote> notes) async {
    final memory = _memory;
    if (memory == null) return;
    try {
      await memory.write(notes);
    } catch (e, stackTrace) {
      _log.warning(
        'Could not save site lookup notes; these sites will be offered again',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Forgets notes for sites that are gone, so the store does not grow with
  /// every deleted site.
  Future<void> _dropNotesForMissingSites(
    Map<String, SiteLookupNote> notes,
    List<DiveSite> all,
  ) async {
    if (notes.isEmpty) return;
    final ids = {for (final site in all) site.id};
    final kept = {
      for (final entry in notes.entries)
        if (ids.contains(entry.key)) entry.key: entry.value,
    };
    if (kept.length != notes.length) await _writeNotes(kept);
  }

  /// Runs the lookup over [targets], or over [candidates] when the caller
  /// has none to hand. A caller that already listed the candidates (to
  /// confirm on their count, say) passes them here so the database is not
  /// scanned and mapped a second time.
  Future<BackfillSummary> run({
    String? diverId,
    List<DiveSite>? targets,
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) => ChangeLogScope.bulk(
    DatabaseService.instance.databaseOrNull,
    label: ChangeLogLabels.bulkEdit,
    body: () => _runInner(
      diverId: diverId,
      targets: targets,
      onProgress: onProgress,
      isCancelled: isCancelled,
    ),
  );

  /// [notes] with what the lookup that just answered [found] for [siteId]
  /// left empty: OpenStreetMap has nothing for those fields at this place.
  /// The same map comes back, unchanged, when there is nothing new to note.
  ///
  /// A lookup that found nothing at all leaves the notes alone: the web
  /// geocoder answers an empty result for a failure it could not classify
  /// (a broken response, a TLS error), and noting that would hide the site
  /// from every later run. A failure here only costs the note, so it is
  /// logged rather than counted against the lookup.
  Future<Map<String, SiteLookupNote>> _noted(
    String siteId,
    PlaceLookup found,
    Map<String, SiteLookupNote> notes,
  ) async {
    if (found.isEmpty) return notes;
    try {
      final after = await _sites.getSiteById(siteId);
      final note = after == null ? null : SiteLookupNote.of(after, found);
      if (note == null) {
        if (!notes.containsKey(siteId)) return notes;
        return {
          for (final entry in notes.entries)
            if (entry.key != siteId) entry.key: entry.value,
        };
      }
      if (notes[siteId] == note) return notes;
      return {...notes, siteId: note};
    } catch (e, stackTrace) {
      _log.warning(
        'Could not note the lookup for site $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      return notes;
    }
  }

  Future<BackfillSummary> _runInner({
    String? diverId,
    List<DiveSite>? targets,
    required void Function(int done, int total) onProgress,
    required bool Function() isCancelled,
  }) async {
    final sites = targets ?? (await candidates(diverId: diverId)).sites;
    final total = sites.length;
    var updated = 0;
    var unchanged = 0;
    var failed = 0;
    var done = 0;
    final stored = await _readNotes();
    var notes = stored;
    onProgress(done, total);

    for (final site in sites) {
      if (isCancelled()) {
        if (!identical(notes, stored)) await _writeNotes(notes);
        return BackfillSummary(
          total: total,
          updated: updated,
          unchanged: unchanged,
          failed: failed,
          cancelled: true,
        );
      }
      final point = site.location!;
      try {
        final lookup = await _location.reverseGeocode(
          point.latitude,
          point.longitude,
          languageCode: _languageCode,
        );
        if (lookup.networkFailed) {
          if (done == 0) {
            return BackfillSummary(
              total: total,
              updated: updated,
              unchanged: unchanged,
              failed: failed,
              offline: true,
            );
          }
          failed++;
        } else {
          if (await _sites.applyLocationDetails(
            site.id,
            lookup,
            overwrite: mode == SiteLocationLookupMode.refreshAll,
          )) {
            updated++;
          } else {
            unchanged++;
          }
          notes = await _noted(site.id, lookup, notes);
        }
      } catch (e, stackTrace) {
        _log.warning(
          'Backfill failed for site ${site.id}: $e',
          error: e,
          stackTrace: stackTrace,
        );
        failed++;
      }
      done++;
      onProgress(done, total);
    }

    if (!identical(notes, stored)) await _writeNotes(notes);
    return BackfillSummary(
      total: total,
      updated: updated,
      unchanged: unchanged,
      failed: failed,
    );
  }
}
