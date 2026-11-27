import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_contact_rules.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_text_binding.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

export 'package:submersion/features/dive_sites/domain/services/site_contact_rules.dart';

/// Whether the Contact card can be saved. A value that was already stored
/// (from a sync or an import) does not block saving other changes.
bool siteContactIsValid(EditSession<DiveSite> session) {
  final email = session.valueOf(siteEmailField);
  final website = session.valueOf(siteWebsiteField);
  final stored = session.stored;
  return (isValidSiteEmail(email) || email == stored.email) &&
      (isValidSiteWebsite(website) || website == stored.website);
}

/// The Contact card's editor (issue #5073): the site's street address,
/// phone, email and website.
class SiteContactCardEditor extends StatefulWidget {
  const SiteContactCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  State<SiteContactCardEditor> createState() => _SiteContactCardEditorState();
}

class _SiteContactCardEditorState extends State<SiteContactCardEditor> {
  final Map<String, FieldTextBinding<DiveSite, String?>> _bindings = {};

  FieldTextBinding<DiveSite, String?> _bind(EditField<DiveSite, String?> f) =>
      _bindings[f.id] ??= siteWordsBinding(widget.session, f);

  void _disposeBindings() {
    for (final binding in _bindings.values) {
      binding.dispose();
    }
    _bindings.clear();
  }

  @override
  void didUpdateWidget(SiteContactCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _disposeBindings();
  }

  @override
  void dispose() {
    _disposeBindings();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = widget.session;
    Widget row(
      EditField<DiveSite, String?> field, {
      required String label,
      required String hint,
      TextInputType? keyboard,
      int maxLines = 1,
    }) => KeyedSubtree(
      key: ValueKey('site_contact_edit_${field.id}'),
      child: SuggestionFormRow(
        label: label,
        controller: _bind(field).controller,
        suggestions: const [],
        placeholder: hint,
        keyboardType: keyboard,
        maxLines: maxLines,
      ),
    );
    Widget error(bool valid, String message) => valid
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(
          siteAddressField,
          label: l10n.diveSites_edit_contact_address_label,
          hint: l10n.diveSites_edit_contact_address_hint,
          keyboard: TextInputType.streetAddress,
          maxLines: 4,
        ),
        row(
          sitePhoneField,
          label: l10n.diveSites_edit_contact_phone_label,
          hint: l10n.diveSites_edit_contact_phone_hint,
          keyboard: TextInputType.phone,
        ),
        row(
          siteEmailField,
          label: l10n.diveSites_edit_contact_email_label,
          hint: l10n.diveSites_edit_contact_email_hint,
          keyboard: TextInputType.emailAddress,
        ),
        row(
          siteWebsiteField,
          label: l10n.diveSites_edit_contact_website_label,
          hint: l10n.diveSites_edit_contact_website_hint,
          keyboard: TextInputType.url,
        ),
        // Why Save is refused, while a value cannot be used.
        ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final stored = session.stored;
            final email = session.valueOf(siteEmailField);
            final website = session.valueOf(siteWebsiteField);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                error(
                  isValidSiteEmail(email) || email == stored.email,
                  l10n.diveSites_edit_contact_emailInvalid,
                ),
                error(
                  isValidSiteWebsite(website) || website == stored.website,
                  l10n.diveSites_edit_contact_websiteInvalid,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
