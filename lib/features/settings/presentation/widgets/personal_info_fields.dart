import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/settings/presentation/pages/diver_profile_drafts.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// The personal fields and their state, shared by the personal info page
/// and the new-diver page.
class PersonalInfoForm {
  final name = TextEditingController();
  final email = TextEditingController();
  final phone = TextEditingController();
  final social = TextEditingController();
  final birthYear = TextEditingController();

  /// The sex picked, or null for not set.
  DiverSex? sex;

  List<TextEditingController> get _controllers => [
    name,
    email,
    phone,
    social,
    birthYear,
  ];

  /// The form as it reads now.
  PersonalInfoDraft get draft => (
    name: name.text,
    email: email.text,
    phone: phone.text,
    social: social.text,
    sex: sex,
    birthYear: birthYear.text,
  );

  /// Fills the form from [diver].
  void fill(Diver diver) {
    name.text = diver.name;
    email.text = diver.email ?? '';
    phone.text = diver.phone ?? '';
    social.text = diver.socialHandle ?? '';
    birthYear.text = diver.birthYear?.toString() ?? '';
    sex = diver.sex;
  }

  /// Calls [listener] on every change to a text field. The sex dropdown
  /// reports through `PersonalInfoFields.onSexChanged`.
  void addListener(VoidCallback listener) {
    for (final controller in _controllers) {
      controller.addListener(listener);
    }
  }

  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
  }
}

/// Name, email, phone, social handle, sex and birth year, with their
/// checks and the note on what sex and birth year are for.
class PersonalInfoFields extends StatelessWidget {
  const PersonalInfoFields({
    super.key,
    required this.form,
    required this.onSexChanged,
  });

  final PersonalInfoForm form;

  /// The sex dropdown changed: set [PersonalInfoForm.sex] and rebuild.
  final ValueChanged<DiverSex?> onSexChanged;

  /// The earliest birth year the field accepts.
  static const int _minBirthYear = 1900;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: form.name,
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
          controller: form.email,
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
          controller: form.phone,
          decoration: InputDecoration(
            labelText: context.l10n.divers_edit_phoneLabel,
            prefixIcon: const Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: form.social,
          decoration: InputDecoration(
            labelText: context.l10n.buddyShare_social,
            prefixIcon: const Icon(Icons.alternate_email),
          ),
        ),
        const SizedBox(height: 16),
        ..._bodyEstimateFields(context),
      ],
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
        initialValue: form.sex,
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
        onChanged: onSexChanged,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: form.birthYear,
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
