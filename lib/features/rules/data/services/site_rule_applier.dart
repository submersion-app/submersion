import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

/// Applies one site action of a logbook rule (#3513), writing only the
/// sites it changes and recording each change. The engine scopes targets
/// to the diver's own non-library sites, opens the transaction and
/// notifies; this never does.
class SiteRuleApplier {
  SiteRuleApplier({
    SiteClassificationRepository? classification,
    SiteRepository? sites,
  }) : _classification = classification ?? SiteClassificationRepository(),
       _sites = sites ?? SiteRepository();

  final SiteClassificationRepository _classification;
  final SiteRepository _sites;
  final SyncRepository _sync = SyncRepository();
  final TagRepository _tags = TagRepository();

  AppDatabase get _db => DatabaseService.instance.database;

  Future<AppliedAction> apply(
    Rule rule,
    RuleAction action,
    List<String> siteIds,
  ) async {
    if (siteIds.isEmpty) return AppliedAction.none;
    return switch (action) {
      SetSiteFieldAction() => _setField(rule, action, siteIds),
      SiteMembershipAction() => _membership(rule, action, siteIds),
      AppendSiteDescriptionAction(:final text) => _append(rule, text, siteIds),
      _ => Future.value(AppliedAction.none),
    };
  }

  Future<AppliedAction> _setField(
    Rule rule,
    SetSiteFieldAction a,
    List<String> ids,
  ) async {
    final column = a.field.column;
    final after = {column: storedForm(a.value)};
    final before = await columnValues(
      _db,
      table: 'dive_sites',
      columns: [column],
      ids: ids,
    );
    final changed = [
      for (final id in ids)
        if (before[id] != null && !sameColumns(before[id]!, after)) id,
    ];
    if (changed.isEmpty) return AppliedAction.none;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final chunk in ruleIdChunks(changed)) {
      // The column name comes from SiteRuleField, never from stored data.
      await _db.customUpdate(
        'UPDATE dive_sites SET $column = ?, updated_at = ? '
        'WHERE id IN (${ruleIdPlaceholders(chunk.length)})',
        variables: [
          Variable(after[column]),
          Variable.withInt(now),
          for (final id in chunk) Variable.withString(id),
        ],
        updates: {_db.diveSites},
      );
    }
    for (final id in changed) {
      await _sync.markRecordPending(
        entityType: 'diveSites',
        recordId: id,
        localUpdatedAt: now,
      );
    }
    return AppliedAction([
      for (final id in changed)
        ruleChange(rule, id, a.field.name, before[id], after),
    ]);
  }

  /// The table the ids of [c] name.
  static TableInfo<Table, dynamic> refTable(AppDatabase db, SiteCollection c) =>
      switch (c) {
        SiteCollection.tags => db.tags,
        SiteCollection.siteTypes => db.siteTypes,
      };

  Future<AppliedAction> _membership(
    Rule rule,
    SiteMembershipAction a,
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
    Future<Map<String, List<String>>> read(List<String> siteIds) =>
        members(a.collection, siteIds);
    final before = await read(ids);
    final add = a.mode == MembershipMode.add;
    final changed = [
      for (final id in ids)
        if (add
            ? wanted.any((w) => !before[id]!.contains(w))
            : wanted.any(before[id]!.contains))
          id,
    ];
    for (final id in changed) {
      await writeMembership(a.collection, add: add, siteId: id, ids: wanted);
    }
    final after = changed.isEmpty
        ? const <String, List<String>>{}
        : await read(changed);
    return AppliedAction([
      for (final id in changed)
        if (!sameList(before[id]!, after[id]!))
          ruleChange(rule, id, a.collection.name, before[id], after[id]),
    ], skippedMissingRef: missing);
  }

  /// Each site's members of [c], sorted, through the repository's readers.
  Future<Map<String, List<String>>> members(
    SiteCollection c,
    List<String> siteIds,
  ) async {
    final out = {for (final id in siteIds) id: <String>[]};
    for (final chunk in ruleIdChunks(siteIds)) {
      final linked = c == SiteCollection.tags
          ? await _classification.getTagIdsBySite(chunk)
          : await _classification.getTypeIdsBySite(chunk);
      for (final e in linked.entries) {
        out[e.key] = [...e.value.toSet()]..sort();
      }
    }
    return out;
  }

  /// Adds [ids] to, or removes them from, [c] on one site, without
  /// notifying.
  Future<void> writeMembership(
    SiteCollection c, {
    required bool add,
    required String siteId,
    required List<String> ids,
  }) async {
    switch ((c, add)) {
      case (SiteCollection.tags, true):
        // A link implies its scope: a dive-only tag becomes a site tag too.
        await _tags.widenScope(ids, TagScope.sites, notify: false);
        await _classification.addTags(siteId, ids, notify: false);
      case (SiteCollection.tags, false):
        await _classification.removeTags(siteId, ids, notify: false);
      case (SiteCollection.siteTypes, true):
        await _classification.addTypes(siteId, ids, notify: false);
      case (SiteCollection.siteTypes, false):
        await _classification.removeTypes(siteId, ids, notify: false);
    }
  }

  Future<AppliedAction> _append(
    Rule rule,
    String text,
    List<String> ids,
  ) async {
    if (text.isEmpty) return AppliedAction.none;
    final before = await columnValues(
      _db,
      table: 'dive_sites',
      columns: const ['description'],
      ids: ids,
    );
    final changes = <RuleChange>[];
    for (final id in ids) {
      if (before[id] == null) continue;
      final old = (before[id]!['description'] as String?) ?? '';
      await _sites.appendDescription(id, text);
      changes.add(
        ruleChange(
          rule,
          id,
          'description',
          old,
          old.isEmpty ? text : '$old\n$text',
        ),
      );
    }
    return AppliedAction(changes);
  }
}
