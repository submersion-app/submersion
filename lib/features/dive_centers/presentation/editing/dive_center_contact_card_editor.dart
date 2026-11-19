import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/editing/dive_center_edit_fields.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_fill_hours_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// What is wrong with [hours], in the form's words, or null.
String? diveCenterFillHoursError(
  AppLocalizations l10n,
  DiveCenterFillHours hours,
) => switch (fillHoursProblem(hours.opensAt, hours.closesAt)) {
  null => null,
  FillHoursProblem.missingOne => l10n.diveCenters_fillHours_errorBoth,
  FillHoursProblem.closesBeforeOpens => l10n.diveCenters_fillHours_errorOrder,
};

/// The dive centre Contact card's editor (issue #4527, phase 3): phone,
/// email, website and fill hours, whose problem shows at once rather than
/// only after a blocked save.
class DiveCenterContactCardEditor extends ConsumerStatefulWidget {
  const DiveCenterContactCardEditor({super.key, required this.session});

  final EditSession<DiveCenter> session;

  @override
  ConsumerState<DiveCenterContactCardEditor> createState() =>
      _DiveCenterContactCardEditorState();
}

class _DiveCenterContactCardEditorState
    extends ConsumerState<DiveCenterContactCardEditor> {
  EditSession<DiveCenter> get _session => widget.session;

  late final _phone = _bind(diveCenterPhoneField);
  late final _email = _bind(diveCenterEmailField);
  late final _website = _bind(diveCenterWebsiteField);

  FieldTextBinding<DiveCenter, String?> _bind(
    EditField<DiveCenter, String?> field,
  ) => FieldTextBinding<DiveCenter, String?>(
    session: _session,
    field: field,
    format: (v) => v ?? '',
    parse: FieldValue<String?>.new,
  );

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final hours = _session.valueOf(diveCenterFillHoursField);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('dive-center-edit-phone'),
              controller: _phone.controller,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_label_phone,
                hintText: l10n.diveCenters_hint_phone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('dive-center-edit-email'),
              controller: _email.controller,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_label_email,
                hintText: l10n.diveCenters_hint_email,
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: diveCenterEmailValid(_email.controller.text)
                    ? null
                    : l10n.diveCenters_validation_invalidEmail,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('dive-center-edit-website'),
              controller: _website.controller,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: l10n.diveCenters_label_website,
                hintText: l10n.diveCenters_hint_website,
                prefixIcon: const Icon(Icons.language_outlined),
              ),
            ),
            const SizedBox(height: 24),
            DiveCenterFillHoursSection(
              opensAt: hours.opensAt,
              closesAt: hours.closesAt,
              units: units,
              errorText: diveCenterFillHoursError(l10n, hours),
              onChanged: (opens, closes) => _session.set(
                diveCenterFillHoursField,
                (opensAt: opens, closesAt: closes),
              ),
            ),
          ],
        );
      },
    );
  }
}
