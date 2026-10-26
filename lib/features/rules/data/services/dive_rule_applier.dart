import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/existing_row_ids.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_link_repository.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/core/text/markdown/notes_markdown.dart';

/// Applies one dive action of a logbook rule (#3513) through the bulk edit
/// primitives, writing only the dives it changes and recording each change.
/// Never opens a transaction or notifies: the engine does both once.
class DiveRuleApplier {
  DiveRuleApplier({
    DiveRepository? diveRepository,
    BuddyRepository? buddyRepository,
    DiveRoleRepository? roleRepository,
  }) : _dives = diveRepository ?? DiveRepository(),
       _buddies = buddyRepository ?? BuddyRepository(),
       _roles = roleRepository ?? DiveRoleRepository();

  final DiveRepository _dives;
  final BuddyRepository _buddies;
  final DiveRoleRepository _roles;
  final DiveRoleLinkRepository _roleLinks = DiveRoleLinkRepository();
  final TagRepository _tags = TagRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  Future<AppliedAction> apply(
    Rule rule,
    RuleAction action,
    List<String> diveIds,
  ) async {
    if (diveIds.isEmpty) return AppliedAction.none;
    return switch (action) {
      SetDiveFieldAction() => _setField(rule, action, diveIds),
      DiveMembershipAction() => _membership(rule, action, diveIds),
      AppendDiveNotesAction(:final text) => _append(rule, text, diveIds),
      _ => Future.value(AppliedAction.none),
    };
  }

  Future<AppliedAction> _setField(
    Rule rule,
    SetDiveFieldAction a,
    List<String> ids,
  ) async {
    final (TableInfo<Table, dynamic>, Object?)? ref = switch (a.field) {
      BulkField.diveCenter => (_db.diveCenters, a.values['diveCenterId']),
      BulkField.trip => (_db.trips, a.values['tripId']),
      _ => null,
    };
    if (ref != null &&
        ref.$2 is String &&
        (await existingRowIds(_db, ref.$1, [ref.$2! as String])).isEmpty) {
      return const AppliedAction([], skippedMissingRef: true);
    }
    final companion = diveCompanionFor(a);
    final after = {
      for (final e in companion.toColumns(false).entries)
        e.key: storedForm(_valueOf(e.value)),
    };
    if (after.isEmpty) return AppliedAction.none;
    final before = await columnValues(
      _db,
      table: 'dives',
      columns: after.keys.toList(),
      ids: ids,
    );
    final changed = [
      for (final id in ids)
        if (before[id] != null && !sameColumns(before[id]!, after)) id,
    ];
    if (changed.isEmpty) return AppliedAction.none;
    for (final chunk in ruleIdChunks(changed)) {
      await _dives.bulkUpdateFields(chunk, companion);
    }
    return AppliedAction([
      for (final id in changed)
        ruleChange(rule, id, a.field.name, before[id], after),
    ]);
  }

  Object? _valueOf(Expression<Object> e) => switch (e) {
    Variable(:final value) => value,
    Constant(:final value) => value,
    _ => throw StateError('unexpected column expression $e'),
  };

  /// The table the ids of [c] name.
  static TableInfo<Table, dynamic> refTable(AppDatabase db, DiveCollection c) =>
      switch (c) {
        DiveCollection.diveTypes => db.diveTypes,
        DiveCollection.tags => db.tags,
        DiveCollection.equipment => db.equipment,
        DiveCollection.buddies => db.buddies,
        DiveCollection.courses => db.courses,
      };

  Future<AppliedAction> _membership(
    Rule rule,
    DiveMembershipAction a,
    List<String> ids,
  ) async {
    final (present: wanted, :missing) = await presentRefs(
      _db,
      refTable(_db, a.collection),
      a.ids,
    );
    if (wanted.isEmpty) {
      return AppliedAction(const [], skippedMissingRef: missing);
    }
    final before = await members(a.collection, ids);
    final changed = [
      for (final id in ids)
        if (_wouldChange(a.collection, before[id]!, a.mode, wanted)) id,
    ];
    if (changed.isNotEmpty) {
      for (final chunk in ruleIdChunks(changed)) {
        await writeMembership(
          a.collection,
          add: a.mode == MembershipMode.add,
          diveIds: chunk,
          ids: wanted,
          buddyRoleId: a.buddyRoleId,
        );
      }
    }
    final after = changed.isEmpty
        ? const <String, List<Object>>{}
        : await members(a.collection, changed);
    return AppliedAction([
      for (final id in changed)
        if (!sameList(before[id]!, after[id]!))
          ruleChange(rule, id, a.collection.name, before[id], after[id]),
    ], skippedMissingRef: missing);
  }

