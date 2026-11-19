import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/merge_field_extras.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/similar_value_hint.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';

/// The merge page's Identity group (issue #4527, phase 2, plan 7): name,
/// description, country, region, city, island and body of water, as
/// suggestion-capable rows, each with the source caption and cycle button
/// [mergeExtras] gives it. The section ends with [placeLookup], which fills
/// the place fields above it.
class IdentitySection extends StatelessWidget {
  const IdentitySection({
    super.key,
    required this.allSites,
    required this.nameController,
    required this.descriptionController,
    required this.countryController,
    required this.regionController,
    required this.cityController,
    required this.islandController,
    required this.bodyOfWaterController,
    required this.nameValidator,
    required this.placeLookup,
    this.mergeExtras,
  });

  final List<DiveSite> allSites;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController countryController;
  final TextEditingController regionController;
  final TextEditingController cityController;
  final TextEditingController islandController;
  final TextEditingController bodyOfWaterController;
  final String? Function(String?) nameValidator;
  final Widget placeLookup;
  final MergeFieldExtras? Function(String key)? mergeExtras;

  Widget _row(
    BuildContext context, {
    required String key,
    required String label,
    required TextEditingController controller,
    List<String> suggestions = const [],
    bool enableFuzzy = false,
    String? placeholder,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool markdown = false,
  }) {
    final extras = mergeExtras?.call(key);
    return SuggestionFormRow(
      label: label,
      controller: controller,
      suggestions: suggestions,
      enableFuzzy: enableFuzzy,
      // Names and places take a capital per word; the Markdown description
      // is prose and takes one per sentence.
      textCapitalization: markdown
          ? TextCapitalization.sentences
          : TextCapitalization.words,
      placeholder: placeholder,
      validator: validator,
      maxLines: maxLines,
      markdown: markdown,
      caption: extras?.sourceLabel,
      trailing: extras == null
          ? null
          : MergeCycleButton(onPressed: extras.onCycle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FormSection(
      label: l10n.diveSites_edit_group_identity,
      icon: Icons.bookmark_outline,
      expanded: true,
      onToggle: null,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _row(
              context,
              key: 'name',
              label: l10n.diveSites_edit_field_siteName_label,
              controller: nameController,
              suggestions: suggestedSiteNames(allSites),
              enableFuzzy: true,
              placeholder: l10n.diveSites_edit_field_siteName_hint,
              validator: nameValidator,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: nameController,
                builder: (context, name, _) {
                  return SimilarValueHint(
                    query: name.text,
                    candidates: suggestedSiteNames(allSites),
                  );
                },
              ),
            ),
          ],
        ),
        _row(
          context,
          key: 'description',
          label: l10n.diveSites_edit_field_description_label,
          controller: descriptionController,
          placeholder: l10n.diveSites_edit_field_description_hint,
          maxLines: 3,
          markdown: true,
        ),
        _row(
          context,
          key: 'country',
          label: l10n.diveSites_edit_field_country_label,
          controller: countryController,
          suggestions: suggestedCountries(allSites),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: countryController,
          builder: (context, country, _) => _row(
            context,
            key: 'region',
            label: l10n.diveSites_edit_field_region_label,
            controller: regionController,
            suggestions: suggestedRegions(allSites, country.text),
            enableFuzzy: true,
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: countryController,
          builder: (context, country, _) =>
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: regionController,
                builder: (context, region, _) => _row(
                  context,
                  key: 'city',
                  label: l10n.diveSites_edit_field_city_label,
                  controller: cityController,
                  suggestions: suggestedCities(
                    allSites,
                    country.text,
                    region.text,
                  ),
                  enableFuzzy: true,
                ),
              ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: countryController,
          builder: (context, country, _) => _row(
            context,
            key: 'island',
            label: l10n.diveSites_edit_field_island_label,
            controller: islandController,
            suggestions: suggestedIslands(allSites, country.text),
            enableFuzzy: true,
          ),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: countryController,
          builder: (context, country, _) => _row(
            context,
            key: 'bodyOfWater',
            label: l10n.diveSites_edit_field_bodyOfWater_label,
            controller: bodyOfWaterController,
            suggestions: suggestedBodiesOfWater(allSites, country.text),
            enableFuzzy: true,
          ),
        ),
        placeLookup,
      ],
    );
  }
}
