import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/data/services/rule_target_labels.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/entities/rule_run.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum RuleChangeGrouping { target, rule }

/// How one change reads: its field and before and after values in the
/// diver's units and language, ids shown as names.
({String field, String before, String after, String? appended})
describeRuleChange(
  AppLocalizations l,
  UnitFormatter u,
  RuleChange c,
  RuleNameOf nameOf,
) {
  String names(Object? list, QuerySubject subject) {
    final items = [
      for (final m in (list as List?) ?? const [])
        nameOf(subject, m is Map ? '${m['id']}' : '$m') ??
            l.rules_actionSummary_missing,
    ];
    return items.isEmpty ? l.rules_value_empty : items.join(', ');
  }

  if (c.field == 'notes' || c.field == 'description') {
    final before = (c.before as String?) ?? '';
    final after = (c.after as String?) ?? '';
    return (
      field: c.field == 'notes'
          ? l.rules_field_notes
          : l.rules_siteField_description,
      before: before,
      after: after,
      appended: after.length >= before.length
          ? after.substring(before.length).trim()
          : after,
    );
  }
  if (c.subject == RuleSubject.dives) {
    final collection = DiveCollection.values.asNameMap()[c.field];
    if (collection != null) {
      final subject = diveCollectionSubject(collection);
      return (
        field: ruleDiveCollectionLabel(l, collection),
        before: names(c.before, subject),
        after: names(c.after, subject),
        appended: null,
      );
    }
    final field = BulkField.values.asNameMap()[c.field];
    final column = field == null ? null : diveFieldColumn(field);
    if (field != null && column != null) {
      String value(Object? cols) {
        final map = (cols as Map?) ?? const {};
        if (field == BulkField.diluentGas) {
          return ruleDiluentLabel(
            map['diluent_o2'] as num?,
            map['diluent_he'] as num?,
          );
        }
        return ruleValueLabel(
          l,
          u,
          kind: diveFieldKind(field),
          unit: diveFieldUnit(field),
          fieldName: field.name,
          value: map[column],
          refSubject: diveFieldRefSubject(field),
          nameOf: nameOf,
        );
      }

      return (
        field: ruleDiveFieldLabel(l, field),
        before: value(c.before),
        after: value(c.after),
        appended: null,
      );
    }
  } else {
    final collection = SiteCollection.values.asNameMap()[c.field];
    if (collection != null) {
      final subject = siteCollectionSubject(collection);
      return (
        field: ruleSiteCollectionLabel(l, collection),
        before: names(c.before, subject),
        after: names(c.after, subject),
        appended: null,
      );
    }
    final field = SiteRuleField.values.asNameMap()[c.field];
    if (field != null) {
      String value(Object? cols) => ruleValueLabel(
        l,
        u,
        kind: field.kind,
        unit: siteFieldUnit(field),
        fieldName: field.name,
        value: ((cols as Map?) ?? const {})[field.column],
      );
      return (
        field: ruleSiteFieldLabel(l, field),
        before: value(c.before),
        after: value(c.after),
        appended: null,
      );
    }
  }
  return (
    field: c.field,
    before: '${c.before}',
    after: '${c.after}',
    appended: null,
  );
}

/// The heading of a dive or site in a change list.
String ruleTargetHeading(
  AppLocalizations l,
  UnitFormatter u,
  RuleSubject subject,
  RuleTargetInfo? info,
) {
  if (info == null) return l.rules_actionSummary_missing;
  if (subject == RuleSubject.sites) {
    return [info.name, info.place].whereType<String>().join(', ');
  }
  return [
    if (info.number != null) '#${info.number}',
    info.name ?? l.rules_target_noSite,
    if (info.date != null) u.formatDate(info.date),
  ].join(' ');
}

/// A run's changes, one block per dive or site (or per rule), built lazily
/// so a run over a whole logbook stays responsive.
class RuleChangeList extends StatelessWidget {
  const RuleChangeList({
    super.key,
    required this.changes,
    required this.targets,
    required this.units,
    required this.nameOf,
    this.grouping = RuleChangeGrouping.target,
  });

  final List<RuleChange> changes;
  final Map<String, RuleTargetInfo> targets;
  final UnitFormatter units;
  final RuleNameOf nameOf;
  final RuleChangeGrouping grouping;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Grouping is cheap; a row's text is made only when the row is built,
    // so a run over a whole logbook formats what is on screen, not all of
    // it on every rebuild.
    final rows = <(RuleChange change, bool header)>[];
    final groups = <String, List<RuleChange>>{};
    for (final c in changes) {
      // By rule id: two rules may share a name (a copy renamed back).
      final key = grouping == RuleChangeGrouping.target
          ? '${c.subject.name}:${c.targetId}'
          : c.ruleId ?? c.ruleName;
      groups.putIfAbsent(key, () => []).add(c);
    }
    for (final group in groups.values) {
      rows.add((group.first, true));
      for (final c in group) {
        rows.add((c, false));
      }
    }
    String textOf(RuleChange c, bool header) {
      if (header) {
        return grouping == RuleChangeGrouping.target
            ? ruleTargetHeading(l, units, c.subject, targets[c.targetId])
            : c.ruleName;
      }
      final d = describeRuleChange(l, units, c, nameOf);
      final who = grouping == RuleChangeGrouping.target
          ? c.ruleName
          : ruleTargetHeading(l, units, c.subject, targets[c.targetId]);
      return d.appended != null
          ? '$who: ${l.rules_change_appended(d.field, d.appended!)}'
          : l.rules_change_line(who, d.field, d.before, d.after);
    }

    final theme = Theme.of(context);
    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final (change, header) = rows[i];
        final text = textOf(change, header);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            header ? 16 : 32,
            header ? 12 : 2,
            16,
            header ? 4 : 2,
          ),
          child: Text(
            text,
            style: header
                ? theme.textTheme.titleSmall
                : theme.textTheme.bodyMedium,
          ),
        );
      },
    );
  }
}

/// By item or by rule, for a change list.
class RuleChangeGroupingToggle extends StatelessWidget {
  const RuleChangeGroupingToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RuleChangeGrouping value;
  final ValueChanged<RuleChangeGrouping> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SegmentedButton<RuleChangeGrouping>(
      segments: [
        ButtonSegment(
          value: RuleChangeGrouping.target,
          label: Text(l.rules_preview_groupByTarget),
        ),
        ButtonSegment(
          value: RuleChangeGrouping.rule,
          label: Text(l.rules_preview_groupByRule),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.single),
    );
  }
}
