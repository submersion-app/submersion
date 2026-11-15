import 'package:flutter/foundation.dart' show visibleForTesting;

import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/geocoding/sea_area_index.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_catalogue_fill_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/data/services/catalogue_sea_name.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_name_key.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pairing.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/repositories/site_catalogue.dart';
import 'package:submersion/features/dive_sites/domain/services/catalogue_site_visibility.dart';

/// One pair the diver chose to apply, with the fields they kept ticked.
class CatalogueApplyRequest {
  const CatalogueApplyRequest(this.pair, this.fields);

  final CataloguePair pair;

  /// The offered fields to fill. The pair's other fields were turned down
  /// and are remembered as such.
  final Set<CatalogueGapField> fields;
}

/// What applying a list of pairs came to.
class CatalogueApplyResult {
  const CatalogueApplyResult({
    this.linked = 0,
    this.filled = 0,
    this.notApplied = 0,
  });

  /// Sites that gained their link.
  final int linked;

  /// Sites that had at least one field filled.
  final int filled;

  /// Pairs that could not be applied: the site or the record had changed
  /// hands since the pair was offered, or the write failed.
  final int notApplied;
}

/// Runs [body] as one bulk action of the diver's.
typedef BulkRunner = Future<T> Function<T>(Future<T> Function() body);

/// Finds the built-in catalogue records that are the same place as sites
/// the diver already has, and applies what the diver accepts from them.
///
/// Nothing here writes on its own account: [findPairs] only reads, and
/// every write is a request the diver made on the review list or a site's
/// page.
class CatalogueGapService {
  CatalogueGapService({
    required SiteRepository siteRepository,
    required SiteCatalogue catalogue,
    required SiteClassificationRepository classification,
    required SiteCatalogueFillRepository fills,
    LibraryEditStamper? stamper,
    this.fetchElevation,
    this.loadSeas,
    this.placeNameLanguage,
    BulkRunner? runBulk,
  }) : _sites = siteRepository,
       _catalogue = catalogue,
       _classification = classification,
       _fills = fills,
       _stamper = stamper ?? LibraryEditStamper(),
       _runBulk = runBulk ?? _changeLogBulk;

  final SiteRepository _sites;
  final SiteCatalogue _catalogue;
  final SiteClassificationRepository _classification;
  final SiteCatalogueFillRepository _fills;
  final LibraryEditStamper _stamper;
  final BulkRunner _runBulk;
  static final _log = LoggerService.forClass(CatalogueGapService);

  /// Altitude for a point, or null when unknown. Asked only for a site
  /// that was given a position, after its write has committed.
  final Future<double?> Function(GeoPoint point)? fetchElevation;

  /// The sea table and the diver's place-name language, so a sea taken
  /// from the catalogue is named as the diver's other sites name theirs.
  final Future<SeaAreaIndex?> Function()? loadSeas;
  final String Function()? placeNameLanguage;

  /// The altitude lookups started so far, one batch after another. They
  /// never fail; a test waits on this to see what they wrote.
  @visibleForTesting
  Future<void> altitudeFills = Future.value();

  static Future<T> _changeLogBulk<T>(Future<T> Function() body) =>
      ChangeLogScope.bulk(
        DatabaseService.instance.databaseOrNull,
        label: ChangeLogLabels.bulkEdit,
        body: body,
      );

  /// The pairs [diverId] can be offered now. Reads only.
  ///
  /// The sites taking part are the diver's own and the shared library
  /// sites they may edit. Another profile's shared site never takes part,
  /// though a record it is linked to counts as claimed. One catalogue read
  /// per site that is linked (its record) or has a position (the records
  /// around it), and one read in all for the sites that have neither (the
  /// records of their names): a logbook brought in from another app can
  /// hold hundreds of those.
  ///
  /// [isCancelled] lets the caller give up on a search a newer one has
  /// replaced: it is asked before each site's read, and a cancelled search
  /// answers with no pairs, which the caller throws away.
  Future<List<CataloguePair>> findPairs({
    required String? diverId,
    bool Function()? isCancelled,
  }) async {
    final all = await _sites.getAllSites(diverId: diverId);
    // Who may edit depends on the library and the diver, not on the site:
    // asked once per library, however many sites it holds.
    final editable = <String, bool>{};
    final taking = <DiveSite>[];
    for (final site in all) {
      final libraryId = site.sharedLibraryId;
      final takesPart = libraryId == null
          ? site.diverId == diverId
          : editable[libraryId] ??= await _stamper.mayEdit(
              site.id,
              actingDiverId: diverId,
            );
      if (takesPart) taking.add(site);
    }
    if (taking.isEmpty) return const [];

    final linked = <String, CatalogueSite>{};
    final near = <String, List<CatalogueSite>>{};
    final bare = <DiveSite>[];
    for (final site in taking) {
      if (isCancelled?.call() ?? false) return const [];
      final link = site.catalogueId;
      final location = site.location;
      if (link != null) {
        final record = await _catalogue.byId(link);
        if (record != null) linked[site.id] = record;
      } else if (location != null) {
        near[site.id] = await _catalogue.near(
          location,
          radiusMeters: kCataloguePairRadiusMeters,
          limit: 50,
        );
      } else if (catalogueNameKey(site.name).isNotEmpty) {
        bare.add(site);
      }
    }
    final named = <String, List<CatalogueSite>>{};
    if (bare.isNotEmpty) {
      if (isCancelled?.call() ?? false) return const [];
      final byNameKey = await _catalogue.namedMany({
        for (final site in bare) site.name,
      });
      for (final site in bare) {
        final records = byNameKey[catalogueNameKey(site.name)];
        if (records != null) named[site.id] = records;
      }
    }
    if (linked.isEmpty &&
        near.values.every((r) => r.isEmpty) &&
        named.values.every((r) => r.isEmpty)) {
      return const [];
    }

    final typeIds = await _classification.getTypeIdsBySite([
      for (final site in taking) site.id,
    ]);
    return pairSitesWithCatalogue(
      sites: taking,
      sitesWithTypes: {
        for (final entry in typeIds.entries)
          if (entry.value.isNotEmpty) entry.key,
      },
      claimed: linkedCatalogueIds(all),
      candidates: PairingCandidates(
        linkedRecords: linked,
        near: near,
        named: named,
      ),
    );
  }

