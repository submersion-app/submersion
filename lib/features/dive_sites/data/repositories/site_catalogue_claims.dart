import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/sql_templates.dart'
    show escapeLike;
import 'package:submersion/features/dive_sites/data/mappers/dive_site_row_mapper.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart'
    as domain;

/// Which of a diver's sites claims a built-in catalogue record.
///
/// A site claims the record it was adopted from, and every record it
/// stands for since a merge folded a site adopted from that record into
/// it. Adoption asks this before it creates a site, so one record never
/// becomes two of the diver's sites.
class SiteCatalogueClaims {
  const SiteCatalogueClaims(this._db);

  final AppDatabase _db;

  /// The site of [diverId] that claims [catalogueId], or null. With no
  /// [diverId], a site that has no diver.
  ///
  /// In order: the diver's own site adopted from the record; a site of a
  /// shared library the diver belongs to that is linked to it; one of
  /// either that stands for it since a merge. The oldest wins within each
  /// step, so every caller agrees on one.
  ///
  /// A library site the diver has hidden claims nothing for them: it is
  /// in none of their lists, and a dive must not be assigned to it.
  Future<domain.DiveSite?> claimant(
    String catalogueId, {
    String? diverId,
  }) async {
    Expression<bool> own($DiveSitesTable t) =>
        diverId == null ? t.diverId.isNull() : t.diverId.equals(diverId);
    Expression<bool> inALibraryOfTheirs($DiveSitesTable t) {
      final memberships = _db.sharedLibraryMemberships;
      final hides = _db.siteHides;
      return t.sharedLibraryId.isInQuery(
            _db.selectOnly(memberships)
              ..addColumns([memberships.libraryId])
              ..where(memberships.diverId.equals(diverId!)),
          ) &
          t.id.isNotInQuery(
            _db.selectOnly(hides)
              ..addColumns([hides.siteId])
              ..where(hides.diverId.equals(diverId)),
          );
    }

    Future<List<DiveSite>> oldestFirst(
      Expression<bool> Function($DiveSitesTable t) filter, {
      int? limit,
    }) {
      final query = _db.select(_db.diveSites)
        ..where(filter)
        ..orderBy([
          (t) => OrderingTerm.asc(t.createdAt),
          (t) => OrderingTerm.asc(t.id),
        ]);
      if (limit != null) query.limit(limit);
      return query.get();
    }

    final scopes = <Expression<bool> Function($DiveSitesTable t)>[
      own,
      if (diverId != null) inALibraryOfTheirs,
    ];
    for (final scope in scopes) {
      final linked = await oldestFirst(
        (t) => t.catalogueId.equals(catalogueId) & scope(t),
        limit: 1,
      );
      if (linked.isNotEmpty) return mapDiveSiteRow(linked.first);
    }
    // The id as it sits in the stored JSON narrows the rows read; the
    // decoded answers decide. A LIKE alone would take `osm_node_1` for
    // part of `osm_node_12`, and its `_` for any character.
    final needle = '%"${escapeLike(catalogueId)}"%';
    for (final scope in scopes) {
      final rows = await oldestFirst(
        (t) => t.catalogueAnswers.like(needle, escapeChar: r'\') & scope(t),
      );
      for (final row in rows) {
        final site = mapDiveSiteRow(row);
        if (site.catalogueAnswers.also.contains(catalogueId)) return site;
      }
    }
    return null;
  }
}
