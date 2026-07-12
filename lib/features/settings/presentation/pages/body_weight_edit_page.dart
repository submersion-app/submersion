import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Dated body-weight history for the active diver (weight prediction v104):
/// a list of measurements with add/delete.
class BodyWeightEditPage extends ConsumerWidget {
  const BodyWeightEditPage({super.key});

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final units = UnitFormatter(ref.read(settingsProvider));
    final weightController = TextEditingController();
    final heightCmController = TextEditingController();
    final heightFeetController = TextEditingController();
    final heightInchesController = TextEditingController();
    var measuredAt = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(dialogContext.l10n.bodyWeight_addEntry),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: weightController,
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
                TextField(
                  controller: heightCmController,
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
                      child: TextField(
                        controller: heightFeetController,
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
                      child: TextField(
                        controller: heightInchesController,
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
                      '${DateFormat.yMMMd().format(measuredAt)}',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(dialogContext.l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(dialogContext.l10n.common_action_save),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final parsedWeight = double.tryParse(weightController.text);
    if (parsedWeight == null) return;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    if (diverId == null) return;

    final double? heightCm;
    if (units.heightIsMetric) {
      heightCm = double.tryParse(heightCmController.text);
    } else {
      final feet = double.tryParse(heightFeetController.text);
      final inches = double.tryParse(heightInchesController.text);
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
                      ? '${DateFormat.yMMMd().format(entry.measuredAt)} · '
                            '${units.formatHeight(entry.heightCm)}'
                      : DateFormat.yMMMd().format(entry.measuredAt),
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
