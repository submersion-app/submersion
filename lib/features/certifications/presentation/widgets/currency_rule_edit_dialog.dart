import 'package:flutter/material.dart';

import 'package:submersion/core/constants/certification_levels.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/presentation/certification_agency_display.dart';
import 'package:submersion/features/certifications/presentation/certification_level_display.dart';
import 'package:submersion/features/certifications/presentation/currency_rule_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Creates or edits a currency rule (issue #2267); null when cancelled.
///
/// With no [editing] rule it creates one. With a custom rule it edits that
/// rule. With a BUILT-IN rule it is copy-on-write: built-in rows never sync,
/// so the result is a new custom rule, prefilled from the built-in, whose
/// `supersedesRuleId` names it. The returned rule's id is empty for a new
/// rule or a copy, and the caller's for an edit.
Future<CurrencyRule?> showCurrencyRuleEditDialog(
  BuildContext context, {
  CurrencyRule? editing,
  required String? diverId,
}) => showDialog<CurrencyRule>(
  context: context,
  builder: (_) => _CurrencyRuleEditDialog(editing: editing, diverId: diverId),
);

class _CurrencyRuleEditDialog extends StatefulWidget {
  final CurrencyRule? editing;
  final String? diverId;

  const _CurrencyRuleEditDialog({this.editing, this.diverId});

  @override
  State<_CurrencyRuleEditDialog> createState() =>
      _CurrencyRuleEditDialogState();
}

