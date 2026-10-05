import 'package:flutter/material.dart';

import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/certifications/domain/services/certification_currency_engine.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// A per card interval override; a null field inherits the rule's value.
typedef CurrencyIntervalOverride = ({int? lapse, int? lead});

/// Asks for a lapse and lead override (issue #2267); null when cancelled.
/// Blank fields inherit the rule's own value.
Future<CurrencyIntervalOverride?> showCurrencyIntervalDialog(
  BuildContext context, {
  required CurrencyRule rule,
  int? lapseOverride,
  int? leadOverride,
}) => showDialog<CurrencyIntervalOverride>(
  context: context,
  builder: (_) => _CurrencyIntervalDialog(
    rule: rule,
    lapseOverride: lapseOverride,
    leadOverride: leadOverride,
  ),
);

class _CurrencyIntervalDialog extends StatefulWidget {
  final CurrencyRule rule;
  final int? lapseOverride;
  final int? leadOverride;

  const _CurrencyIntervalDialog({
    required this.rule,
    this.lapseOverride,
    this.leadOverride,
  });

  @override
  State<_CurrencyIntervalDialog> createState() =>
      _CurrencyIntervalDialogState();
}

class _CurrencyIntervalDialogState extends State<_CurrencyIntervalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _lapse = TextEditingController(
    text: widget.lapseOverride?.toString() ?? '',
  );
  late final _lead = TextEditingController(
    text: widget.leadOverride?.toString() ?? '',
  );

  @override
  void dispose() {
    _lapse.dispose();
    _lead.dispose();
    super.dispose();
  }

  int? _read(TextEditingController c) =>
      switch (readNumber(c.text, integer: true, allowNegative: false)) {
        NumberValue(:final value) => value.round(),
        _ => null,
      };

  /// The card-expiry status lapses on the printed date itself, so only its
  /// warning lead can be tuned.
  bool get _hasLapse => widget.rule.id != kCardExpiryRuleId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.certifications_currency_intervalDialog_title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_hasLapse) ...[
                TextFormField(
                  controller: _lapse,
                  keyboardType: TextInputType.number,
                  validator: numberValidator(
                    context,
                    integer: true,
                    allowNegative: false,
                    check: (v) {
                      if (v < 1) return l10n.numberInput_invalidWholeNumber;
                      // A blank lead inherits the rule's; a lapse shorter
                      // than that would read due soon from day one. A typed
                      // lead is checked on its own field.
                      if (_read(_lead) != null) return null;
                      return v < widget.rule.leadDays
                          ? l10n.certifications_currency_intervalDialog_leadTooLong
                          : null;
                    },
                  ),
                  decoration: InputDecoration(
                    labelText:
                        l10n.certifications_currency_intervalDialog_lapse,
                    helperText: l10n
                        .certifications_currency_intervalDialog_inheritHint(
                          '${widget.rule.lapseDays}',
                        ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _lead,
                keyboardType: TextInputType.number,
                validator: numberValidator(
                  context,
                  integer: true,
                  allowNegative: false,
                  check: (v) {
                    if (!_hasLapse) return null;
                    final lapse = _read(_lapse) ?? widget.rule.lapseDays;
                    return v > lapse
                        ? l10n.certifications_currency_intervalDialog_leadTooLong
                        : null;
                  },
                ),
                decoration: InputDecoration(
                  labelText: l10n.certifications_currency_intervalDialog_lead,
                  helperText: l10n
                      .certifications_currency_intervalDialog_inheritHint(
                        '${widget.rule.leadDays}',
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            final lapse = _hasLapse ? _read(_lapse) : null;
            final lead = _read(_lead);
            Navigator.of(context).pop((lapse: lapse, lead: lead));
          },
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
