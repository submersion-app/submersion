import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/app/app_exit_guard.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

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
  final _socialCtrl = TextEditingController();
  final _birthYearCtrl = TextEditingController();
  DiverSex? _sex;

  /// The earliest birth year the field accepts.
  static const int _minBirthYear = 1900;

  bool _populated = false;
  bool _hasChanges = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onFieldChanged);
    _emailCtrl.addListener(_onFieldChanged);
    _phoneCtrl.addListener(_onFieldChanged);
    _socialCtrl.addListener(_onFieldChanged);
    _birthYearCtrl.addListener(_onFieldChanged);
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
    _socialCtrl.dispose();
    _birthYearCtrl.dispose();
    super.dispose();
  }

  void _populateFromDiver(Diver diver) {
    if (_populated) return;
    _populated = true;
    _nameCtrl.text = diver.name;
    _emailCtrl.text = diver.email ?? '';
    _phoneCtrl.text = diver.phone ?? '';
    _socialCtrl.text = diver.socialHandle ?? '';
    _birthYearCtrl.text = diver.birthYear?.toString() ?? '';
    _sex = diver.sex;
    _hasChanges = false;
  }

  /// The birth year field's value once the form has validated: blank is
  /// "not given", and unreadable text cannot reach here.
  int? get _birthYear => switch (readNumber(
    _birthYearCtrl.text,
    integer: true,
    allowNegative: false,
  )) {
    NumberValue(:final value) => value.round(),
    NumberBlank() || NumberInvalid() => null,
  };

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
          socialHandle: _trimOrNull(_socialCtrl),
          sex: _sex,
          birthYear: _birthYear,
          createdAt: now,
          updatedAt: now,
        );
        final created = await ref
            .read(diverListNotifierProvider.notifier)
            .addDiver(newDiver);
        // The new diver stands either way; becoming them starts the table
        // editor clean, so the page underneath may keep the current one.
        if (await ref.read(appExitGuardProvider).mayLeave()) {
          await ref
              .read(currentDiverIdProvider.notifier)
              .setCurrentDiver(created.id);
        }
      } else if (existingDiver != null) {
        final updated = existingDiver.copyWith(
          name: _nameCtrl.text.trim(),
          email: _trimOrNull(_emailCtrl),
          phone: _trimOrNull(_phoneCtrl),
          socialHandle: _trimOrNull(_socialCtrl),
          sex: _sex,
          birthYear: _birthYear,
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
              AppBarTextAction(
                label: context.l10n.divers_edit_saveButton,
                onPressed: () => _save(diver),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _socialCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.buddyShare_social,
                        prefixIcon: const Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._bodyEstimateFields(context),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sex and birth year, both optional: they only sharpen the body fat
  /// estimate behind the weight prediction (issue #4525), and the note
  /// under them says so.
  List<Widget> _bodyEstimateFields(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final thisYear = DateTime.now().year;
    return [
      DropdownButtonFormField<DiverSex?>(
        key: const Key('personalInfo_sex'),
        initialValue: _sex,
        decoration: InputDecoration(
          labelText: l10n.diverProfile_sex_label,
          prefixIcon: const Icon(Icons.wc),
        ),
        items: [
          DropdownMenuItem<DiverSex?>(
            value: null,
            child: Text(l10n.diverProfile_sex_notSet),
          ),
          DropdownMenuItem<DiverSex?>(
            value: DiverSex.female,
            child: Text(l10n.diverProfile_sex_female),
          ),
          DropdownMenuItem<DiverSex?>(
            value: DiverSex.male,
            child: Text(l10n.diverProfile_sex_male),
          ),
        ],
        onChanged: (value) => setState(() {
          _sex = value;
          _hasChanges = true;
        }),
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _birthYearCtrl,
        decoration: InputDecoration(
          labelText: l10n.diverProfile_birthYear_label,
          prefixIcon: const Icon(Icons.cake_outlined),
        ),
        keyboardType: TextInputType.number,
        inputFormatters: numberInputFormatters(),
        validator: numberValidator(
          context,
          integer: true,
          allowNegative: false,
          check: (year) => year >= _minBirthYear && year <= thisYear
              ? null
              : l10n.diverProfile_birthYear_invalid(thisYear),
        ),
      ),
      const SizedBox(height: 8),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          l10n.diverProfile_bodyEstimate_note,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    ];
  }
}
