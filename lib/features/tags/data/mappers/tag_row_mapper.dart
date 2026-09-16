import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// Maps a `tags` row to its domain entity. Shared by every reader, so a new
/// column (like the v217 scope flags) is mapped in exactly one place.
domain.Tag mapTagRow(Tag row) {
  return domain.Tag(
    id: row.id,
    diverId: row.diverId,
    name: row.name,
    colorHex: row.color,
    createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
    scopes: tagScopesOf(row),
  );
}

/// The scopes a `tags` row's flag columns switch on (issue #1942). One arm
/// per scope, so a new scope does not compile until its column is read here.
Set<domain.TagScope> tagScopesOf(Tag row) => {
  for (final scope in domain.TagScope.values)
    if (switch (scope) {
      domain.TagScope.dives => row.appliesToDives,
      domain.TagScope.sites => row.appliesToSites,
    })
      scope,
};

/// The `tags` flag column values for [scopes], keyed by column name. Every
/// registry scope gets a value, true when [scopes] holds it, so a write can
/// never leave a flag at a stale value. Wrap in `RawValuesInsertable<Tag>`,
/// alone or spread beside a companion's `toColumns(false)`.
Map<String, Expression> tagScopeColumns(Set<domain.TagScope> scopes) => {
  for (final scope in domain.TagScope.values)
    scope.table.scopeColumn: Variable<bool>(scopes.contains(scope)),
};
