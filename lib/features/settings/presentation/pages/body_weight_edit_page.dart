import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Dated body-weight history for the active diver (weight prediction v104):
/// a list of measurements with add/delete.
class BodyWeightEditPage extends ConsumerWidget {
  const BodyWeightEditPage({super.key});

  /// A dialog field's number once its form has validated: blank is "not
  /// entered", and unreadable text cannot reach here.
  static double? _validatedNumber(TextEditingController controller) =>
      switch (readNumber(controller.text)) {
        NumberValue(:final value) => value,
        NumberBlank() => null,
        NumberInvalid() => null, // unreachable: validate() ran first
      };

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final units = UnitFormatter(ref.read(settingsProvider));
    final weightController = TextEditingController();
    final heightCmController = TextEditingController();
    final heightFeetController = TextEditingController();
    final heightInchesController = TextEditingController();
    var measuredAt = DateTime.now();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(dialogContext.l10n.bodyWeight_addEntry),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: weightController,
                  inputFormatters: numberInputFormatters(),
                  validator: numberValidator(dialogContext),
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: dialogContext.l10n.bodyWeight_weightLabel(
                      units.weightSymbol,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                if (units.heightIsMetric)
                  TextFormField(
                    controller: heightCmController,
                    inputFormatters: numberInputFormatters(),
                    validator: numberValidator(dialogContext),
                    decoration: InputDecoration(
                      labelText: dialogContext.l10n.bodyWeight_heightLabel,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: heightFeetController,
                          inputFormatters: numberInputFormatters(),
                          validator: numberValidator(
                            dialogContext,
                            integer: true,
                          ),
                          decoration: InputDecoration(
                            labelText:
                                dialogContext.l10n.bodyWeight_heightFeetLabel,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: heightInchesController,
                          inputFormatters: numberInputFormatters(),
                          validator: numberValidator(dialogContext),
                          decoration: InputDecoration(
                            labelText:
                                dialogContext.l10n.bodyWeight_heightInchesLabel,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${dialogContext.l10n.bodyWeight_dateLabel}: '
                        '${units.formatDate(measuredAt)}',
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: () async {
                        final picked = await showAppDatePicker(
                          context: dialogContext,
                          initialDate: measuredAt,
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => measuredAt = picked);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () {
                // An unreadable number used to close the dialog having saved
                // nothing, or saved no height (#1900).
                if (!formKey.currentState!.validate()) return;
                Navigator.of(dialogContext).pop(true);
              },
              child: Text(dialogContext.l10n.common_action_save),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    // Blank closes having saved nothing, as before; the dialog's validators
    // already stopped unreadable text.
    final parsedWeight = _validatedNumber(weightController);
    if (parsedWeight == null) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;

    final double? heightCm;
    if (units.heightIsMetric) {
      heightCm = _validatedNumber(heightCmController);
    } else {
      final feet = _validatedNumber(heightFeetController);
      final inches = _validatedNumber(heightInchesController);
      heightCm = (feet == null && inches == null)
          ? null
          : units.feetInchesToCm(feet ?? 0, inches ?? 0);
    }

    await ref
        .read(diverWeightEntryRepositoryProvider)
        .createEntry(
          DiverWeightEntry(
            id: '',
            diverId: diverId,
            measuredAt: measuredAt,
            weightKg: units.weightToKg(parsedWeight),
            heightCm: heightCm,
            createdAt: measuredAt,
            updatedAt: measuredAt,
          ),
        );
    ref.invalidate(diverWeightEntriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(diverWeightEntriesProvider);
    final units = UnitFormatter(ref.watch(settingsProvider));

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.diverProfile_bodyWeight_title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDialog(context, ref),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.bodyWeight_addEntry),
      ),
      body: entriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (entries) {
          if (entries.isEmpty) {
            return Center(
              child: Text(context.l10n.diverProfile_bodyWeight_empty),
            );
          }
          return ListView.separated(
            itemCount: entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return ListTile(
                leading: const Icon(Icons.monitor_weight),
                title: Text(units.formatWeight(entry.weightKg)),
                subtitle: Text(
                  entry.heightCm != null
                      ? '${units.formatDate(entry.measuredAt)} · '
                            '${units.formatHeight(entry.heightCm)}'
                      : units.formatDate(entry.measuredAt),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: context.l10n.bodyWeight_deleteTooltip,
                  onPressed: () async {
                    await ref
                        .read(diverWeightEntryRepositoryProvider)
                        .deleteEntry(entry.id);
                    ref.invalidate(diverWeightEntriesProvider);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
