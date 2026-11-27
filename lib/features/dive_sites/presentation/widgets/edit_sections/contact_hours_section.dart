import 'package:flutter/material.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/domain/services/site_contact_rules.dart';
import 'package:submersion/features/dive_sites/presentation/opening_hours_summary.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// The merge page's Contact group (issue #5073): the site's address,
/// phone, email and website as rows that take merge extras, and its
/// opening hours, chosen whole from one of the sites.
class ContactHoursSection extends StatelessWidget {
  const ContactHoursSection({
    super.key,
    required this.addressController,
    required this.phoneController,
    required this.emailController,
    required this.websiteController,
    required this.openingHours,
    this.mergeExtras,
    this.openingHoursExtras,
  });

  final TextEditingController addressController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController websiteController;
  final OpeningHours? openingHours;
  final MergeFieldExtras? Function(String key)? mergeExtras;
  final MergeFieldExtras? openingHoursExtras;

  Widget _row({
    required String key,
    required String label,
    required TextEditingController controller,
    TextInputType? keyboard,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    final extras = mergeExtras?.call(key);
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions: const [],
      maxLines: maxLines,
      keyboardType: keyboard,
      validator: validator,
      caption: extras?.sourceLabel,
      trailing: extras == null
          ? null
          : MergeCycleButton(onPressed: extras.onCycle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hours = openingHours;
    final hoursSummary = hours == null
        ? l10n.diveSites_hours_noSchedule
        : openingHoursSummary(l10n, hours);
    final extras = openingHoursExtras;
    return FormSection(
      label: l10n.diveSites_detail_section_contact,
      icon: Icons.contact_phone_outlined,
      expanded: true,
      onToggle: null,
      children: [
        _row(
          key: 'address',
          label: l10n.diveSites_edit_contact_address_label,
          controller: addressController,
          keyboard: TextInputType.streetAddress,
          maxLines: 3,
        ),
        _row(
          key: 'phone',
          label: l10n.diveSites_edit_contact_phone_label,
          controller: phoneController,
          keyboard: TextInputType.phone,
        ),
        _row(
          key: 'email',
          label: l10n.diveSites_edit_contact_email_label,
          controller: emailController,
          keyboard: TextInputType.emailAddress,
          // As the Contact card refuses them.
          validator: (text) => isValidSiteEmail(text)
              ? null
              : l10n.diveSites_edit_contact_emailInvalid,
        ),
        _row(
          key: 'website',
          label: l10n.diveSites_edit_contact_website_label,
          controller: websiteController,
          keyboard: TextInputType.url,
          validator: (text) => isValidSiteWebsite(text)
              ? null
              : l10n.diveSites_edit_contact_websiteInvalid,
        ),
        if (extras != null)
          MergeSourceRow(
            sourceLabel: extras.sourceLabel,
            onCycle: extras.onCycle,
          ),
        ListTile(
          key: const ValueKey('merge_opening_hours'),
          leading: const Icon(Icons.schedule),
          title: Text(l10n.diveSites_detail_section_openingHours),
          subtitle: Text(hoursSummary),
        ),
      ],
    );
  }
}