class _CurrencyRuleEditDialogState extends State<_CurrencyRuleEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _lapse;
  late final TextEditingController _lead;
  late final TextEditingController _note;
  late CurrencyClockKind _clock;
  late Set<CertificationAgency> _agencies;
  late Set<CertificationLevel> _levels;
  late List<String> _types;
  late Set<DiveMode> _modes;
  bool _initialized = false;

  bool get _copying => widget.editing?.isBuiltIn ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final rule = widget.editing;
    final l10n = context.l10n;
    _name = TextEditingController(
      text: rule == null ? '' : currencyRuleName(l10n, rule),
    );
    _lapse = TextEditingController(text: rule?.lapseDays.toString() ?? '');
    _lead = TextEditingController(text: rule?.leadDays.toString() ?? '');
    _note = TextEditingController(
      text: rule == null ? '' : currencyRuleAdvisory(l10n, rule) ?? '',
    );
    _clock = rule?.clockKind ?? CurrencyClockKind.activity;
    _agencies = {...?rule?.agencies};
    _levels = {...?rule?.levels};
    _types = [...?rule?.countedDiveTypeIds];
    _modes = {...?rule?.countedDiveModes};
  }

  @override
  void dispose() {
    _name.dispose();
    _lapse.dispose();
    _lead.dispose();
    _note.dispose();
    super.dispose();
  }

  int? _read(TextEditingController c) =>
      switch (readNumber(c.text, integer: true, allowNegative: false)) {
        NumberValue(:final value) => value.round(),
        _ => null,
      };

  /// The levels offered: the selected agencies' ladders and specialties, or
  /// every agency's when none is selected, plus anything already selected.
  List<CertificationLevel> _levelChoices() {
    final agencies = _agencies.isEmpty
        ? CertificationAgency.values
        : CertificationAgency.values.where(_agencies.contains);
    final offered = <CertificationLevel>{
      for (final a in agencies) ...CertificationLevelCatalog.ladderFor(a),
      for (final a in agencies) ...CertificationLevelCatalog.specialtiesFor(a),
      ..._levels,
    };
    return [
      for (final l in CertificationLevel.values)
        if (offered.contains(l)) l,
    ];
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final now = DateTime.now();
    final base = widget.editing;
    final note = _note.text.trim();
    final activity = _clock == CurrencyClockKind.activity;
    Navigator.of(context).pop(
      CurrencyRule(
        id: base == null || _copying ? '' : base.id,
        diverId: base == null || _copying ? widget.diverId : base.diverId,
        name: _name.text.trim(),
        clockKind: _clock,
        agencies: [
          for (final a in CertificationAgency.values)
            if (_agencies.contains(a)) a,
        ],
        levels: [
          for (final l in CertificationLevel.values)
            if (_levels.contains(l)) l,
        ],
        lapseDays: _read(_lapse)!,
        leadDays: _read(_lead)!,
        countedDiveTypeIds: activity ? [..._types] : const [],
        countedDiveModes: activity
            ? [
                for (final m in DiveMode.values)
                  if (_modes.contains(m)) m,
              ]
            : const [],
        advisoryText: note.isEmpty ? null : note,
        supersedesRuleId: _copying ? base!.id : base?.supersedesRuleId,
        createdAt: base?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final hint = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return AlertDialog(
      title: Text(
        widget.editing == null
            ? l10n.currencyRules_dialog_addTitle
            : l10n.currencyRules_dialog_editTitle,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_copying)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      l10n.currencyRules_dialog_copyNote,
                      style: hint,
                    ),
                  ),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: l10n.currencyRules_dialog_name,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? l10n.currencyRules_dialog_nameRequired
                      : null,
                ),
                _label(context, l10n.currencyRules_dialog_clock),
                SegmentedButton<CurrencyClockKind>(
                  segments: [
                    ButtonSegment(
                      value: CurrencyClockKind.activity,
                      label: Text(l10n.currencyRules_dialog_clock_activity),
                    ),
                    ButtonSegment(
                      value: CurrencyClockKind.date,
                      label: Text(l10n.currencyRules_dialog_clock_date),
                    ),
                  ],
                  selected: {_clock},
                  onSelectionChanged: (s) => setState(() => _clock = s.first),
                ),
                _label(context, l10n.currencyRules_dialog_agencies),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final a in CertificationAgency.values)
                      FilterChip(
                        label: Text(a.localizedName(l10n)),
                        selected: _agencies.contains(a),
                        onSelected: (on) => setState(
                          () => _agencies = on
                              ? {..._agencies, a}
                              : ({..._agencies}..remove(a)),
                        ),
                      ),
                  ],
                ),
                _label(context, l10n.currencyRules_dialog_levels),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final level in _levelChoices())
                      FilterChip(
                        label: Text(level.localizedName(l10n)),
                        selected: _levels.contains(level),
                        onSelected: (on) => setState(
                          () => _levels = on
                              ? {..._levels, level}
                              : ({..._levels}..remove(level)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l10n.currencyRules_dialog_anyHint, style: hint),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lapse,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        l10n.certifications_currency_intervalDialog_lapse,
                  ),
                  validator: numberValidator(
                    context,
                    integer: true,
                    required: true,
                    allowNegative: false,
                    check: (v) =>
                        v < 1 ? l10n.numberInput_invalidWholeNumber : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lead,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.certifications_currency_intervalDialog_lead,
                  ),
                  validator: numberValidator(
                    context,
                    integer: true,
                    required: true,
                    allowNegative: false,
                    check: (v) {
                      final lapse = _read(_lapse);
                      return lapse != null && v > lapse
                          ? l10n.certifications_currency_intervalDialog_leadTooLong
                          : null;
                    },
                  ),
                ),
                if (_clock == CurrencyClockKind.activity) ...[
                  const SizedBox(height: 16),
                  DiveTypeMultiSelectField(
                    selectedTypeIds: _types,
                    allowEmpty: true,
                    // A type hidden from the pickers (issue #401) that the
                    // rule counted on opening stays offered once unticked.
                    keepTypeIds: [...?widget.editing?.countedDiveTypeIds],
                    labelText: l10n.certifications_currency_mappingDialog_types,
                    onChanged: (ids) => setState(() => _types = ids),
                  ),
                  _label(
                    context,
                    l10n.certifications_currency_mappingDialog_modes,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final mode in DiveMode.values)
                        FilterChip(
                          label: Text(mode.localizedName(l10n)),
                          selected: _modes.contains(mode),
                          onSelected: (on) => setState(
                            () => _modes = on
                                ? {..._modes, mode}
                                : ({..._modes}..remove(mode)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.certifications_currency_mappingDialog_anyHint,
                    style: hint,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _note,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.currencyRules_dialog_note,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l10n.common_action_save)),
      ],
    );
  }
}
