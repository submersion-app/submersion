import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/certifications/domain/entities/currency_rule.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_type_multi_select_field.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Which dives count for one card's activity rule. Both null means "use the
/// rule's own mapping"; an empty list is the diver saying any dive counts.
typedef CurrencyMapping = ({List<String>? types, List<DiveMode>? modes});

/// Asks which dive types and modes count (issue #2267); null when
/// cancelled. Starts from the card's override, else the rule's mapping.
Future<CurrencyMapping?> showCurrencyMappingDialog(
  BuildContext context, {
  required CurrencyRule rule,
  List<String>? types,
  List<DiveMode>? modes,
}) => showDialog<CurrencyMapping>(
  context: context,
  builder: (_) => _CurrencyMappingDialog(
    initialTypes: types ?? rule.countedDiveTypeIds,
    initialModes: modes ?? rule.countedDiveModes,
    ruleTypes: rule.countedDiveTypeIds,
  ),
);

class _CurrencyMappingDialog extends StatefulWidget {
  final List<String> initialTypes;
  final List<DiveMode> initialModes;

  /// The rule's own mapping, offered even when hidden from the pickers.
  final List<String> ruleTypes;

  const _CurrencyMappingDialog({
    required this.initialTypes,
    required this.initialModes,
    required this.ruleTypes,
  });

  @override
  State<_CurrencyMappingDialog> createState() => _CurrencyMappingDialogState();
}

class _CurrencyMappingDialogState extends State<_CurrencyMappingDialog> {
  late List<String> _types = [...widget.initialTypes];
  late Set<DiveMode> _modes = {...widget.initialModes};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.certifications_currency_mappingDialog_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DiveTypeMultiSelectField(
              selectedTypeIds: _types,
              allowEmpty: true,
              // A type hidden from the pickers (issue #401) stays offered
              // when the rule counts it or the card did on opening, so the
              // diver can always tick it back.
              keepTypeIds: [...widget.ruleTypes, ...widget.initialTypes],
              labelText: l10n.certifications_currency_mappingDialog_types,
              onChanged: (ids) => setState(() => _types = ids),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.certifications_currency_mappingDialog_modes,
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 12),
            Text(
              l10n.certifications_currency_mappingDialog_anyHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop((types: null, modes: null)),
          child: Text(l10n.certifications_currency_mappingDialog_reset),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop((
            types: [..._types],
            modes: [
              for (final m in DiveMode.values)
                if (_modes.contains(m)) m,
            ],
          )),
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
