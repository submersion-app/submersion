import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class EmergencyContactsEditPage extends ConsumerStatefulWidget {
  const EmergencyContactsEditPage({super.key});

  @override
  ConsumerState<EmergencyContactsEditPage> createState() =>
      _EmergencyContactsEditPageState();
}

class _EmergencyContactsEditPageState
    extends ConsumerState<EmergencyContactsEditPage> {
  final _formKey = GlobalKey<FormState>();

  // Primary emergency contact
  final _ec1NameCtrl = TextEditingController();
  final _ec1PhoneCtrl = TextEditingController();
  final _ec1RelationCtrl = TextEditingController();

  // Secondary emergency contact
  final _ec2NameCtrl = TextEditingController();
  final _ec2PhoneCtrl = TextEditingController();
  final _ec2RelationCtrl = TextEditingController();

  bool _populated = false;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    for (final ctrl in _allControllers) {
      ctrl.addListener(_onFieldChanged);
    }
  }

  List<TextEditingController> get _allControllers => [
    _ec1NameCtrl,
    _ec1PhoneCtrl,
    _ec1RelationCtrl,
    _ec2NameCtrl,
    _ec2PhoneCtrl,
    _ec2RelationCtrl,
  ];

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    for (final ctrl in _allControllers) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _populateFromDiver(Diver diver) {
    if (_populated) return;
    _populated = true;
    _ec1NameCtrl.text = diver.emergencyContact.name ?? '';
    _ec1PhoneCtrl.text = diver.emergencyContact.phone ?? '';
    _ec1RelationCtrl.text = diver.emergencyContact.relation ?? '';
    _ec2NameCtrl.text = diver.emergencyContact2.name ?? '';
    _ec2PhoneCtrl.text = diver.emergencyContact2.phone ?? '';
    _ec2RelationCtrl.text = diver.emergencyContact2.relation ?? '';
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
        emergencyContact: EmergencyContact(
          name: _trimOrNull(_ec1NameCtrl),
          phone: _trimOrNull(_ec1PhoneCtrl),
          relation: _trimOrNull(_ec1RelationCtrl),
        ),
        emergencyContact2: EmergencyContact(
          name: _trimOrNull(_ec2NameCtrl),
          phone: _trimOrNull(_ec2PhoneCtrl),
          relation: _trimOrNull(_ec2RelationCtrl),
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
          title: Text(context.l10n.settings_profileHub_emergencyContacts),
        ),
        body: Center(child: Text('$error')),
      ),
      data: (diver) {
        if (diver == null) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.settings_profileHub_emergencyContacts),
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
          title: Text(context.l10n.settings_profileHub_emergencyContacts),
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
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildContactCard(
                  title: context.l10n.divers_edit_primaryContactTitle,
                  nameCtrl: _ec1NameCtrl,
                  phoneCtrl: _ec1PhoneCtrl,
                  relationCtrl: _ec1RelationCtrl,
                ),
                const SizedBox(height: 16),
                _buildContactCard(
                  title: context.l10n.divers_edit_secondaryContactTitle,
                  nameCtrl: _ec2NameCtrl,
                  phoneCtrl: _ec2PhoneCtrl,
                  relationCtrl: _ec2RelationCtrl,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required String title,
    required TextEditingController nameCtrl,
    required TextEditingController phoneCtrl,
    required TextEditingController relationCtrl,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_contactNameLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phoneCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_contactPhoneLabel,
                prefixIcon: const Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: relationCtrl,
              decoration: InputDecoration(
                labelText: context.l10n.divers_edit_relationshipLabel,
                prefixIcon: const Icon(Icons.people),
                hintText: context.l10n.divers_edit_relationshipHint,
              ),
              textCapitalization: TextCapitalization.words,
            ),
          ],
        ),
      ),
    );
  }
}
