import 'package:drift/drift.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_classification_repository.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/services/site_country_code.dart';
import 'package:submersion/features/rules/data/services/rule_applier_support.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/core/text/markdown/notes_markdown.dart';

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
    // A country brings its code along (issue #4426), so the flag never stays
    // on the country the rule replaced. Each change records the code beside
    // the country, so an undo puts both back.
    final withCode = a.field == SiteRuleField.country;
    final before = await columnValues(
      _db,
      table: 'dive_sites',
      columns: [column, if (withCode) _countryCodeColumn],
      ids: ids,
    );
    final written = <String, Map<String, Object?>>{
      for (final id in ids)
        if (before[id] case final was?
            when !sameColumns({column: was[column]}, after))
          id: {
            ...after,
            if (withCode)
              _countryCodeColumn: countryCodeOnSave(
                country: after[column] as String?,
                known: (
                  country: was[column] as String?,
                  code: was[_countryCodeColumn] as String?,
                ),
              ),
          },
    };
    if (written.isEmpty) return AppliedAction.none;
    // Sites given the same values share one UPDATE; only a country's code
    // can differ between them.
    final groups = <Object?, List<String>>{};
    for (final entry in written.entries) {
      groups
          .putIfAbsent(entry.value[_countryCodeColumn], () => [])
          .add(entry.key);
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final group in groups.values) {
      final values = written[group.first]!;
      for (final chunk in ruleIdChunks(group)) {
        // The column names come from SiteRuleField and this class, never
        // from stored data.
        await _db.customUpdate(
          'UPDATE dive_sites SET '
          '${[for (final k in values.keys) '$k = ?'].join(', ')}, '
          'updated_at = ? '
          'WHERE id IN (${ruleIdPlaceholders(chunk.length)})',
          variables: [
            for (final v in values.values) Variable(v),
            Variable.withInt(now),
            for (final id in chunk) Variable.withString(id),
          ],
          updates: {_db.diveSites},
        );
      }
    }
    final changed = written.keys.toList();
    await _sync.markRecordsPending(
      entityType: 'diveSites',
      recordIds: changed,
      localUpdatedAt: now,
    );
    return AppliedAction([
      for (final id in changed)
        ruleChange(rule, id, a.field.name, before[id], written[id]),
    ]);
  }

  /// The column a site's ISO country code lives in (issue #4426).
  static const _countryCodeColumn = 'country_code';

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
    if (changed.isNotEmpty) {
      final distinct = wanted.toSet();
      add
          ? await _addToAll(a.collection, wanted, {
              for (final id in changed)
                id: [
                  for (final w in distinct)
                    if (!before[id]!.contains(w)) w,
                ],
            })
          : await _removeFromAll(a.collection, changed, wanted);
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

  /// Adds to [c] the ids [missing] names for each of its sites, in one pass
  /// over what the caller just read (#4012). [wanted] is widened once, not
  /// once per site.
  Future<void> _addToAll(
    SiteCollection c,
    List<String> wanted,
    Map<String, List<String>> missing,
  ) async {
    switch (c) {
      case SiteCollection.tags:
        // A link implies its scope: a dive-only tag becomes a site tag too.
        await _tags.widenScope(wanted, TagScope.sites, notify: false);
        await _classification.addTagsToSites(missing);
      case SiteCollection.siteTypes:
        await _classification.addTypesToSites(missing);
    }
  }

  /// Removes [ids] from [c] on every one of [siteIds] (#4012).
  Future<void> _removeFromAll(
    SiteCollection c,
    List<String> siteIds,
    List<String> ids,
  ) => switch (c) {
    SiteCollection.tags => _classification.removeTagsFromSites(siteIds, ids),
    SiteCollection.siteTypes => _classification.removeTypesFromSites(
      siteIds,
      ids,
    ),
  };

  /// Adds [ids], which [siteId] lacks, to [c], or removes them from it,
  /// without notifying. Undo's write: it restores one change at a time.
  Future<void> writeMembership(
    SiteCollection c, {
    required bool add,
    required String siteId,
    required List<String> ids,
  }) =>
      add ? _addToAll(c, ids, {siteId: ids}) : _removeFromAll(c, [siteId], ids);

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
    final present = [
      for (final id in ids)
        if (before[id] != null) id,
    ];
    await _sites.appendDescriptionToAll(present, text);
    String old(String id) => (before[id]!['description'] as String?) ?? '';
    return AppliedAction([
      for (final id in present)
        ruleChange(
          rule,
          id,
          'description',
          old(id),
          appendMarkdownParagraph(old(id), text),
        ),
    ]);
  }
}