  /// Applies [requests], several of them as one bulk action in the change
  /// log. A pair that cannot be applied is counted and the rest still go
  /// through.
  ///
  /// Each pair's record is read again first, and one the catalogue no
  /// longer holds as the pair shows it is counted as not applied.
  ///
  /// The result does not wait for the altitude of a site that was given a
  /// position: that lookup needs the network, and follows by itself.
  Future<CatalogueApplyResult> apply(
    List<CatalogueApplyRequest> requests, {
    required String? diverId,
  }) async {
    if (requests.isEmpty) return const CatalogueApplyResult();
    var linked = 0;
    var filled = 0;
    var notApplied = 0;
    final located = <String, GeoPoint>{};

    Future<void> applyAll() async {
      for (final request in requests) {
        final pair = request.pair;
        final fields = request.fields.intersection(pair.fields);
        try {
          // The pair pictures the catalogue as it stood when the diver was
          // shown it, and an import can replace the catalogue while a
          // comparison is open. A record that has gone or changed since is
          // not written: the diver has not seen what it holds now, and the
          // next search offers that.
          if (await _catalogue.byId(pair.record.id) != pair.record) {
            notApplied++;
            continue;
          }
          final write = await _fills.applyFill(
            siteId: pair.site.id,
            record: pair.record,
            fields: fields,
            declined: pair.fields.difference(fields),
            bodyOfWater: fields.contains(CatalogueGapField.bodyOfWater)
                ? await catalogueSeaInDiversLanguage(
                    pair.record,
                    loadSeas: loadSeas,
                    placeNameLanguage: placeNameLanguage,
                  )
                : null,
            actingDiverId: diverId,
          );
          if (write.outcome != CatalogueFillOutcome.applied) {
            notApplied++;
            continue;
          }
          if (write.linked) linked++;
          if (write.filled.isNotEmpty) filled++;
          final position = pair.record.location;
          if (write.filled.contains(CatalogueGapField.position) &&
              position != null &&
              pair.site.altitude == null) {
            located[pair.site.id] = position;
          }
        } catch (error, stackTrace) {
          notApplied++;
          _log.error(
            'Could not apply catalogue record ${pair.record.id} to site '
            '${pair.site.id}',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }
    }

    // One pair, from a site's page or one comparison, is an ordinary edit.
    if (requests.length == 1) {
      await applyAll();
    } else {
      await _runBulk(applyAll);
    }

    altitudeFills = altitudeFills.then((_) => _fillAltitudes(located));
    return CatalogueApplyResult(
      linked: linked,
      filled: filled,
      notApplied: notApplied,
    );
  }

  /// Remembers that [pair]'s record is a different place from its site.
  Future<void> answerNotSame(CataloguePair pair, {required String? diverId}) =>
      _fills.updateAnswers(
        pair.site.id,
        (answers) => answers.withNotSame(pair.record.id),
        actingDiverId: diverId,
      );

  /// Turns down every field [pair] offers. They are not offered again
  /// from that record.
  Future<void> declineAll(CataloguePair pair, {required String? diverId}) =>
      _fills.updateAnswers(
        pair.site.id,
        (answers) => answers.withDeclined(pair.record.id, [
          for (final field in pair.fields) field.name,
        ]),
        actingDiverId: diverId,
      );

  /// Best-effort altitude for each site that was given a position. After
  /// the writes have committed, so a network stall holds no lock; never
  /// throws.
  ///
  /// The lookup can be out for seconds. The site is read again when it
  /// answers, and an altitude the diver entered meanwhile is left alone,
  /// as a fill leaves any other value of theirs.
  Future<void> _fillAltitudes(Map<String, GeoPoint> located) async {
    final fetch = fetchElevation;
    if (fetch == null) return;
    for (final entry in located.entries) {
      try {
        final meters = await fetch(entry.value);
        if (meters == null) continue;
        final site = await _sites.getSiteById(entry.key);
        if (site == null || site.altitude != null) continue;
        await _sites.updateSiteAltitude(entry.key, meters);
      } catch (error, stackTrace) {
        _log.warning(
          'Altitude lookup failed for site ${entry.key}',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
