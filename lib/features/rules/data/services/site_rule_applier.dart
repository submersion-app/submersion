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
import 'package:submersion/features/rules/domain/rule_subject.dart';

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

  RuleChange _change(
    Rule rule,
    String siteId,
    String field,
    Object? before,
    Object? after,
  ) => RuleChange(
    subject: RuleSubject.sites,
    targetId: siteId,
    ruleId: rule.id,
    ruleName: rule.name,
    field: field,
    before: before,
    after: after,
  );

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
        'WHERE id IN (${placeholders(chunk.length)})',
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
        _change(rule, id, a.field.name, before[id], after),
    ]);
  }

  Future<AppliedAction> _membership(
    Rule rule,
    SiteMembershipAction a,
    List<String> ids,
  ) async {
    final tags = a.collection == SiteCollection.tags;
    final present = await existingIds(_db, tags ? 'tags' : 'site_types', a.ids);
    final wanted = [
      for (final id in a.ids)
        if (present.contains(id)) id,
    ];
    final missing = wanted.length < a.ids.toSet().length;
    if (wanted.isEmpty) {
      return AppliedAction(const [], skippedMissingRef: missing);
    }
    Future<Map<String, List<String>>> members(List<String> siteIds) =>
        linkedIds(
          _db,
          table: tags ? 'site_tags' : 'site_site_types',
          ownerColumn: 'site_id',
          linkColumn: tags ? 'tag_id' : 'site_type_id',
          ownerIds: siteIds,
        );
    final before = await members(ids);
    final add = a.mode == MembershipMode.add;
    final changed = [
      for (final id in ids)
        if (add
            ? wanted.any((w) => !before[id]!.contains(w))
            : wanted.any(before[id]!.contains))
          id,
    ];
    for (final id in changed) {
      switch ((tags, add)) {
        case (true, true):
          await _classification.addTags(id, wanted, notify: false);
        case (true, false):
          await _classification.removeTags(id, wanted, notify: false);
        case (false, true):
          await _classification.addTypes(id, wanted, notify: false);
        case (false, false):
          await _classification.removeTypes(id, wanted, notify: false);
      }
    }
    final after = changed.isEmpty
        ? const <String, List<String>>{}
        : await members(changed);
    return AppliedAction([
      for (final id in changed)
        if (!sameList(before[id]!, after[id]!))
          _change(rule, id, a.collection.name, before[id], after[id]),
    ], skippedMissingRef: missing);
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
        _change(
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
