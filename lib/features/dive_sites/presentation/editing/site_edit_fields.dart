import 'package:submersion/core/constants/site_detail_sections.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';

/// The site's description, edited on the Description card.
final siteDescriptionField = EditField<DiveSite, String>(
  id: 'description',
  cardId: SiteDetailSectionId.description.name,
  read: (site) => site.description,
  write: (site, description) => site.copyWith(description: description),
);

/// The site's notes, edited on the Notes card.
final siteNotesField = EditField<DiveSite, String>(
  id: 'notes',
  cardId: SiteDetailSectionId.notes.name,
  read: (site) => site.notes,
  write: (site, notes) => site.copyWith(notes: notes),
);
