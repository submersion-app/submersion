import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_field_value.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One kind of action the picker offers, before its values are chosen.
/// Exactly one of the field or collection members is set, or neither for
/// an append.
class RuleActionTemplate {
  const RuleActionTemplate.diveField(BulkField this.diveField)
    : siteField = null,
      diveCollection = null,
      siteCollection = null,
      mode = null,
      subject = RuleSubject.dives;

  const RuleActionTemplate.siteField(SiteRuleField this.siteField)
    : diveField = null,
      diveCollection = null,
      siteCollection = null,
      mode = null,
      subject = RuleSubject.sites;

  const RuleActionTemplate.diveMembership(
    DiveCollection this.diveCollection,
    MembershipMode this.mode,
  ) : diveField = null,
      siteField = null,
      siteCollection = null,
      subject = RuleSubject.dives;

  const RuleActionTemplate.siteMembership(
    SiteCollection this.siteCollection,
    MembershipMode this.mode,
  ) : diveField = null,
      siteField = null,
      diveCollection = null,
      subject = RuleSubject.sites;

  const RuleActionTemplate.append(this.subject)
    : diveField = null,
      siteField = null,
      diveCollection = null,
      siteCollection = null,
      mode = null;

  final RuleSubject subject;
  final BulkField? diveField;
  final SiteRuleField? siteField;
  final DiveCollection? diveCollection;
  final SiteCollection? siteCollection;
  final MembershipMode? mode;

  /// The template an existing action was made from, for editing it.
  static RuleActionTemplate? of(RuleAction a) => switch (a) {
    SetDiveFieldAction(:final field) => RuleActionTemplate.diveField(field),
    SetSiteFieldAction(:final field) => RuleActionTemplate.siteField(field),
    DiveMembershipAction(:final collection, :final mode) =>
      RuleActionTemplate.diveMembership(collection, mode),
    SiteMembershipAction(:final collection, :final mode) =>
      RuleActionTemplate.siteMembership(collection, mode),
    AppendDiveNotesAction() => const RuleActionTemplate.append(
      RuleSubject.dives,
    ),
    AppendSiteDescriptionAction() => const RuleActionTemplate.append(
      RuleSubject.sites,
    ),
    UnknownRuleAction() => null,
  };

  String label(AppLocalizations l) {
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    if (diveField != null) {
      return l.rules_picker_set(ruleDiveFieldLabel(l, diveField!));
    }
    if (siteField != null) {
      return l.rules_picker_set(ruleSiteFieldLabel(l, siteField!));
    }
    final collection = diveCollection != null
        ? ruleDiveCollectionLabel(l, diveCollection!)
        : siteCollection != null
        ? ruleSiteCollectionLabel(l, siteCollection!)
        : null;
    if (collection != null) {
      return cap(
        mode == MembershipMode.add
            ? l.rules_picker_add(collection)
            : l.rules_picker_remove(collection),
      );
    }
    return subject == RuleSubject.dives
        ? l.rules_picker_appendNotes
        : l.rules_picker_appendDescription;
  }

  String get key =>
      diveField?.name ??
      siteField?.name ??
      '${diveCollection?.name ?? siteCollection?.name ?? 'append'}'
          '_${mode?.name ?? subject.name}';
}

/// Every action a [subject] rule can take, memberships first.
List<RuleActionTemplate> ruleActionTemplates(RuleSubject subject) =>
    switch (subject) {
      RuleSubject.dives => [
        for (final c in DiveCollection.values)
          for (final m in MembershipMode.values)
            RuleActionTemplate.diveMembership(c, m),
        const RuleActionTemplate.append(RuleSubject.dives),
        for (final f in kRuleSettableDiveFields)
          RuleActionTemplate.diveField(f),
      ],
      RuleSubject.sites => [
        for (final c in SiteCollection.values)
          for (final m in MembershipMode.values)
            RuleActionTemplate.siteMembership(c, m),
        const RuleActionTemplate.append(RuleSubject.sites),
        for (final f in SiteRuleField.values) RuleActionTemplate.siteField(f),
      ],
    };

/// The searchable "+ Add action" list.
Future<RuleActionTemplate?> showRuleActionPicker(
  BuildContext context,
  RuleSubject subject,
) => showModalBottomSheet<RuleActionTemplate>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _PickerSheet(templates: ruleActionTemplates(subject)),
);

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.templates});

  final List<RuleActionTemplate> templates;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final q = _search.trim().toLowerCase();
    final shown = [
      for (final t in widget.templates)
        if (q.isEmpty || t.label(l10n).toLowerCase().contains(q)) t,
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  key: const ValueKey('rule_action_search'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.rules_picker_search,
                  ),
                  onChanged: (s) => setState(() => _search = s),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in shown)
                      ListTile(
                        key: ValueKey('rule_pick_${t.key}'),
                        title: Text(t.label(l10n)),
                        onTap: () => Navigator.of(context).pop(t),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