  bool _wouldChange(
    DiveCollection collection,
    List<Object> current,
    MembershipMode mode,
    List<String> ids,
  ) {
    final have = {for (final m in current) m is Map ? m['id'] : m};
    if (mode == MembershipMode.add) return ids.any((id) => !have.contains(id));
    if (collection == DiveCollection.diveTypes) {
      // A dive always keeps a type: removing its last falls back to
      // recreational, so removing recreational alone changes nothing.
      final left = have.difference(ids.toSet());
      final kept = left.isEmpty ? const {'recreational'} : left;
      return kept.length != have.length || !kept.containsAll(have);
    }
    return ids.any(have.contains);
  }

  /// Adds [ids] to, or removes them from, [collection] on [diveIds] through
  /// the bulk primitives. Added buddies get [buddyRoleId].
  Future<void> writeMembership(
    DiveCollection collection, {
    required bool add,
    required List<String> diveIds,
    required List<String> ids,
    String? buddyRoleId,
  }) async {
    switch (collection) {
      case DiveCollection.diveTypes:
        add
            ? await _dives.bulkAddDiveTypes(diveIds, ids)
            : await _dives.bulkRemoveDiveTypes(diveIds, ids);
      case DiveCollection.tags:
        if (add) {
          // A link implies its scope: a site-only tag becomes a dive tag too.
          await _tags.widenScope(ids, TagScope.dives, notify: false);
          await _dives.bulkAddTags(diveIds, ids, notify: false);
        } else {
          await _dives.bulkRemoveTags(diveIds, ids, notify: false);
        }
      case DiveCollection.equipment:
        add
            ? await _dives.bulkAddEquipment(diveIds, ids)
            : await _dives.bulkRemoveEquipment(diveIds, ids);
      case DiveCollection.courses:
        add
            ? await _dives.bulkAddCourses(diveIds, ids)
            : await _dives.bulkRemoveCourses(diveIds, ids);
      case DiveCollection.buddies:
        if (add) {
          await _buddies.bulkAddBuddies(
            diveIds,
            await buddiesWithRole(ids, buddyRoleId),
            overwriteRole: false,
          );
        } else {
          await _buddies.bulkRemoveBuddies(diveIds, ids);
        }
    }
  }

  /// The [BuddyWithRole]s the buddy write needs, each holding [roleId] (or
  /// the built-in buddy role).
  Future<List<BuddyWithRole>> buddiesWithRole(
    List<String> buddyIds,
    String? roleId,
  ) async {
    final role =
        await _roles.getDiveRoleById(roleId ?? DiveRole.buddyId) ??
        await _roles.getDiveRoleById(DiveRole.buddyId);
    if (role == null) return const [];
    return [
      for (final id in buddyIds)
        if (await _buddies.getBuddyById(id) case final buddy?)
          BuddyWithRole(buddy: buddy, roles: [role]),
    ];
  }

  /// Puts each buddy of [rolesByBuddy] back on [diveId] with every role it
  /// held there, for undo. A role deleted since is dropped (a buddy left
  /// with none gets the built-in buddy role); a buddy deleted since is not
  /// added.
  Future<void> addBuddiesWithRoles(
    String diveId,
    Map<String, List<String>> rolesByBuddy,
  ) async {
    final fallback = await _roles.getDiveRoleById(DiveRole.buddyId);
    final links = <BuddyWithRole>[];
    for (final e in rolesByBuddy.entries) {
      final buddy = await _buddies.getBuddyById(e.key);
      if (buddy == null) continue;
      final roles = [
        for (final id in e.value) ?await _roles.getDiveRoleById(id),
      ];
      if (roles.isEmpty && fallback == null) continue;
      links.add(
        BuddyWithRole(buddy: buddy, roles: roles.isEmpty ? [fallback!] : roles),
      );
    }
    await _buddies.bulkAddBuddies([diveId], links, overwriteRole: false);
  }

  /// Makes [diveId]'s dive types exactly [typeIds], the first its
  /// representative type, for undo.
  Future<void> replaceDiveTypes(String diveId, List<String> typeIds) =>
      _dives.bulkReplaceDiveTypes([diveId], typeIds);

