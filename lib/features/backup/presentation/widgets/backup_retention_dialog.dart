import 'package:flutter/material.dart';

import 'package:submersion/features/backup/domain/entities/backup_settings.dart';
import 'package:submersion/features/backup/presentation/widgets/backup_choice_dialog.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// The counts offered as a single tap; any other count is typed.
const backupRetentionChoices = [5, 10, 15, 20, 30];

/// What a row of the picker stands for: a count, or null for "type one". A
/// record, so it compares by value and the shared choice dialog can check
/// the current row, while still telling a pick apart from backing out.
typedef _Pick = ({int? count});

const _Pick _custom = (count: null);
const _Pick _keepAll = (count: BackupSettings.keepAllRetentionCount);

/// Asks how many backups to keep (issue #4535): the usual counts, Keep all
/// ([BackupSettings.keepAllRetentionCount]), or a typed count from 1 to
/// [BackupSettings.maxCustomRetentionCount]. Null when the diver backs out,
/// from either dialog.
Future<int?> showBackupRetentionDialog(
  BuildContext context, {
  required int selected,
}) async {
  final l10n = context.l10n;
  final keepsAll = BackupSettings.countKeepsAll(selected);
  final custom = !keepsAll && !backupRetentionChoices.contains(selected);
  final pick = await showBackupChoiceDialog<_Pick>(
    context,
    title: l10n.backup_schedule_retention,
    values: [
      for (final n in backupRetentionChoices) (count: n),
      _keepAll,
      _custom,
    ],
    selected: keepsAll
        ? _keepAll
        : custom
        ? _custom
        : (count: selected),
    label: (pick) => switch (pick.count) {
      BackupSettings.keepAllRetentionCount => l10n.backup_retention_keepAll,
      final int count => '$count',
      null when custom => l10n.backup_retention_customCurrent(selected),
      null => l10n.backup_retention_custom,
    },
  );
  if (pick == null) return null;
  if (pick.count case final count?) return count;
  if (!context.mounted) return null;
  return showDialog<int>(
    context: context,
    builder: (_) => _CustomRetentionDialog(initial: keepsAll ? null : selected),
  );
}

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
  /// Starts with the current count selected, so typing replaces it.
  late final _controller = () {
    final text = widget.initial?.toString() ?? '';
    return TextEditingController.fromValue(
      TextEditingValue(
        text: text,
        selection: TextSelection(baseOffset: 0, extentOffset: text.length),
      ),
    );
  }();

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
