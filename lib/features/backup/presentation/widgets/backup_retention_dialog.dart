import 'package:flutter/material.dart';

import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// The counts offered as a single tap; any other count is typed.
const backupRetentionChoices = [5, 10, 15, 20, 30];

/// What a row of the picker stands for: a count, or "type one".
sealed class _Pick {
  const _Pick();
}

class _Count extends _Pick {
  const _Count(this.count);

  final int count;
}

class _Custom extends _Pick {
  const _Custom();
}

/// Asks how many backups to keep (issue #4535): the usual counts, Keep all
/// ([BackupSettings.keepAllRetentionCount]), or a typed count from 1 to
/// [BackupSettings.maxCustomRetentionCount]. Null when the diver backs out,
/// from either dialog.
Future<int?> showBackupRetentionDialog(
  BuildContext context, {
  required int selected,
}) async {
  final keepsAll = BackupSettings(retentionCount: selected).keepsAll;
  final custom = !keepsAll && !backupRetentionChoices.contains(selected);
  final pick = await showDialog<_Pick>(
    context: context,
    builder: (context) {
      final l10n = context.l10n;
      return SimpleDialog(
        title: Text(l10n.backup_schedule_retention),
        children: [
          for (final n in backupRetentionChoices)
            _row(context, '$n', n == selected, _Count(n)),
          _row(
            context,
            l10n.backup_retention_keepAll,
            keepsAll,
            const _Count(BackupSettings.keepAllRetentionCount),
          ),
          _row(
            context,
            custom
                ? l10n.backup_retention_customCurrent(selected)
                : l10n.backup_retention_custom,
            custom,
            const _Custom(),
          ),
        ],
      );
    },
  );
  switch (pick) {
    case null:
      return null;
    case _Count(:final count):
      return count;
    case _Custom():
      if (!context.mounted) return null;
      return showDialog<int>(
        context: context,
        builder: (_) =>
            _CustomRetentionDialog(initial: keepsAll ? null : selected),
      );
  }
}

Widget _row(BuildContext context, String label, bool selected, _Pick pick) =>
    ListTile(
      title: Text(label),
      selected: selected,
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(pick),
    );

/// A number field for the count, with Save enabled only for 1 to
/// [BackupSettings.maxCustomRetentionCount].
class _CustomRetentionDialog extends StatefulWidget {
  const _CustomRetentionDialog({required this.initial});

  /// The count the field starts with; null starts it empty.
  final int? initial;

  @override
  State<_CustomRetentionDialog> createState() => _CustomRetentionDialogState();
}

class _CustomRetentionDialogState extends State<_CustomRetentionDialog> {
  late final _controller = TextEditingController(
    text: widget.initial?.toString() ?? '',
  );

  /// Whether the diver has changed the field: an untouched empty field is
  /// not yet an error.
  var _edited = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The typed count, or null when it is blank, unreadable, fractional or
  /// out of range.
  int? get _value => switch (readNumber(
    _controller.text,
    integer: true,
    allowNegative: false,
  )) {
    NumberValue(:final value)
        when value >= 1 && value <= BackupSettings.maxCustomRetentionCount =>
      value.toInt(),
    _ => null,
  };

  void _save() {
    final n = _value;
    if (n != null) Navigator.of(context).pop(n);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = _value;
    return AlertDialog(
      title: Text(l10n.backup_retention_custom_title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: numberInputFormatters(),
        decoration: InputDecoration(
          labelText: l10n.backup_retention_custom_label,
          errorText: _edited && value == null
              ? l10n.backup_retention_custom_error(
                  BackupSettings.maxCustomRetentionCount,
                )
              : null,
        ),
        onChanged: (_) => setState(() => _edited = true),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: value == null ? null : _save,
          child: Text(l10n.common_action_save),
        ),
      ],
    );
  }
}
