import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/currency_event.dart';
import 'package:submersion/features/certifications/presentation/currency_rule_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// What the diver logged: a refresher, renewal or revalidation (issue #2267).
typedef LoggedCurrencyEvent = ({
  CurrencyEventType type,
  DateTime date,
  String? provider,
  String notes,
});

/// Asks for a ledger entry; null when cancelled.
Future<LoggedCurrencyEvent?> showCurrencyEventDialog(
  BuildContext context, {
  required CurrencyEventType defaultType,
}) => showDialog<LoggedCurrencyEvent>(
  context: context,
  builder: (_) => _CurrencyEventDialog(defaultType: defaultType),
);

class _CurrencyEventDialog extends ConsumerStatefulWidget {
  final CurrencyEventType defaultType;

  const _CurrencyEventDialog({required this.defaultType});

  @override
  ConsumerState<_CurrencyEventDialog> createState() =>
      _CurrencyEventDialogState();
}

class _CurrencyEventDialogState extends ConsumerState<_CurrencyEventDialog> {
  late CurrencyEventType _type = widget.defaultType;
  late DateTime _date;
  final _provider = TextEditingController();
  final _notes = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _provider.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    return AlertDialog(
      title: Text(l10n.certifications_currency_eventDialog_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<CurrencyEventType>(
              initialValue: _type,
              decoration: InputDecoration(
                labelText: l10n.certifications_currency_eventDialog_type,
              ),
              items: [
                for (final t in CurrencyEventType.values)
                  DropdownMenuItem(value: t, child: Text(t.label(l10n))),
              ],
              onChanged: (t) => setState(() => _type = t ?? _type),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.certifications_currency_eventDialog_date,
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                child: Text(units.formatDate(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _provider,
              decoration: InputDecoration(
                labelText: l10n.certifications_currency_eventDialog_provider,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              minLines: 1,
              decoration: InputDecoration(
                labelText: l10n.certifications_currency_eventDialog_notes,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () {
            final provider = _provider.text.trim();
            Navigator.of(context).pop((
              type: _type,
              date: _date,
              provider: provider.isEmpty ? null : provider,
              notes: _notes.text.trim(),
            ));
          },
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
