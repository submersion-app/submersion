import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_preferences.dart';
import 'package:submersion/features/change_log/presentation/providers/change_log_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Asks, then removes the active diver's entries from this device.
Future<void> confirmClearChangeLog(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.changeLog_clear_title),
      content: Text(l.changeLog_clear_body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.common_action_cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.changeLog_clear_confirm),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return;
  await ref.read(changeLogRepositoryProvider).clearForDiver(diverId);
}

/// How long this device keeps its change log, and Clear log.
class ChangeLogSettingsPage extends ConsumerStatefulWidget {
  const ChangeLogSettingsPage({super.key});

  @override
  ConsumerState<ChangeLogSettingsPage> createState() =>
      _ChangeLogSettingsPageState();
}

class _ChangeLogSettingsPageState extends ConsumerState<ChangeLogSettingsPage> {
  late final ChangeLogPreferences _preferences = ChangeLogPreferences(
    ref.read(sharedPreferencesProvider),
  );
  late int _months = _preferences.retentionMonths;

  Future<void> _choose(int? months) async {
    if (months == null) return;
    setState(() => _months = months);
    await _preferences.setRetentionMonths(months);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.changeLog_settings_title)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              l.changeLog_retention_title,
              style: theme.textTheme.titleSmall,
            ),
          ),
          RadioGroup<int>(
            groupValue: _months,
            onChanged: _choose,
            child: Column(
              children: [
                for (final months in ChangeLogPreferences.retentionChoices)
                  RadioListTile<int>(
                    value: months,
                    title: Text(
                      months == 0
                          ? l.changeLog_retention_forever
                          : l.changeLog_retention_months(months),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              l.changeLog_retention_note,
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(l.changeLog_clear),
            onTap: () => confirmClearChangeLog(context, ref),
          ),
        ],
      ),
    );
  }
}