  /// Makes [diveId]'s gear exactly [rows], provenance included, for undo.
  Future<void> replaceGear(String diveId, List<GearProvenance> rows) =>
      _dives.replaceGearRows(diveId, rows);

  /// Each dive's members of [c], as undo needs them to put them back: dive
  /// types in order (the first is the dive's representative), buddies as
  /// `{id, roles}` with every role held, gear as `{id, via?, set?}` with
  /// the assembly and set it came through, the rest as sorted ids.
  Future<Map<String, List<Object>>> members(
    DiveCollection c,
    List<String> diveIds,
  ) async {
    final out = {for (final id in diveIds) id: <Object>[]};
    for (final chunk in ruleIdChunks(diveIds)) {
      switch (c) {
        case DiveCollection.buddies:
          final sets = await _roleLinks.buddyRoleIdsForDives(chunk);
          for (final e in sets.entries) {
            out[e.key] = <Object>[
              for (final b in e.value.keys.toList()..sort())
                {'id': b, 'roles': e.value[b]!},
            ];
          }
        case DiveCollection.equipment:
          for (final r in await _rows(
            'SELECT dive_id, equipment_id, via_equipment_id, via_set_id '
            'FROM dive_equipment WHERE dive_id IN (?) ORDER BY equipment_id',
            chunk,
          )) {
            out[r.read<String>('dive_id')]!.add({
              'id': r.read<String>('equipment_id'),
              'via': ?r.readNullable<String>('via_equipment_id'),
              'set': ?r.readNullable<String>('via_set_id'),
            });
          }
        case DiveCollection.courses:
          // Through the reader the writes use: a dive with no junction rows
          // yet holds its legacy course column.
          for (final e in (await _dives.courseIdsForDives(chunk)).entries) {
            out[e.key] = <Object>[...(List.of(e.value)..sort())];
          }
        case DiveCollection.diveTypes:
          for (final e in (await _dives.diveTypeIdsForDives(chunk)).entries) {
            out[e.key] = <Object>[...e.value];
          }
        case DiveCollection.tags:
          final linked = await linkedIds(
            _db,
            table: 'dive_tags',
            ownerColumn: 'dive_id',
            linkColumn: 'tag_id',
            ownerIds: chunk,
          );
          for (final e in linked.entries) {
            out[e.key] = <Object>[...e.value.toSet()];
          }
      }
    }
    if (c == DiveCollection.diveTypes) {
      // A dive always has a type: one with no junction rows (a legacy dive)
      // holds its representative column, as the bulk write seeds it.
      final bare = [
        for (final e in out.entries)
          if (e.value.isEmpty) e.key,
      ];
      if (bare.isNotEmpty) {
        final reps = await columnValues(
          _db,
          table: 'dives',
          columns: const ['dive_type'],
          ids: bare,
        );
        for (final id in bare) {
          out[id] = [(reps[id]?['dive_type'] as String?) ?? 'recreational'];
        }
      }
    }
    return out;
  }

  /// [sql]'s rows for [ids], its single `IN (?)` expanded to fit them.
  Future<List<QueryRow>> _rows(String sql, List<String> ids) => _db
      .customSelect(
        sql.replaceFirst('IN (?)', 'IN (${ruleIdPlaceholders(ids.length)})'),
        variables: [for (final id in ids) Variable.withString(id)],
      )
      .get();

  Future<AppliedAction> _append(
    Rule rule,
    String text,
    List<String> ids,
  ) async {
    if (text.isEmpty) return AppliedAction.none;
    final before = await columnValues(
      _db,
      table: 'dives',
      columns: const ['notes'],
      ids: ids,
    );
    final empty = <String>[];
    final filled = <String>[];
    for (final id in ids) {
      final notes = before[id]?['notes'] as String?;
      if (before[id] == null) continue;
      ((notes ?? '').isEmpty ? empty : filled).add(id);
    }
    // bulkAppendNotes adds the paragraph break only where notes exist.
    for (final chunk in ruleIdChunks([...empty, ...filled])) {
      await _dives.bulkAppendNotes(chunk, text);
    }
    return AppliedAction([
      for (final id in empty) ruleChange(rule, id, 'notes', '', text),
      for (final id in filled)
        ruleChange(
          rule,
          id,
          'notes',
          before[id]!['notes'] as String,
          appendMarkdownParagraph(before[id]!['notes'] as String, text),
        ),
    ]);
  }
}
