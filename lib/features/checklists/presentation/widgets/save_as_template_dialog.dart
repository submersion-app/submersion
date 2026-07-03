import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Prompts for a name and snapshots the trip's checklist as a template.
Future<void> showSaveAsTemplateDialog({
  required BuildContext context,
  required Trip trip,
}) {
  return showDialog<void>(
    context: context,
    // Not barrier-dismissible: _save() runs async work and then pops/shows a
    // SnackBar; a tap-outside dismiss mid-save would leave it popping a
    // disposed route. Dismissal is only via the explicit Cancel/Save buttons.
    barrierDismissible: false,
    builder: (context) => _SaveAsTemplateDialog(trip: trip),
  );
}

class _SaveAsTemplateDialog extends ConsumerStatefulWidget {
  final Trip trip;

  const _SaveAsTemplateDialog({required this.trip});

  @override
  ConsumerState<_SaveAsTemplateDialog> createState() =>
      _SaveAsTemplateDialogState();
}

class _SaveAsTemplateDialogState extends ConsumerState<_SaveAsTemplateDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repository = ref.read(tripChecklistRepositoryProvider);
    try {
      await repository.saveAsTemplate(
        tripId: widget.trip.id,
        tripStartDate: widget.trip.startDate,
        name: _controller.text.trim(),
        diverId: widget.trip.diverId,
      );
      // Resolve navigator/messenger after the await and guard with mounted, so
      // a teardown during the save can never pop a disposed route.
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      final l10n = context.l10n;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.checklists_saveTemplate_success),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    } catch (_) {
      // Surface the failure but keep the dialog open so the user can retry or
      // cancel; the finally re-enables the buttons.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.common_error_tryAgain),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.checklists_saveTemplate_title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.checklists_saveTemplate_nameLabel,
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? context.l10n.checklists_template_nameRequired
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
