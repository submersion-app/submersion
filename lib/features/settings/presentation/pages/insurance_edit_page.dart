import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class InsuranceEditPage extends ConsumerStatefulWidget {
  const InsuranceEditPage({super.key});

  @override
  ConsumerState<InsuranceEditPage> createState() => _InsuranceEditPageState();
}

class _InsuranceEditPageState extends ConsumerState<InsuranceEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _providerCtrl = TextEditingController();
  final _policyCtrl = TextEditingController();

  DateTime? _insuranceExpiry;
  bool _populated = false;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _providerCtrl.addListener(_onFieldChanged);
    _policyCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _providerCtrl.dispose();
    _policyCtrl.dispose();
    super.dispose();
  }

  void _populateFromDiver(Diver diver) {
    if (_populated) return;
    _populated = true;
    _providerCtrl.text = diver.insurance.provider ?? '';
    _policyCtrl.text = diver.insurance.policyNumber ?? '';
    _insuranceExpiry = diver.insurance.expiryDate;
    _hasChanges = false;
  }

  String? _trimOrNull(TextEditingController ctrl) {
    final value = ctrl.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save(Diver existingDiver) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updated = existingDiver.copyWith(
        insurance: DiverInsurance(
          provider: _trimOrNull(_providerCtrl),
          policyNumber: _trimOrNull(_policyCtrl),
          expiryDate: _insuranceExpiry,
        ),
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

  Future<void> _selectInsuranceExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _insuranceExpiry ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        _insuranceExpiry = picked;
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
        appBar: AppBar(title: Text(context.l10n.settings_profileHub_insurance)),
        body: Center(child: Text('$error')),
      ),
      data: (diver) {
        if (diver == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.settings_profileHub_insurance),
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
          title: Text(context.l10n.settings_profileHub_insurance),
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
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _providerCtrl,
                      decoration: InputDecoration(
                        labelText:
                            context.l10n.divers_edit_insuranceProviderLabel,
                        prefixIcon: const Icon(Icons.health_and_safety),
                        hintText:
                            context.l10n.divers_edit_insuranceProviderHint,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _policyCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_policyNumberLabel,
                        prefixIcon: const Icon(Icons.numbers),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInsuranceExpiryField(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInsuranceExpiryField() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.calendar_today),
      title: Text(context.l10n.divers_edit_expiryDateTitle),
      subtitle: Text(
        _insuranceExpiry != null
            ? DateFormat.yMMMd().format(_insuranceExpiry!)
            : context.l10n.divers_edit_expiryDateNotSet,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_insuranceExpiry != null)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: context.l10n.divers_edit_clearInsuranceExpiryTooltip,
              onPressed: () {
                setState(() {
                  _insuranceExpiry = null;
                  _hasChanges = true;
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.edit_calendar),
            tooltip: context.l10n.divers_edit_selectInsuranceExpiryTooltip,
            onPressed: _selectInsuranceExpiry,
          ),
        ],
      ),
    );
  }
}
