import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/currency.dart';
import 'package:submersion/core/utils/currency_catalog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What a currency picker returned: [code] is null when the diver chose the
/// inherit entry.
class CurrencyChoice {
  const CurrencyChoice(this.code);

  final String? code;
}

/// Opens a searchable picker over every ISO 4217 currency (issue #4997).
///
/// With no search, the diver's [preferred] currencies come first (and
/// [current], when it is outside them), then the rest of the catalog. A
/// search matches codes and English names across all of them. When
/// [inheritLabel] is given, an entry with that label leads the list and picks
/// null. Returns null when the picker is dismissed.
Future<CurrencyChoice?> showCurrencyPicker(
  BuildContext context, {
  required String title,
  required String? current,
  required List<String> preferred,
  String? inheritLabel,
}) => showDialog<CurrencyChoice>(
  context: context,
  builder: (_) => _CurrencyPickerDialog(
    title: title,
    current: current,
    preferred: preferred,
    inheritLabel: inheritLabel,
  ),
);

/// A form field showing a currency code that opens [showCurrencyPicker] when
/// tapped.
///
/// A null [value] shows [inheritLabel], which also adds the inherit entry to
/// the picker.
class CurrencyPickerField extends ConsumerWidget {
  const CurrencyPickerField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.inheritLabel,
  });

  final String? value;
  final String label;
  final ValueChanged<String?> onChanged;
  final String? inheritLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = value?.trim().toUpperCase();
    final shown = (code == null || code.isEmpty) ? inheritLabel : code;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: () async {
          final choice = await showCurrencyPicker(
            context,
            title: label,
            current: code,
            preferred: ref.read(preferredCurrencyCodesProvider),
            inheritLabel: inheritLabel,
          );
          if (choice != null) onChanged(choice.code);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          isEmpty: shown == null,
          child: Text(
            shown ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// One row of the picker's list: a section header or a currency.
sealed class _Row {
  const _Row();
}

class _HeaderRow extends _Row {
  const _HeaderRow(this.text);

  final String text;
}

class _CodeRow extends _Row {
  const _CodeRow(this.code);

  final String code;
}

class _InheritRow extends _Row {
  const _InheritRow();
}

class _CurrencyPickerDialog extends StatefulWidget {
  const _CurrencyPickerDialog({
    required this.title,
    required this.current,
    required this.preferred,
    required this.inheritLabel,
  });

  final String title;
  final String? current;
  final List<String> preferred;
  final String? inheritLabel;

  @override
  State<_CurrencyPickerDialog> createState() => _CurrencyPickerDialogState();
}

class _CurrencyPickerDialogState extends State<_CurrencyPickerDialog> {
  String _query = '';

  List<_Row> _rows(BuildContext context) {
    final l10n = context.l10n;
    final leading = currencyCodesWith(
      widget.current,
      preferred: widget.preferred,
    );
    final all = allCurrencyCodesWith(
      widget.current,
      preferred: widget.preferred,
    );
    if (_query.trim().isNotEmpty) {
      return [
        for (final code in all)
          if (currencyMatchesQuery(code, _query)) _CodeRow(code),
      ];
    }
    return [
      if (widget.inheritLabel != null) const _InheritRow(),
      if (leading.isNotEmpty) ...[
        _HeaderRow(l10n.currencyPicker_section_preferred),
        for (final code in leading) _CodeRow(code),
      ],
      _HeaderRow(l10n.currencyPicker_section_all),
      for (final code in all.skip(leading.length)) _CodeRow(code),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final rows = _rows(context);
    final current = widget.current?.trim().toUpperCase();
    final height = math.min(MediaQuery.sizeOf(context).height * 0.6, 520.0);

    Widget? check(bool selected) =>
        selected ? Icon(Icons.check, color: theme.colorScheme.primary) : null;

    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
      content: SizedBox(
        width: 480,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: const Key('currency-picker-search'),
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.currencyPicker_searchHint,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: rows.isEmpty
                  ? Center(child: Text(l10n.currencyPicker_noMatches))
                  : ListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) => switch (rows[index]) {
                        _HeaderRow(:final text) => Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                          child: Text(
                            text,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        _InheritRow() => ListTile(
                          key: const Key('currency-picker-inherit'),
                          title: Text(widget.inheritLabel!),
                          trailing: check(current == null || current.isEmpty),
                          onTap: () => Navigator.of(
                            context,
                          ).pop(const CurrencyChoice(null)),
                        ),
                        _CodeRow(:final code) => CurrencyListTile(
                          key: Key('currency-picker-$code'),
                          code: code,
                          trailing: check(code == current),
                          onTap: () =>
                              Navigator.of(context).pop(CurrencyChoice(code)),
                        ),
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
      ],
    );
  }
}

/// A currency's row in a list: its symbol, code and English name.
class CurrencyListTile extends StatelessWidget {
  const CurrencyListTile({
    super.key,
    required this.code,
    this.trailing,
    this.onTap,
  });

  final String code;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final name = isoCurrencyName(code);
    return ListTile(
      leading: CurrencySymbolBox(code: code),
      title: Text(code),
      subtitle: name == null ? null : Text(name),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

/// [code]'s symbol in a fixed-width box, so codes line up beside it.
class CurrencySymbolBox extends StatelessWidget {
  const CurrencySymbolBox({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 40,
    child: Center(
      child: Text(
        currencySymbol(code),
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
      ),
    ),
  );
}

/// Entries for an editable currency [DropdownMenu], one per code in [codes],
/// each with its symbol beside it.
List<DropdownMenuEntry<String>> currencyMenuEntries(List<String> codes) => [
  for (final code in codes)
    DropdownMenuEntry(
      value: code,
      label: code,
      leadingIcon: SizedBox(
        width: 28,
        child: Center(child: Text(currencySymbol(code))),
      ),
    ),
];

/// A [DropdownMenu.filterCallback] for [currencyMenuEntries]: typing matches
/// a code or a currency's English name, so "real" finds BRL.
List<DropdownMenuEntry<String>> filterCurrencyMenuEntries(
  List<DropdownMenuEntry<String>> entries,
  String filter,
) => [
  for (final entry in entries)
    if (currencyMatchesQuery(entry.value, filter)) entry,
];
