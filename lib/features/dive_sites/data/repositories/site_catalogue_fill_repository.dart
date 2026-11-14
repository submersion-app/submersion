import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/dive_sites/data/mappers/dive_site_row_mapper.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_offer.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/dive_sites/domain/entry_method_list.dart';

/// What became of one request to fill a site from a catalogue record.
enum CatalogueFillOutcome {
  /// The write went through. It may still have written nothing, when the
  /// site had filled every chosen field in the meantime.
  applied,

  /// Another of the diver's sites has claimed the record since the pair
  /// was offered.
  claimedElsewhere,

  /// The site has been linked to a different record since.
  siteChanged,

  /// A shared library site this profile may not edit.
  notEditable,

  /// The site no longer exists.
  missing,
}

/// The result of [SiteCatalogueFillRepository.applyFill].
class CatalogueFillWrite {
  const CatalogueFillWrite(
    this.outcome, {
    this.linked = false,
    this.filled = const {},
  });

  final CatalogueFillOutcome outcome;

  /// Whether this write set the site's link.
  final bool linked;

  /// The fields this write filled: the chosen ones the site still had
  /// empty.
  final Set<CatalogueGapField> filled;
}

/// Writes what a diver accepted from a built-in catalogue record onto one
/// of their existing sites, and what they answered about it.
///
/// Kept apart from [SiteRepository]: the ordinary site save deliberately
/// never writes the catalogue link or the answers, and this is the one
/// place an existing site gains them by the diver's own choice.
class SiteCatalogueFillRepository {
  SiteCatalogueFillRepository({
    LibraryEditStamper? stamper,
    SiteClassificationRepository? classification,
    SiteRepository? sites,
  }) : _stamper = stamper ?? LibraryEditStamper(),
       _classification = classification ?? SiteClassificationRepository(),
       _sites = sites ?? SiteRepository();

  final LibraryEditStamper _stamper;
  final SiteClassificationRepository _classification;
  final SiteRepository _sites;
  final SyncRepository _syncRepository = SyncRepository();
  final _log = LoggerService.forClass(SiteCatalogueFillRepository);

  AppDatabase get _db => DatabaseService.instance.database;

