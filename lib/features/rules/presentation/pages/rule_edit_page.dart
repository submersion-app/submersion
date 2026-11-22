import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/entity_query_editor.dart';
import 'package:submersion/features/insights/data/dive_filter_sql.dart';
import 'package:submersion/features/insights/presentation/providers/dive_deco_status_providers.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_action_card.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_action_editor.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_action_picker_sheet.dart';
import 'package:submersion/features/rules/presentation/pages/rule_draft.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// Creates or edits one logbook rule (#3513): its name, what it applies to
/// (new rules only), when it runs, its condition in the query editor with
/// a live match count, and its actions. A rule a newer version saved opens
/// read-only.
///
/// Edited on the shared Cancel and Save bar (issue #4527, phase 4): Save is
/// one transaction and one History entry, and leaving with unsaved changes
/// asks first. A read-only rule opens no sitting, so it keeps a plain bar.
class RuleEditPage extends ConsumerStatefulWidget {
  const RuleEditPage({super.key, this.ruleId});

  /// Null for a new rule.
  final String? ruleId;

  @override
  ConsumerState<RuleEditPage> createState() => _RuleEditPageState();
}

class _RuleEditPageState extends ConsumerState<RuleEditPage>
    with RecordEditorHost<RuleEditPage, RuleDraft> {
  final _name = TextEditingController();
  Rule? _original;
  RuleSubject _subject = RuleSubject.dives;
  Set<RuleTrigger> _triggers = {RuleTrigger.afterImport};
  QueryNode? _condition;

  /// The stored rule while it loads; closed once it has.
  ProviderSubscription<AsyncValue<Rule?>>? _loading;

  /// The stored rule could not be read, or is gone.
  bool _loadFailed = false;

  /// Whether the diver edited the condition. A rule whose stored condition
  /// did not load shows no match count unless they did.
  bool _conditionTouched = false;

  /// False while the condition's text does not parse: the editor then
  /// still holds the last tree that did, which is not what the diver sees,
  /// so Save waits.
  bool _conditionValid = true;
  List<RuleAction> _actions = [];

  bool get _isNew => widget.ruleId == null;

  /// The rule has a stored condition that did not load into a tree (it can
  /// no longer be read, or names a field this version rejects): the editor
  /// shows none, so an edit of it replaces what is stored even when it ends
  /// as none. A condition that loaded, or no stored condition, is compared
  /// as it reads.
  bool get _storedConditionUnloaded {
    final original = _original;
    return original != null &&
        original.conditionJson.isNotEmpty &&
        original.condition == null;
  }

  bool get _readOnly =>
      _original?.problem == RuleLoadProblem.newerVersion ||
      _actions.any((a) => a is UnknownRuleAction);

  @override
  void initState() {
    super.initState();
    _name.addListener(() => _change(() {}));
    final id = widget.ruleId;
    if (id == null) {
      // From the blank rule: the form's defaults are that rule, so it opens
      // unchanged.
      openEditor(from: blankRuleDraft);
      return;
    }
    // Read once: the editor fills itself from the first value and ignores
    // later ticks. A manual listen keeps the auto-dispose rule alive while
    // it loads.
    final loading = ref.listenManual<AsyncValue<Rule?>>(
      ruleByIdProvider(id),
      (_, next) => _loaded(next),
      fireImmediately: true,
    );
    // A rule already loaded answered at once, before there was a
    // subscription to close: close it now.
    if (_settled) {
      loading.close();
    } else {
      _loading = loading;
    }
  }

  /// The stored rule has filled the form, or could not be read.
  bool get _settled => _original != null || _loadFailed;

  /// Fills the form from the rule's first value only: a later tick (a sync,
  /// the list's switch) never overwrites what the diver is editing.
  void _loaded(AsyncValue<Rule?> next) {
    if (_settled) return;
    switch (next) {
      case AsyncData(:final value?):
        _loading?.close();
        _loading = null;
        setState(() => _seed(value));
        // A rule this version cannot save stays read only, with no sitting.
        if (!_readOnly) openEditor();
      case AsyncData():
      case AsyncError():
        _loading?.close();
        _loading = null;
        setState(() => _loadFailed = true);
      default:
    }
  }

  @override
  void dispose() {
    disposeEditor();
    _loading?.close();
    _name.dispose();
    super.dispose();
  }

  void _seed(Rule rule) {
    _original = rule;
    _name.text = rule.name;
    _subject = rule.subject;
    _triggers = {...rule.triggers};
    _condition = rule.condition;
    _actions = [...rule.actions];
  }

  /// Applies a change to the form and hands the form to the sitting.
  void _change(VoidCallback change) {
    setState(change);
    editorChanged();
  }

  @override
  String get editorTable => 'rules';

  @override
  String? get editorStoredId => widget.ruleId;

  @override
  String? get editorLeaveLocation => '/rules';

  @override
  String editorTitle(BuildContext context) => _isNew
      ? context.l10n.rules_edit_titleNew
      : context.l10n.rules_edit_titleEdit;

  @override
  RuleDraft readEditorDraft() => RuleDraft(
    name: _name.text,
    subject: _subject,
    triggers: {..._triggers},
    condition: _condition,
    conditionValid: _conditionValid,
    replacesBrokenCondition: _storedConditionUnloaded && _conditionTouched,
    actions: [..._actions],
  );

  @override
  bool get editorCanSave =>
      _conditionValid && _name.text.trim().isNotEmpty && _actions.isNotEmpty;

  @override
  bool validateEditor() => editorCanSave;

  @override
  Future<void> writeEditor(String recordId) async {
    final repository = ref.read(ruleRepositoryProvider);
    final draft = readEditorDraft();
    if (editorCreating) {
      final diverId = editorDiverId;
      if (diverId == null) throw StateError('no active diver');
      await repository.create(
        id: recordId,
        diverId: diverId,
        subject: draft.subject,
        name: draft.name,
        triggers: draft.triggers,
        condition: draft.condition,
        actions: draft.actions,
      );
      return;
    }
    // Only what the diver changed, on the rule as stored now: a condition
    // that did not load keeps its stored form unless they edited it.
    final wrote = await repository.patch(
      recordId,
      ruleChanges(draft, editorStartDraft!),
    );
    if (!wrote) {
      throw RecordSittingRefusal((l10n) => l10n.rules_edit_notFound);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final Widget body;
    if (_loadFailed) {
      body = Center(child: Text(l10n.common_error_tryAgain));
    } else if (!_isNew && _original == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = _form(context);
    }
    return editorScaffold(context, body: body);
  }

  Widget _form(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (_readOnly || _original?.problem != null)
          _Banner(
            text:
                (_original == null
                    ? null
                    : ruleProblemText(l10n, _original!)) ??
                l10n.rules_problem_newerVersion,
          ),
        TextField(
          key: const ValueKey('rule_name'),
          controller: _name,
          enabled: !_readOnly,
          decoration: InputDecoration(labelText: l10n.rules_edit_name),
        ),
        if (_isNew) ...[
          _Heading(l10n.rules_edit_appliesTo),
          SegmentedButton<RuleSubject>(
            key: const ValueKey('rule_subject_picker'),
            segments: [
              ButtonSegment(
                value: RuleSubject.dives,
                label: Text(l10n.rules_edit_subjectDives),
                icon: const Icon(Icons.scuba_diving),
              ),
              ButtonSegment(
                value: RuleSubject.sites,
                label: Text(l10n.rules_edit_subjectSites),
                icon: const Icon(Icons.place_outlined),
              ),
            ],
            selected: {_subject},
            onSelectionChanged: (s) => _change(() {
              // A condition and actions are written for one subject. The
              // new subject's editor starts empty, so no half-typed text
              // of the old one holds Save back.
              _subject = s.single;
              _condition = null;
              _conditionValid = true;
              _actions = [];
            }),
          ),
        ],
        _Heading(l10n.rules_edit_whenRuns),
        _triggerBox(RuleTrigger.afterImport, l10n.rules_trigger_afterImport),
        _triggerBox(
          RuleTrigger.afterManualCreate,
          _subject == RuleSubject.dives
              ? l10n.rules_trigger_afterManualDive
              : l10n.rules_trigger_afterManualSite,
        ),
        Text(
          l10n.rules_edit_runNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        _Heading(l10n.rules_edit_if),
        IgnorePointer(
          ignoring: _readOnly,
          child: EntityQueryEditor(
            key: ValueKey('rule_condition_${_subject.name}'),
            root: appQueryRegistry.entityFor(_subject.querySubject),
            value: _condition,
            onChanged: (n) => _change(() {
              _condition = n;
              _conditionTouched = true;
            }),
            onValidityChanged: (valid) =>
                _change(() => _conditionValid = valid),
          ),
        ),
        const SizedBox(height: 8),
        _matchCount(context),
        _Heading(l10n.rules_edit_then),
        ..._actionCards(context),
        if (_actions.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(l10n.rules_edit_noActions),
          ),
        if (!_readOnly)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('rule_add_action'),
              onPressed: _addAction,
              icon: const Icon(Icons.add),
              label: Text(l10n.rules_edit_addAction),
            ),
          ),
      ],
    );
  }

  Widget _triggerBox(RuleTrigger t, String label) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(label),
    value: _triggers.contains(t),
    onChanged: _readOnly
        ? null
        : (on) => _change(() {
            _triggers = on == true
                ? {..._triggers, t}
                : ({..._triggers}..remove(t));
          }),
  );

  /// Whether the condition reads the computed deco verdicts. The diver only
  /// narrows what a compiled query binds, not which tables it reads.
  bool _readsDeco() {
    try {
      return ref
          .read(ruleTargetScopeProvider)
          .reads(_condition, _subject, '', kDiveDecoStatusTable);
    } on Object {
      // A half-typed condition the compiler rejects reads nothing yet.
      return false;
    }
  }

  Widget _matchCount(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    final count = ref
        .watch(
          ruleMatchCountProvider((
            subject: _subject,
            conditionJson: encodeRuleCondition(_condition),
          )),
        )
        .value;
    // A count over deco waits for the dive analysis, which on a library
    // nothing has analyzed runs for minutes: say how far it has got (#4461).
    final analysis = count == null && _readsDeco()
        ? ref.watch(diveDecoStatusProgressProvider)
        : null;
    final dives = _subject == RuleSubject.dives;
    final unloaded = _original?.problem != null && !_conditionTouched;
    final text = unloaded
        ? ''
        : _condition == null
        ? (dives
              ? l10n.rules_edit_matchesEveryDive
              : l10n.rules_edit_matchesEverySite)
        : analysis != null
        ? l10n.insights_profile_deco_analyzing(
            analysis.analyzed,
            analysis.total,
          )
        : count == null
        ? ''
        : dives
        ? l10n.rules_edit_matchCountDives(count)
        : l10n.rules_edit_matchCountSites(count);
    return Text(text, style: style);
  }

  List<Widget> _actionCards(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);
    final nameOf = ref.watch(ruleNameOfProvider).value;
    if (nameOf == null) return const [];
    return [
      for (var i = 0; i < _actions.length; i++)
        RuleActionCard(
          key: ValueKey('rule_action_$i'),
          action: _actions[i],
          units: units,
          nameOf: nameOf,
          onEdit: _readOnly ? null : () => _editAction(i),
          onRemove: _readOnly
              ? null
              : () => _change(() => _actions = [..._actions]..removeAt(i)),
        ),
    ];
  }

  Future<void> _addAction() async {
    final template = await showRuleActionPicker(context, _subject);
    if (template == null || !mounted) return;
    final action = await editRuleAction(context, ref, template);
    if (action == null || !mounted) return;
    _change(() => _actions = [..._actions, action]);
  }

  Future<void> _editAction(int i) async {
    final template = RuleActionTemplate.of(_actions[i]);
    if (template == null) return;
    final action = await editRuleAction(
      context,
      ref,
      template,
      initial: _actions[i],
    );
    if (action == null || !mounted) return;
    _change(() => _actions = [..._actions]..[i] = action);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}
