import 'package:flutter/material.dart';

import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_attachment_card_editors.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_collection_card_editors.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_edit_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_access_card_editors.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_header_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_location_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_markdown_card_editor.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_measure_card_editors.dart';
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
  SiteDetailSectionId.depth: EditCard<DiveSite>(
    id: SiteDetailSectionId.depth.name,
    title: (context) => context.l10n.diveSites_detail_section_depthRange,
    leading: (context) => Icon(
      Icons.arrow_downward,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    isEmpty: (_) => false,
    isValid: siteDepthRangeIsValid,
    editorBuilder: (context, session) => SiteDepthCardEditor(session: session),
  ),
  SiteDetailSectionId.altitude: EditCard<DiveSite>(
    id: SiteDetailSectionId.altitude.name,
    title: (context) => context.l10n.diveSites_detail_section_altitude,
    leading: (context) => Icon(
      Icons.terrain,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    isEmpty: (site) => site.altitude == null,
    editorBuilder: (context, session) =>
        SiteAltitudeCardEditor(session: session),
  ),
  SiteDetailSectionId.difficulty: EditCard<DiveSite>(
    id: SiteDetailSectionId.difficulty.name,
    title: (context) => context.l10n.diveSites_detail_section_difficultyLevel,
    leading: (context) => Icon(
      Icons.fitness_center,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    isEmpty: (site) => site.difficulty == null,
    editorBuilder: (context, session) =>
        SiteDifficultyCardEditor(session: session),
  ),
  SiteDetailSectionId.rating: EditCard<DiveSite>(
    id: SiteDetailSectionId.rating.name,
    title: (context) => context.l10n.diveSites_detail_section_rating,
    leading: (context) => Icon(
      Icons.star,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    isEmpty: (_) => false,
    editorBuilder: (context, session) => SiteRatingCardEditor(session: session),
  ),
  SiteDetailSectionId.hazards: EditCard<DiveSite>(
    id: SiteDetailSectionId.hazards.name,
    title: (context) => context.l10n.diveSites_detail_section_hazards,
    leading: (context) => Icon(
      Icons.warning_amber,
      size: 20,
      color: Theme.of(context).colorScheme.error,
    ),
    isEmpty: (site) => site.hazards?.isNotEmpty != true,
    editorBuilder: (context, session) =>
        SiteHazardsCardEditor(session: session),
  ),
  SiteDetailSectionId.access: EditCard<DiveSite>(
    id: SiteDetailSectionId.access.name,
    title: (context) => context.l10n.diveSites_detail_section_access,
    leading: (context) => Icon(
      Icons.directions,
      size: 20,
      color: Theme.of(context).colorScheme.primary,
    ),
    // As the page decides whether to show the card.
    isEmpty: (site) => !site.hasAccessInfo,
    editorBuilder: (context, session) => SiteAccessCardEditor(session: session),
  ),
  SiteDetailSectionId.features: EditCard<DiveSite>(
    id: SiteDetailSectionId.features.name,
    title: (context) => context.l10n.siteFeature_sectionTitle,
    // On the page wherever the site has coordinates, with or without
    // features; there is nowhere to place one without them.
    isEmpty: (site) => !site.hasCoordinates,
    offeredWhenEmpty: (session) => session.working.hasCoordinates,
    editorBuilder: (context, session) =>
        SiteFeaturesCardEditor(session: session),
  ),
  SiteDetailSectionId.marineLife: EditCard<DiveSite>(
    id: SiteDetailSectionId.marineLife.name,
    title: (context) => context.l10n.marineLife_siteSection_title,
    // Always on the page: empty, it says there are none.
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        SiteSpeciesCardEditor(session: session),
  ),
  SiteDetailSectionId.media: EditCard<DiveSite>(
    id: SiteDetailSectionId.media.name,
    title: (context) => context.l10n.media_siteMediaSection_title,
    // Always on the page: empty, it says there are none.
    isEmpty: (_) => false,
    editorBuilder: (context, session) => SiteMediaCardEditor(session: session),
  ),
  SiteDetailSectionId.documents: EditCard<DiveSite>(
    id: SiteDetailSectionId.documents.name,
    title: (context) => context.l10n.documents_section_title,
    isEmpty: (_) => false,
    editorBuilder: (context, session) =>
        SiteDocumentsCardEditor(session: session),
  ),
  SiteDetailSectionId.tags: EditCard<DiveSite>(
    id: SiteDetailSectionId.tags.name,
    title: (context) => context.l10n.diveLog_detail_section_tags,
    // Its rows are not columns of the site: locked, the card decides for
    // itself; unlocked, from the sitting's list, once loaded.
    isEmpty: (_) => false,
    isEmptyInSitting: (session) =>
        siteTagsList.current(session)?.isEmpty ?? false,
    editorBuilder: (context, session) => SiteTagsCardEditor(session: session),
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
