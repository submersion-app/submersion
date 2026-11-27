import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/firmware/presentation/providers/firmware_recorder_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// Asks for the version a firmware update installed, its date and notes,
/// and logs it in [item]'s service history (issue #5104). [suggestedVersion]
/// prefills the version, such as the newest release the catalogue lists.
Future<void> showLogFirmwareUpdateDialog(
  BuildContext context, {
  required EquipmentItem item,
  String? suggestedVersion,
}) => showDialog<void>(
  context: context,
  builder: (_) =>
      _LogFirmwareUpdateDialog(item: item, suggestedVersion: suggestedVersion),
);

final _log = LoggerService.forClass(_LogFirmwareUpdateDialog);

class _LogFirmwareUpdateDialog extends ConsumerStatefulWidget {
  const _LogFirmwareUpdateDialog({required this.item, this.suggestedVersion});

  final EquipmentItem item;
  final String? suggestedVersion;

  @override
  ConsumerState<_LogFirmwareUpdateDialog> createState() =>
      _LogFirmwareUpdateDialogState();
}

class _LogFirmwareUpdateDialogState
    extends ConsumerState<_LogFirmwareUpdateDialog> {
  late final TextEditingController _version = TextEditingController(
    text: widget.suggestedVersion ?? '',
  );
  final TextEditingController _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _version.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final version = _version.text.trim();
    if (version.isEmpty) {
      setState(() => _error = context.l10n.firmware_log_versionRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(firmwareUpdateRecorderProvider)
          .logUpdate(
            equipmentId: widget.item.id,
            version: version,
            date: _date,
            notes: _notes.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e, stackTrace) {
      _log.error(
        'Logging a firmware update failed',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    return AlertDialog(
      title: Text(l10n.firmware_card_log),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('firmware-log-version'),
              controller: _version,
              maxLength: 60,
              autofocus: widget.suggestedVersion == null,
              decoration: InputDecoration(
                labelText: l10n.firmware_log_version,
                errorText: _error,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 8),
            InkWell(
              key: const ValueKey('firmware-log-date'),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.firmware_log_date,
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                child: Text(units.formatDate(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('firmware-log-notes'),
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.firmware_log_notes),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
