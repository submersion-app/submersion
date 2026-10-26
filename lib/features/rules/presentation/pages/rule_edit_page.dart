import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/presentation/entity_query_editor.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/providers/rule_providers.dart';
import 'package:submersion/features/rules/presentation/rule_labels.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_action_card.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_action_editor.dart';
import 'package:submersion/features/rules/presentation/widgets/rule_action_picker_sheet.dart';
import 'package:submersion/features/rules/presentation/widgets/rules_page_menus.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

final _log = LoggerService.forClass(RuleEditPage);

/// Creates or edits one logbook rule (#3513): its name, what it applies to
/// (new rules only), when it runs, its condition in the query editor with
/// a live match count, and its actions. A rule a newer version saved opens
/// read-only.
class RuleEditPage extends ConsumerStatefulWidget {
  const RuleEditPage({super.key, this.ruleId});

  /// Null for a new rule.
  final String? ruleId;

  @override
  ConsumerState<RuleEditPage> createState() => _RuleEditPageState();
}

class _RuleEditPageState extends ConsumerState<RuleEditPage> {
  final _name = TextEditingController();
  Rule? _original;
  bool _seeded = false;
  bool _saving = false;
  RuleSubject _subject = RuleSubject.dives;
  Set<RuleTrigger> _triggers = {RuleTrigger.afterImport};
  QueryNode? _condition;

  /// Whether the diver edited the condition. A rule whose stored condition
  /// did not load keeps that JSON on save unless they did.
  bool _conditionTouched = false;

  /// False while the condition's text does not parse: the editor then
  /// still holds the last tree that did, which is not what the diver sees,
  /// so Save waits.
  bool _conditionValid = true;
  List<RuleAction> _actions = [];

  bool get _isNew => widget.ruleId == null;

  bool get _readOnly =>
      _original?.problem == RuleLoadProblem.newerVersion ||
      _actions.any((a) => a is UnknownRuleAction);

  bool get _canSave =>
      !_saving &&
      !_readOnly &&
      _conditionValid &&
      _name.text.trim().isNotEmpty &&
      _actions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _seed(Rule rule) {
    _seeded = true;
    _original = rule;
    _name.text = rule.name;
    _subject = rule.subject;
    _triggers = {...rule.triggers};
    _condition = rule.condition;
    _actions = [...rule.actions];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (!_isNew && !_seeded) {
      final loaded = ref.watch(ruleByIdProvider(widget.ruleId!));
      switch (loaded) {
        case AsyncData(:final value?):
          _seed(value);
        case AsyncData():
        case AsyncError():
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(l10n.common_error_tryAgain)),
          );
        default:
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isNew ? l10n.rules_edit_titleNew : l10n.rules_edit_titleEdit,
        ),
        actions: [
          if (!_readOnly)
            AppBarTextAction(
              key: const ValueKey('rule_save'),
              label: l10n.common_action_save,
              onPressed: _canSave ? _save : null,
            ),
        ],
      ),
      body: ListView(
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
              onSelectionChanged: (s) => setState(() {
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
              onChanged: (n) => setState(() {
                _condition = n;
                _conditionTouched = true;
              }),
              onValidityChanged: (valid) =>
                  setState(() => _conditionValid = valid),
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
      ),
    );
  }

  Widget _triggerBox(RuleTrigger t, String label) => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: Text(label),
    value: _triggers.contains(t),
    onChanged: _readOnly
        ? null
        : (on) => setState(() {
            _triggers = on == true
                ? {..._triggers, t}
                : ({..._triggers}..remove(t));
          }),
  );

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
    final dives = _subject == RuleSubject.dives;
    final unloaded = _original?.problem != null && !_conditionTouched;
    final text = unloaded
        ? ''
        : _condition == null
        ? (dives
              ? l10n.rules_edit_matchesEveryDive
              : l10n.rules_edit_matchesEverySite)
        : count == null
        ? ''
        : dives
        ? l10n.rules_edit_matchCountDives(count)
        : l10n.rules_edit_matchCountSites(count);
    return Text(text, style: style);
  }

  List<Widget> _actionCards(BuildContext context) {
    final units = UnitFormatter(ref.watch(settingsProvider));
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
              : () => setState(() => _actions = [..._actions]..removeAt(i)),
        ),
    ];
  }

  Future<void> _addAction() async {
    final template = await showRuleActionPicker(context, _subject);
    if (template == null || !mounted) return;
    final action = await editRuleAction(context, ref, template);
    if (action == null || !mounted) return;
    setState(() => _actions = [..._actions, action]);
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
    setState(() => _actions = [..._actions]..[i] = action);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final repository = ref.read(ruleRepositoryProvider);
    try {
      if (_original == null) {
        final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
        if (diverId == null) throw StateError('no active diver');
        await repository.create(
          diverId: diverId,
          subject: _subject,
          name: _name.text,
          triggers: _triggers,
          condition: _condition,
          actions: _actions,
        );
      } else {
        await repository.update(
          _original!.copyWith(
            name: _name.text,
            triggers: _triggers,
            condition: _condition,
            clearCondition: _condition == null,
            actions: _actions,
            // A condition that did not load is kept as stored unless the
            // diver edited it; what they edited is saved as shown.
            clearProblem: _conditionTouched || _original!.problem == null,
          ),
        );
      }
      if (mounted) context.pop();
    } catch (e, st) {
      _log.error('Failed to save rule', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _saving = false);
        showRulesError(context);
      }
    }
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