  /// Links [siteId] to [record] if it has no link, and writes those of
  /// [fields] the site still has empty.
  ///
  /// The offer is worked out again from the stored row inside the
  /// transaction, so a value the diver typed after the pair was shown is
  /// never overwritten. [declined] joins the fields the site has turned
  /// down for this record. [bodyOfWater] replaces the record's own sea
  /// name, which the catalogue holds in English.
  ///
  /// The site is stamped and marked for sync once, and only when something
  /// changed.
  Future<CatalogueFillWrite> applyFill({
    required String siteId,
    required CatalogueSite record,
    required Set<CatalogueGapField> fields,
    Set<CatalogueGapField> declined = const {},
    String? bodyOfWater,
    String? actingDiverId,
  }) async {
    try {
      if (!await _stamper.mayEdit(siteId, actingDiverId: actingDiverId)) {
        return const CatalogueFillWrite(CatalogueFillOutcome.notEditable);
      }
      final now = DateTime.now().millisecondsSinceEpoch;
      domain.DiveSite? before;
      var typesAdded = false;
      var wrote = false;

      final write = await _db.transaction(() async {
        final row = await (_db.select(
          _db.diveSites,
        )..where((t) => t.id.equals(siteId))).getSingleOrNull();
        if (row == null) {
          return const CatalogueFillWrite(CatalogueFillOutcome.missing);
        }
        final site = mapDiveSiteRow(row);
        before = site;
        if (site.catalogueId != null && site.catalogueId != record.id) {
          return const CatalogueFillWrite(CatalogueFillOutcome.siteChanged);
        }
        final claimant = await _sites.getSiteByCatalogueId(
          record.id,
          diverId: site.diverId ?? actingDiverId,
        );
        if (claimant != null && claimant.id != siteId) {
          return const CatalogueFillWrite(
            CatalogueFillOutcome.claimedElsewhere,
          );
        }

        final hasTypes =
            (await _classification.getTypeIdsBySite([
              siteId,
            ]))[siteId]?.isNotEmpty ??
            false;
        final filled = catalogueOfferFor(
          site,
          siteHasTypes: hasTypes,
          record: record,
        ).intersection(fields);
        final linking = site.catalogueId == null;
        final answers = site.catalogueAnswers.withDeclined(record.id, [
          for (final field in declined) field.name,
        ]);
        final answersChanged =
            answers.encode() != site.catalogueAnswers.encode();
        if (filled.isEmpty && !linking && !answersChanged) {
          return const CatalogueFillWrite(CatalogueFillOutcome.applied);
        }

        await (_db.update(
          _db.diveSites,
        )..where((t) => t.id.equals(siteId))).write(
          _companion(record, filled, bodyOfWater: bodyOfWater).copyWith(
            catalogueId: linking ? Value(record.id) : const Value.absent(),
            catalogueAnswers: answersChanged
                ? Value(answers.encode())
                : const Value.absent(),
            updatedAt: Value(now),
          ),
        );
        wrote = true;
        if (filled.contains(CatalogueGapField.siteTypes)) {
          await _classification.addTypesToSites({siteId: record.typeIds});
          typesAdded = true;
        }
        await _syncRepository.markRecordPending(
          entityType: 'diveSites',
          recordId: siteId,
          localUpdatedAt: now,
        );
        return CatalogueFillWrite(
          CatalogueFillOutcome.applied,
          linked: linking,
          filled: filled,
        );
      });

      if (!wrote) return write;
      final was = before;
      if (was != null && was.isLibrarySite) {
        final after = await _sites.getSiteById(siteId);
        if (after != null) {
          await _stamper.stamp(siteId, {
            ...LibraryEditStamper.changedFields(was, after),
            if (typesAdded) 'siteTypes',
          }, actingDiverId: actingDiverId);
        }
      }
      SyncEventBus.notifyLocalChange();
      _log.info(
        'Filled site $siteId from catalogue record ${record.id}: '
        '${write.filled.map((f) => f.name).join(', ')}',
      );
      return write;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to fill site $siteId from catalogue record ${record.id}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Rewrites what the diver has settled about catalogue records for
  /// [siteId] with [change], and marks the site for sync. A change that
  /// leaves the answers as they were writes nothing.
  Future<void> updateAnswers(
    String siteId,
    SiteCatalogueAnswers Function(SiteCatalogueAnswers current) change, {
    String? actingDiverId,
  }) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final changed = await _db.transaction(() async {
        final row = await (_db.select(
          _db.diveSites,
        )..where((t) => t.id.equals(siteId))).getSingleOrNull();
        if (row == null) return false;
        final current = SiteCatalogueAnswers.decode(row.catalogueAnswers);
        final next = change(current).encode();
        if (next == current.encode()) return false;
        await (_db.update(
          _db.diveSites,
        )..where((t) => t.id.equals(siteId))).write(
          DiveSitesCompanion(
            catalogueAnswers: Value(next),
            updatedAt: Value(now),
          ),
        );
        await _syncRepository.markRecordPending(
          entityType: 'diveSites',
          recordId: siteId,
          localUpdatedAt: now,
        );
        return true;
      });
      if (changed) SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to update catalogue answers of site $siteId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// The columns [filled] writes, from [record].
  DiveSitesCompanion _companion(
    CatalogueSite record,
    Set<CatalogueGapField> filled, {
    String? bodyOfWater,
  }) {
    Value<T> when<T>(CatalogueGapField field, T value) =>
        filled.contains(field) ? Value(value) : const Value.absent();

    return DiveSitesCompanion(
      latitude: when(CatalogueGapField.position, record.location?.latitude),
      longitude: when(CatalogueGapField.position, record.location?.longitude),
      // Whichever depth the record has. The other stays empty: the offer
      // is made only to a site that has neither.
      minDepth: when(CatalogueGapField.depth, record.minDepth),
      maxDepth: when(CatalogueGapField.depth, record.maxDepth),
      country: when(CatalogueGapField.country, record.country?.trim()),
      // A country always arrives with its code.
      countryCode: when(
        CatalogueGapField.country,
        record.countryCode ?? countryCodeFor(record.country),
      ),
      region: when(CatalogueGapField.region, record.region?.trim()),
      city: when(CatalogueGapField.city, record.locality?.trim()),
      island: when(CatalogueGapField.island, record.island?.trim()),
      bodyOfWater: when(
        CatalogueGapField.bodyOfWater,
        bodyOfWater ?? record.bodyOfWater?.trim(),
      ),
      waterType: when(CatalogueGapField.waterType, record.waterType?.name),
      entryMethod: when(
        CatalogueGapField.entry,
        encodeEntryMethods(record.entryMethods),
      ),
      difficulty: when(CatalogueGapField.difficulty, record.difficulty?.name),
      hazards: when(CatalogueGapField.hazards, record.hazards?.trim()),
      description: filled.contains(CatalogueGapField.description)
          ? Value(record.description!.trim())
          : const Value.absent(),
    );
  }
}
