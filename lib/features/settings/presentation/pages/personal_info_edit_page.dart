import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class PersonalInfoEditPage extends ConsumerStatefulWidget {
  final bool isNewDiver;

  const PersonalInfoEditPage({super.key, this.isNewDiver = false});

  @override
  ConsumerState<PersonalInfoEditPage> createState() =>
      _PersonalInfoEditPageState();
}

class _PersonalInfoEditPageState extends ConsumerState<PersonalInfoEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _populated = false;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onFieldChanged);
    _emailCtrl.addListener(_onFieldChanged);
    _phoneCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _populateFromDiver(Diver diver) {
    if (_populated) return;
    _populated = true;
    _nameCtrl.text = diver.name;
    _emailCtrl.text = diver.email ?? '';
    _phoneCtrl.text = diver.phone ?? '';
    _hasChanges = false;
  }

  String? _trimOrNull(TextEditingController ctrl) {
    final value = ctrl.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save(Diver? existingDiver) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      if (widget.isNewDiver) {
        final now = DateTime.now();
        final newDiver = Diver(
          id: const Uuid().v4(),
          name: _nameCtrl.text.trim(),
          email: _trimOrNull(_emailCtrl),
          phone: _trimOrNull(_phoneCtrl),
          createdAt: now,
          updatedAt: now,
        );
        final created = await ref
            .read(diverListNotifierProvider.notifier)
            .addDiver(newDiver);
        await ref
            .read(currentDiverIdProvider.notifier)
            .setCurrentDiver(created.id);
      } else if (existingDiver != null) {
        final updated = existingDiver.copyWith(
          name: _nameCtrl.text.trim(),
          email: _trimOrNull(_emailCtrl),
          phone: _trimOrNull(_phoneCtrl),
          updatedAt: DateTime.now(),
        );
        await ref.read(diverListNotifierProvider.notifier).updateDiver(updated);
      }

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
    Diver? diver;

    if (!widget.isNewDiver) {
      final diverAsync = ref.watch(currentDiverProvider);
      return diverAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, _) => Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.settings_profileHub_personalInfo),
          ),
          body: Center(child: Text('$error')),
        ),
        data: (loadedDiver) {
          if (loadedDiver == null) {
            return Scaffold(
              appBar: AppBar(
                title: Text(context.l10n.settings_profileHub_personalInfo),
              ),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          diver = loadedDiver;
          _populateFromDiver(loadedDiver);
          return _buildScaffold(diver);
        },
      );
    }

    return _buildScaffold(diver);
  }

  Widget _buildScaffold(Diver? diver) {
    final title = widget.isNewDiver
        ? context.l10n.settings_profileHub_createDiverTitle
        : context.l10n.settings_profileHub_personalInfo;

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
          title: Text(title),
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
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_nameLabel,
                        prefixIcon: const Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return context.l10n.divers_edit_nameError;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_emailLabel,
                        prefixIcon: const Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value != null && value.isNotEmpty) {
                          if (!value.contains('@') || !value.contains('.')) {
                            return context.l10n.divers_edit_emailError;
                          }
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.divers_edit_phoneLabel,
                        prefixIcon: const Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
