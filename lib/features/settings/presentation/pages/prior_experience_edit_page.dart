import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edits a diver's pre-app diving experience (prior dive count, prior bottom
/// time, and the year they started diving). These totals fold into the
/// lifetime statistics alongside logged dives.
class PriorExperienceEditPage extends ConsumerStatefulWidget {
  const PriorExperienceEditPage({super.key});

  @override
  ConsumerState<PriorExperienceEditPage> createState() =>
      _PriorExperienceEditPageState();
}

class _PriorExperienceEditPageState
    extends ConsumerState<PriorExperienceEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _diveCountCtrl = TextEditingController();
  final _hoursCtrl = TextEditingController();
  final _minutesCtrl = TextEditingController();
  DateTime? _divingSince;

  bool _populated = false;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _diveCountCtrl.addListener(_onFieldChanged);
    _hoursCtrl.addListener(_onFieldChanged);
    _minutesCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _diveCountCtrl.dispose();
    _hoursCtrl.dispose();
    _minutesCtrl.dispose();
    super.dispose();
  }

  void _populateFromDiver(Diver diver) {
    if (_populated) return;
    _populated = true;
    _diveCountCtrl.text = diver.priorDiveCount?.toString() ?? '';
    final seconds = diver.priorDiveTimeSeconds;
    if (seconds != null) {
      _hoursCtrl.text = (seconds ~/ 3600).toString();
      _minutesCtrl.text = ((seconds % 3600) ~/ 60).toString();
    }
    _divingSince = diver.divingSince;
    _hasChanges = false;
  }

  Future<void> _save(Diver existingDiver) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final priorCount = int.tryParse(_diveCountCtrl.text.trim());
      final hStr = _hoursCtrl.text.trim();
      final mStr = _minutesCtrl.text.trim();
      final priorSeconds = (hStr.isEmpty && mStr.isEmpty)
          ? null
          : (int.tryParse(hStr) ?? 0) * 3600 + (int.tryParse(mStr) ?? 0) * 60;

      final updated = existingDiver.copyWith(
        priorDiveCount: priorCount,
        priorDiveTimeSeconds: priorSeconds,
        divingSince: _divingSince,
        updatedAt: DateTime.now(),
      );
      await ref.read(diverListNotifierProvider.notifier).updateDiver(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settings_profileHub_saved)),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.divers_edit_errorSaving('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _pickDivingSince() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _divingSince ?? DateTime(now.year - 10),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, 12, 31),
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _divingSince = DateTime(picked.year);
        _hasChanges = true;
      });
    }
  }

  Future<bool?> _showDiscardDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.divers_edit_discardDialogTitle),
        content: Text(context.l10n.divers_edit_discardDialogContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(context.l10n.divers_edit_keepEditingButton),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(context.l10n.divers_edit_discardButton),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final diverAsync = ref.watch(currentDiverProvider);

    return diverAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.divers_edit_priorExperienceSection),
        ),
        body: Center(child: Text('$error')),
      ),
      data: (diver) {
        if (diver == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.divers_edit_priorExperienceSection),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        _populateFromDiver(diver);
        return _buildScaffold(diver);
      },
    );
  }

  Widget _buildScaffold(Diver diver) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop && _hasChanges) {
          final shouldPop = await _showDiscardDialog();
          if (shouldPop == true && mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.divers_edit_priorExperienceSection),
          actions: [
            if (_isSaving)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              TextButton(
                onPressed: () => _save(diver),
                child: Text(context.l10n.divers_edit_saveButton),
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(key: _formKey, child: _buildFields()),
            ),
          ),
        ),
      ),
    );
  }

  String? _nonNegativeInt(String? v, {int? max}) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null || n < 0) {
      return context.l10n.divers_edit_priorInvalidNumber;
    }
    if (max != null && n > max) {
      return context.l10n.divers_edit_priorInvalidNumber;
    }
    return null;
  }

  Widget _buildFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.divers_edit_priorExperienceHelp,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _diveCountCtrl,
          decoration: InputDecoration(
            labelText: context.l10n.divers_edit_priorDivesLabel,
            prefixIcon: const Icon(Icons.waves),
          ),
          keyboardType: TextInputType.number,
          validator: (v) => _nonNegativeInt(v),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _hoursCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.divers_edit_priorHoursLabel,
                  prefixIcon: const Icon(Icons.timer),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => _nonNegativeInt(v),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _minutesCtrl,
                decoration: InputDecoration(
                  labelText: context.l10n.divers_edit_priorMinutesLabel,
                ),
                keyboardType: TextInputType.number,
                validator: (v) => _nonNegativeInt(v, max: 59),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.event),
          title: Text(context.l10n.divers_edit_divingSinceLabel),
          subtitle: Text(
            _divingSince != null
                ? '${_divingSince!.year}'
                : context.l10n.divers_edit_divingSinceNotSet,
          ),
          trailing: _divingSince != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: context.l10n.divers_edit_clearDivingSinceTooltip,
                  onPressed: () => setState(() {
                    _divingSince = null;
                    _hasChanges = true;
                  }),
                )
              : null,
          onTap: _pickDivingSince,
        ),
      ],
    );
  }
}
