import 'package:flutter/material.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_header_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_markdown_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_card.dart';

/// The site page's cards that can be edited in place, by section (issue
/// #4527, phase 2). Each card's id is its section's name, shared with the
/// `cardId` of the fields it owns.
final Map<SiteDetailSectionId, EditCard<DiveSite>> siteEditCards = {
  SiteDetailSectionId.description: EditCard<DiveSite>(
    id: SiteDetailSectionId.description.name,
    title: (context) => context.l10n.diveSites_detail_section_description,
    leading: (context) => Icon(
      Icons.description,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    // Always on the page: empty, it says there is none.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => SiteMarkdownCardEditor(
      session: session,
      field: siteDescriptionField,
      placeholder: context.l10n.diveSites_edit_field_description_hint,
    ),
  ),
  SiteDetailSectionId.notes: EditCard<DiveSite>(
    id: SiteDetailSectionId.notes.name,
    title: (context) => context.l10n.diveSites_detail_section_notes,
    leading: (context) => Icon(
      Icons.notes,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    // Always on the page: empty, it says there are none.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        SiteMarkdownCardEditor(session: session, field: siteNotesField),
  ),
  SiteDetailSectionId.location: EditCard<DiveSite>(
    id: SiteDetailSectionId.location.name,
    title: (context) => context.l10n.diveSites_detail_section_location,
    leading: (context) =>
        Icon(Icons.map, size: 20, color: Theme.of(context).colorScheme.primary),
    // Always on the page: with nothing set, each row says so.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        SiteLocationCardEditor(session: session),
  ),
};

/// The site page's header block as a card: the site's name and its water.
/// It is not a section, so it is not in [siteEditCards].
final siteHeaderCard = EditCard<DiveSite>(
  id: siteHeaderCardId,
  title: (context) => context.l10n.diveSites_detail_section_header,
  isEmpty: (_) => false,
  isValid: siteNameIsValid,
  editorBuilder: (context, session) => SiteHeaderCardEditor(session: session),
);
