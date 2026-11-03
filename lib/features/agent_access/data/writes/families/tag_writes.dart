import 'package:drift/drift.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/media/data/repositories/smart_album_tag_repoint.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// A diver's tags, through the repository the tag page uses. A name is the
/// diver's once, trimmed and case-folded, as the name index keys it, and a
/// tag applies to at least one scope. Turning a scope off takes the tag off
/// every item of that scope, as the page warns.
class TagWrites extends WritableEntry {
  TagWrites(this._r);

  final RecordRepositories _r;

  static final _colour = RegExp(r'^#[0-9A-Fa-f]{6}$');

  @override
  String get name => 'tags';

  @override
  String get table => 'tags';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 100, trim: true),
    'color_hex': const FieldCodec.text(maxLength: 7, nullable: true),
    'scopes': FieldCodec.enumSet(domain.TagScope.values, min: 1),
  };

  @override
  Set<String> get requiredOnCreate => const {'name'};

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    final colour = check.values['color_hex'];
    if (colour is String && !_colour.hasMatch(colour)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'color_hex: a colour is written as #RRGGBB.',
      );
    }
    final name = check.values['name'];
    if (name is! String) return null;
    final owner = check.ownerId ?? check.document?['diver_id'] as String?;
    final holder = await _holderOf(name, owner, except: check.id);
    if (holder == null) return null;
    return PlanBlock(
      BlockReason.duplicateRecord,
      'name: tag ${holder.id} is already called "${holder.name}". Link that '
      'tag instead, or delete this one with merge_into ${holder.id} to merge '
      'them.',
    );
  }

  @override
  UniqueClaim? uniqueKey(WriteCheck check) => switch (check.values['name']) {
    final String name => UniqueClaim(name.trim().toLowerCase()),
    _ => null,
  };

  /// The links a change of scopes takes off: every item of a scope it turns
  /// off.
  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final after = fields['scopes']!.wire(update.values['scopes']);
    if (after is! List) return const SideEffects();
    final dropped = [
      for (final scope in domain.TagScope.values)
        if ((document['scopes'] as List).contains(scope.name) &&
            !after.contains(scope.name))
          scope,
    ];
    return SideEffects(parts: await _links(id, dropped));
  }

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async => DeleteReach(unlinked: await _links(id, domain.TagScope.values));

  @override
  bool get mergeable => true;

  /// Every link of [id] moves to [intoId], except one whose item already
  /// carries [intoId], which goes, as `mergeTags` does. A tag merged into
  /// [intoId] earlier in the set has moved its links there by then. The
  /// survivor takes every scope the merged tags had, and saved smart albums
  /// filtered by [id] follow it.
  @override
  Future<DeleteReach> mergeReach(
    String id,
    String intoId, {
    Set<String> mergedBefore = const {},
  }) async {
    final moved = <String, int>{};
    final parts = <String, int>{};
    final db = DatabaseService.instance.database;
    final holders = [intoId, ...mergedBefore];
    final marks = [for (var i = 0; i < holders.length; i++) '?${i + 2}'];
    for (final scope in domain.TagScope.values) {
      final junction = scope.table.junctionTable;
      final item = scope.table.parentColumn;
      // DISTINCT, since an item may carry more than one of the holders.
      final row = await db
          .customSelect(
            'SELECT SUM(CASE WHEN held IS NULL THEN 1 ELSE 0 END) AS moved, '
            'SUM(CASE WHEN held IS NULL THEN 0 ELSE 1 END) AS gone '
            'FROM (SELECT a."$item", (SELECT 1 FROM "$junction" b '
            'WHERE b."$item" = a."$item" AND b.tag_id IN (${marks.join(', ')}) '
            'LIMIT 1) AS held FROM "$junction" a WHERE a.tag_id = ?1)',
            variables: [
              Variable.withString(id),
              for (final holder in holders) Variable.withString(holder),
            ],
          )
          .getSingle();
      if ((row.readNullable<int>('moved') ?? 0) > 0) {
        moved[junction] = row.read<int>('moved');
      }
      if ((row.readNullable<int>('gone') ?? 0) > 0) {
        parts[junction] = row.read<int>('gone');
      }
    }
    final albums = await countSmartAlbumsNaming(
      db,
      (filter) => filter.tagIds.contains(id),
    );
    if (albums > 0) moved['media_smart_albums'] = albums;
    return DeleteReach(
      moved: moved,
      parts: parts,
      survivor: await _widenedScopes(intoId, [id, ...mergedBefore]),
      basis: await _linkRows([id, ...holders]),
    );
  }

  /// Every link the tags in [tagIds] hold, in a stable order, so a link that
  /// moves between items after the preview refuses the plan even when the
  /// counts stay the same.
  Future<String> _linkRows(List<String> tagIds) async {
    final db = DatabaseService.instance.database;
    final marks = List.filled(tagIds.length, '?').join(', ');
    final rows = <String>[];
    for (final scope in domain.TagScope.values) {
      final junction = scope.table.junctionTable;
      final item = scope.table.parentColumn;
      final found = await db
          .customSelect(
            'SELECT tag_id, "$item" AS item FROM "$junction" '
            'WHERE tag_id IN ($marks) ORDER BY tag_id, "$item"',
            variables: [for (final id in tagIds) Variable.withString(id)],
          )
          .get();
      for (final row in found) {
        rows.add(
          '$junction:${row.read<String>('tag_id')}:${row.read<String>('item')}',
        );
      }
    }
    return rows.join('\n');
  }

  /// The survivor's scopes after a merge takes the union of the merged
  /// tags', as `mergeTags` writes it, when that differs from what it holds.
  Future<Map<String, Object?>> _widenedScopes(
    String intoId,
    List<String> merged,
  ) async {
    final survivor = await _r.tags.getTagById(intoId);
    if (survivor == null) return const {};
    final union = {...survivor.scopes};
    for (final id in merged) {
      union.addAll((await _r.tags.getTagById(id))?.scopes ?? const {});
    }
    if (union.length == survivor.scopes.length) return const {};
    return {
      'scopes': [
        for (final scope in domain.TagScope.values)
          if (union.contains(scope)) scope.name,
      ],
    };
  }

  /// The survivor's name and colour are read now, so a change to it earlier
  /// in the same set is what it keeps.
  @override
  Future<void> merge(String id, String intoId, String? ownerId) async {
    final survivor = await _r.tags.getTagById(intoId) ?? _gone(intoId);
    await _r.tags.mergeTags(
      sourceTagIds: [id],
      survivingTagId: intoId,
      name: survivor.name,
      colorHex: survivor.colorHex,
    );
  }

  @override
  String get note =>
      'Delete a tag with merge_into set to another of the diver\'s tags to '
      'merge it: its links move to that tag, as the tag page merges them. '
      'The merge\'s fields are the survivor\'s, such as the scopes it gains, '
      'and moved_to_merge_target counts the links and smart albums that '
      'follow it';

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final name = values['name']! as String;
    await _nameStillFree(name, diverId);
    final now = DateTime.now();
    final tag = await _r.tags.createTag(
      domain.Tag(
        id: '',
        diverId: diverId,
        name: name,
        colorHex: values['color_hex'] as String?,
        scopes: _scopes(values['scopes']) ?? const {domain.TagScope.dives},
        createdAt: now,
        updatedAt: now,
      ),
    );
    return tag.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _r.tags.getTagById(id) ?? _gone(id);
    final v = update.values;
    if (v['name'] case final String name) {
      await _nameStillFree(name, current.diverId, except: id);
    }
    await _r.tags.updateTag(
      domain.Tag(
        id: id,
        diverId: current.diverId,
        name: v['name'] as String? ?? current.name,
        colorHex: v.containsKey('color_hex')
            ? v['color_hex'] as String?
            : current.colorHex,
        scopes: _scopes(v['scopes']) ?? current.scopes,
        createdAt: current.createdAt,
        updatedAt: current.updatedAt,
      ),
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) => _r.tags.deleteTag(id);

  Set<domain.TagScope>? _scopes(Object? parsed) {
    final names = fields['scopes']!.wire(parsed);
    if (names is! List) return null;
    return {for (final name in names) domain.TagScope.values.byName('$name')};
  }

  /// Throws when another tag of [ownerId] has taken [name] since the preview.
  /// createTag would hand that tag back and updateTag would merge into it, a
  /// change the diver never allowed.
  Future<void> _nameStillFree(
    String name,
    String? ownerId, {
    String? except,
  }) async {
    final holder = await _holderOf(name, ownerId, except: except);
    if (holder == null) return;
    throw AgentToolException(
      AgentToolErrorCode.writeRefused,
      'Tag ${holder.id} took the name "${holder.name}" after the preview.',
      details: {'id': holder.id},
    );
  }

  /// The tag of [ownerId] holding [name] as the name index keys it, other
  /// than [except].
  Future<({String id, String name})?> _holderOf(
    String name,
    String? ownerId, {
    String? except,
  }) async {
    final db = DatabaseService.instance.database;
    final query = db.select(db.tags)
      ..where(
        (t) =>
            t.name.trim().unicodeLower().equals(name.trim().toLowerCase()) &
            coalesce([t.diverId, const Constant('')]).equals(ownerId ?? '') &
            (except == null ? const Constant(true) : t.id.equals(except).not()),
      )
      ..limit(1);
    final row = await query.getSingleOrNull();
    return row == null ? null : (id: row.id, name: row.name);
  }

  /// How many items of each of [scopes] carry tag [id], by junction table.
  Future<Map<String, int>> _links(
    String id,
    Iterable<domain.TagScope> scopes,
  ) async {
    final counts = <String, int>{};
    final db = DatabaseService.instance.database;
    for (final scope in scopes) {
      final junction = scope.table.junctionTable;
      final row = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM "$junction" WHERE tag_id = ?',
            variables: [Variable.withString(id)],
          )
          .getSingle();
      final n = row.read<int>('n');
      if (n > 0) counts[junction] = n;
    }
    return counts;
  }

  Never _gone(String id) => throw AgentToolException(
    AgentToolErrorCode.writeRefused,
    'Tag $id no longer exists.',
    details: {'id': id},
  );
}
