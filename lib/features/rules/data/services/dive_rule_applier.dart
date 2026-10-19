import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/dive_roles/data/repositories/dive_role_repository.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

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

  RuleChange _change(
    Rule rule,
    String diveId,
    String field,
    Object? before,
    Object? after,
  ) => RuleChange(
    subject: RuleSubject.dives,
    targetId: diveId,
    ruleId: rule.id,
    ruleName: rule.name,
    field: field,
    before: before,
    after: after,
  );

  Future<AppliedAction> _setField(
    Rule rule,
    SetDiveFieldAction a,
    List<String> ids,
  ) async {
    final ref = switch (a.field) {
      BulkField.diveCenter => ('dive_centers', a.values['diveCenterId']),
      BulkField.trip => ('trips', a.values['tripId']),
      _ => null,
    };
    if (ref != null &&
        ref.$2 is String &&
        (await existingIds(_db, ref.$1, [ref.$2! as String])).isEmpty) {
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
        _change(rule, id, a.field.name, before[id], after),
    ]);
  }

  Object? _valueOf(Expression<Object> e) => switch (e) {
    Variable(:final value) => value,
    Constant(:final value) => value,
    _ => throw StateError('unexpected column expression $e'),
  };

  Future<AppliedAction> _membership(
    Rule rule,
    DiveMembershipAction a,
    List<String> ids,
  ) async {
    final table = switch (a.collection) {
      DiveCollection.diveTypes => 'dive_types',
      DiveCollection.tags => 'tags',
      DiveCollection.equipment => 'equipment',
      DiveCollection.buddies => 'buddies',
      DiveCollection.courses => 'courses',
    };
    final present = await existingIds(_db, table, a.ids);
    final wanted = [
      for (final id in a.ids)
        if (present.contains(id)) id,
    ];
    final missing = wanted.length < a.ids.toSet().length;
    if (wanted.isEmpty) {
      return AppliedAction(const [], skippedMissingRef: missing);
    }
    final before = await members(a.collection, ids);
    final changed = [
      for (final id in ids)
        if (_wouldChange(before[id]!, a.mode, wanted)) id,
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
          _change(rule, id, a.collection.name, before[id], after[id]),
    ], skippedMissingRef: missing);
  }

  bool _wouldChange(
    List<Object> current,
    MembershipMode mode,
    List<String> ids,
  ) {
    final have = {for (final m in current) m is Map ? m['id'] : m};
    return switch (mode) {
      MembershipMode.add => ids.any((id) => !have.contains(id)),
      MembershipMode.remove => ids.any(have.contains),
    };
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
        add
            ? await _dives.bulkAddTags(diveIds, ids)
            : await _dives.bulkRemoveTags(diveIds, ids);
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
        await _roles.getDiveRoleById(roleId ?? 'buddy') ??
        await _roles.getDiveRoleById('buddy');
    if (role == null) return const [];
    return [
      for (final id in buddyIds)
        if (await _buddies.getBuddyById(id) case final buddy?)
          BuddyWithRole(buddy: buddy, roles: [role]),
    ];
  }

  /// Each dive's members of [c], sorted; buddies as `{id, role}` maps.
  Future<Map<String, List<Object>>> members(
    DiveCollection c,
    List<String> diveIds,
  ) async {
    if (c == DiveCollection.buddies) {
      final out = {for (final id in diveIds) id: <Object>[]};
      for (final chunk in ruleIdChunks(diveIds)) {
        final rows = await _db
            .customSelect(
              'SELECT dive_id, buddy_id, role FROM dive_buddies '
              'WHERE dive_id IN (${placeholders(chunk.length)}) '
              'ORDER BY buddy_id',
              variables: [for (final id in chunk) Variable.withString(id)],
            )
            .get();
        for (final r in rows) {
          out[r.read<String>('dive_id')]!.add({
            'id': r.read<String>('buddy_id'),
            'role': r.read<String>('role'),
          });
        }
      }
      return out;
    }
    final (table, column) = switch (c) {
      DiveCollection.diveTypes => ('dive_dive_types', 'dive_type_id'),
      DiveCollection.tags => ('dive_tags', 'tag_id'),
      DiveCollection.equipment => ('dive_equipment', 'equipment_id'),
      DiveCollection.courses => ('dive_courses', 'course_id'),
      DiveCollection.buddies => throw StateError('handled above'),
    };
    final linked = await linkedIds(
      _db,
      table: table,
      ownerColumn: 'dive_id',
      linkColumn: column,
      ownerIds: diveIds,
    );
    final out = {
      for (final e in linked.entries) e.key: <Object>[...e.value.toSet()],
    };
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
    for (final chunk in ruleIdChunks(empty)) {
      await _dives.bulkAppendNotes(chunk, text);
    }
    for (final chunk in ruleIdChunks(filled)) {
      await _dives.bulkAppendNotes(chunk, '\n$text');
    }
    return AppliedAction([
      for (final id in [...empty, ...filled])
        _change(
          rule,
          id,
          'notes',
          (before[id]!['notes'] as String?) ?? '',
          empty.contains(id) ? text : '${before[id]!['notes']}\n$text',
        ),
    ]);
  }
}
