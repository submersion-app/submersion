import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_sites/data/catalogue/site_catalogue_row_mapper.dart';

/// The bundled catalogue.
const kSiteCatalogueAsset = 'assets/data/site_catalogue.json';

/// A hash of [kSiteCatalogueAsset], written beside it by the scripts. The
/// importer reads this small file on every launch so it never has to parse
/// the large one to learn nothing changed.
const kSiteCatalogueVersionAsset = 'assets/data/site_catalogue.version';

/// The meta row holding the version of the catalogue last imported: the
/// importer's revision, then the file's hash.
const kSiteCatalogueMetaVersion = 'version';

/// Goes up whenever this build reads the same file into different rows: a
/// change to how a record is parsed, or to how its search text is folded.
/// Stored with the file's hash, so such a build imports again even though
/// the file itself did not change.
const kSiteCatalogueImportRevision = 1;

/// The meta row holding the catalogue's sources, as JSON.
const kSiteCatalogueMetaSources = 'sources';

const _log = LoggerService('SiteCatalogueImporter');

/// Rows written per batch. Large enough to keep an import of tens of
/// thousands of sites to a few dozen statements' worth of round trips,
/// small enough that no single batch holds the worker for long.
const _batchSize = 500;

enum SiteCatalogueImportOutcome {
  /// The tables already hold this version.
  upToDate,

  /// The tables were replaced with the bundled catalogue.
  imported,

  /// Nothing changed: the previous catalogue, if any, is still in place.
  failed,
}

/// Loads the bundled catalogue into the local cache database whenever its
/// version sidecar differs from the version last imported.
class SiteCatalogueImporter {
  SiteCatalogueImporter({
    LocalCacheDatabase? database,
    AssetBundle? bundle,
    this.importRevision = kSiteCatalogueImportRevision,
  }) : _database = database,
       _bundle = bundle ?? rootBundle;

  final LocalCacheDatabase? _database;
  final AssetBundle _bundle;

  /// [kSiteCatalogueImportRevision], except in a test that stands in for a
  /// later build.
  final int importRevision;

  Future<SiteCatalogueImportOutcome>? _running;

  LocalCacheDatabase get _db =>
      _database ?? LocalCacheDatabaseService.instance.database;

  /// Imports the bundled catalogue if it is not the one already stored.
  ///
  /// Never throws. The replace is one transaction, so a reader sees the old
  /// catalogue or the new one, and a failure leaves the old one in place to
  /// be retried on the next launch. Calls that overlap share one run.
  Future<SiteCatalogueImportOutcome> importIfChanged() =>
      _running ??= _run().whenComplete(() => _running = null);

  Future<SiteCatalogueImportOutcome> _run() async {
    try {
      final db = _db;
      final hash = (await _bundle.loadString(
        kSiteCatalogueVersionAsset,
        cache: false,
      )).trim();
      if (hash.isEmpty) {
        _log.warning('The site catalogue has an empty version sidecar');
        return SiteCatalogueImportOutcome.failed;
      }
      final version = '$importRevision:$hash';

      final stored =
          await (db.select(db.siteCatalogueMeta)
                ..where((meta) => meta.key.equals(kSiteCatalogueMetaVersion)))
              .getSingleOrNull();
      if (stored?.value == version) {
        return SiteCatalogueImportOutcome.upToDate;
      }

      // Not cached by the bundle: this is megabytes read once per update.
      final json = await _bundle.loadString(kSiteCatalogueAsset, cache: false);
      // Parsing, folding each site's search text and encoding its lists
      // all happen off the UI isolate: at tens of thousands of sites that
      // is too much work for a frame.
      final built = await compute(buildSiteCatalogueRows, json);
      final rows = built.rows;
      if (rows.isEmpty) {
        // A file that parses but holds no usable site. Emptying the
        // catalogue until the next app update would be worse than keeping
        // the one already here.
        _log.warning('The site catalogue file holds no usable site');
        return SiteCatalogueImportOutcome.failed;
      }

      await db.transaction(() async {
        await db.delete(db.siteCatalogueEntries).go();
        for (var start = 0; start < rows.length; start += _batchSize) {
          final end = start + _batchSize < rows.length
              ? start + _batchSize
              : rows.length;
          await db.batch((batch) {
            batch.insertAll(
              db.siteCatalogueEntries,
              rows.sublist(start, end),
              // A repeated id keeps its last record instead of failing the
              // whole import on a primary key.
              mode: InsertMode.insertOrReplace,
            );
          });
        }
        await db.batch((batch) {
          batch.insertAll(db.siteCatalogueMeta, [
            SiteCatalogueMetaCompanion.insert(
              key: kSiteCatalogueMetaVersion,
              value: version,
            ),
            SiteCatalogueMetaCompanion.insert(
              key: kSiteCatalogueMetaSources,
              value: built.sources,
            ),
          ], mode: InsertMode.insertOrReplace);
        });
      });

      _log.info('Imported ${rows.length} catalogue sites (version $version)');
      return SiteCatalogueImportOutcome.imported;
    } catch (error, stackTrace) {
      _log.warning(
        'The site catalogue was not imported; the previous one stays',
        error: error,
        stackTrace: stackTrace,
      );
      return SiteCatalogueImportOutcome.failed;
    }
  }
}
