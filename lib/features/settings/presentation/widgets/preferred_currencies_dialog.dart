import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/currency_picker.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver choose the currencies every currency picker lists first
/// (issue #4997), from the whole ISO 4217 catalog.
Future<void> showPreferredCurrenciesDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final chosen = await showDialog<List<String>>(
    context: context,
    builder: (_) => PreferredCurrenciesDialog(
      initial: ref.read(preferredCurrencyCodesProvider),
    ),
  );
  if (chosen == null) return;
  await ref.read(settingsProvider.notifier).setPreferredCurrencyCodes(chosen);
}

/// The checklist behind [showPreferredCurrenciesDialog]. Pops the chosen
/// codes in order, or null when cancelled.
///
/// The list keeps the order it opened with, so a row the diver ticks or
/// unticks stays under their finger; a newly ticked code joins the end of
/// the preferred list.
class PreferredCurrenciesDialog extends StatefulWidget {
  const PreferredCurrenciesDialog({super.key, required this.initial});

  final List<String> initial;

  @override
  State<PreferredCurrenciesDialog> createState() =>
      _PreferredCurrenciesDialogState();
}

class _PreferredCurrenciesDialogState extends State<PreferredCurrenciesDialog> {
  late List<String> _chosen = [...widget.initial];
  late final List<String> _order = allCurrencyCodesWith(
    null,
    preferred: widget.initial,
  );
  String _query = '';

  void _toggle(String code, bool on) => setState(() {
    _chosen = on
        ? [..._chosen, code]
        : [
            for (final c in _chosen)
              if (c != code) c,
          ];
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final codes = [
      for (final code in _order)
        if (currencyMatchesQuery(code, _query)) code,
    ];
    final height = math.min(MediaQuery.sizeOf(context).height * 0.6, 520.0);

    return AlertDialog(
      // Reset sits beside the title rather than among the actions: three
      // action buttons stack vertically on a phone.
      title: Row(
        children: [
          Expanded(child: Text(l10n.settings_units_preferredCurrencies)),
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: l10n.settings_units_preferredCurrencies_reset,
            onPressed: () =>
                setState(() => _chosen = [...kDefaultPreferredCurrencyCodes]),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 480,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('preferred-currencies-search'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.currencyPicker_searchHint,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: codes.isEmpty
                  ? Center(child: Text(l10n.currencyPicker_noMatches))
                  : ListView.builder(
                      itemCount: codes.length,
                      itemBuilder: (context, index) {
                        final code = codes[index];
                        final on = _chosen.contains(code);
                        return CurrencyListTile(
                          key: Key('preferred-currency-$code'),
                          code: code,
                          trailing: Checkbox(
                            value: on,
                            onChanged: (value) => _toggle(code, value ?? false),
                          ),
                          onTap: () => _toggle(code, !on),
                        );
                      },
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
        TextButton(
          onPressed: () => Navigator.of(context).pop(_chosen),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
