import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/text/fuzzy_match.dart' show normalize;
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/refine_group_tile.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/autocomplete_options_list.dart';

const kRefineBuddyFieldKey = ValueKey('refine-buddy-name');
const kRefineSpeciesFieldKey = ValueKey('refine-species-search');

/// The Refine panel's People and life group (#2773): buddy names (several,
/// comma separated, with suggestions), dives with no buddy, and species
/// sighted.
class RefinePeopleGroup extends ConsumerStatefulWidget {
  const RefinePeopleGroup({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {'buddyNameFilter', 'noBuddyOnly', 'speciesIds'};

  static int activeCount(DiveFilterState f) => [
    f.buddyNameFilter?.isNotEmpty ?? false,
    f.noBuddyOnly == true,
    f.speciesIds.isNotEmpty,
  ].where((active) => active).length;

  static String title(AppLocalizations l10n) => l10n.diveLog_refine_groupPeople;

  @override
  ConsumerState<RefinePeopleGroup> createState() => _RefinePeopleGroupState();
}

class _RefinePeopleGroupState extends ConsumerState<RefinePeopleGroup> {
  late final _buddy = TextEditingController(
    text: widget.draft.buddyNameFilter ?? '',
  );
  final _buddyFocus = FocusNode();
  final _species = TextEditingController();
  final _speciesFocus = FocusNode();

  @override
  void dispose() {
    _buddy.dispose();
    _buddyFocus.dispose();
    _species.dispose();
    _speciesFocus.dispose();
    super.dispose();
  }

  /// A buddy name filter, which turns "no buddy" off: a dive either has a
  /// buddy to search for, or has none.
  void _setBuddyNames(String text) => widget.onChanged(
    widget.draft.copyWith(
      buddyNameFilter: text,
      clearBuddyNameFilter: text.isEmpty,
      clearNoBuddyOnly: text.isNotEmpty,
    ),
  );

  Iterable<String> _buddyOptions(String text, List<String> names) {
    if (text.isEmpty) return const [];
    final parts = text.split(',').map((e) => e.trim()).toList();
    final chosen = {
      for (final p in parts.take(parts.length - 1)) p.toLowerCase(),
    };
    final open = [
      for (final n in names)
        if (!chosen.contains(n.toLowerCase())) n,
    ];
    final last = parts.last.toLowerCase();
    if (last.isEmpty) return open;
    return open.where((n) => n.toLowerCase().contains(last));
  }

  void _pickBuddy(String selection) {
    // From the draft, not the controller: RawAutocomplete has already
    // replaced the field's text with the selection before this runs, which
    // would drop every name typed before the comma.
    final parts = (widget.draft.buddyNameFilter ?? '').split(',')..removeLast();
    final prefix = parts.join(',').trim();
    final next = prefix.isEmpty ? selection : '$prefix, $selection';
    _buddy.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _setBuddyNames(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.draft;
    final buddyNames =
        ref
            .watch(allBuddiesProvider)
            .valueOrNull
            ?.map((b) => b.name)
            .toSet()
            .toList() ??
        const <String>[];
    final allSpecies =
        ref.watch(allSpeciesProvider).valueOrNull ?? const <Species>[];
    final speciesById = {for (final s in allSpecies) s.id: s};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RefineSubLabel(l10n.diveLog_filter_sectionBuddy),
        RawAutocomplete<String>(
          textEditingController: _buddy,
          focusNode: _buddyFocus,
          optionsBuilder: (value) => _buddyOptions(value.text, buddyNames),
          onSelected: _pickBuddy,
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) =>
              TextField(
                key: kRefineBuddyFieldKey,
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: l10n.diveLog_filter_buddyName,
                  hintText: l10n.diveLog_filter_buddyHint,
                  prefixIcon: const Icon(Icons.person),
                ),
                onChanged: _setBuddyNames,
                // Commits the highlighted suggestion when the list is open.
                onSubmitted: (_) => onSubmitted(),
              ),
          optionsViewBuilder: (context, onSelected, options) =>
              AutocompleteOptionsList<String>(
                options: options,
                onSelected: onSelected,
                labelFor: (option) => option,
              ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.diveLog_filter_noBuddyOnly),
          subtitle: Text(l10n.diveLog_filter_showOnlyNoBuddy),
          secondary: const Icon(Icons.person_off),
          value: d.noBuddyOnly ?? false,
          onChanged: (v) {
            if (v) _buddy.clear();
            widget.onChanged(
              d.copyWith(
                noBuddyOnly: v ? true : null,
                clearNoBuddyOnly: !v,
                clearBuddyNameFilter: v,
              ),
            );
          },
        ),
        RefineSubLabel(l10n.diveLog_filter_sectionSpecies),
        if (d.speciesIds.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final id in d.speciesIds)
                InputChip(
                  label: Text(
                    speciesById[id]?.localizedCommonName(l10n) ??
                        l10n.diveLog_filterChip_speciesCount(1),
                  ),
                  onDeleted: () => widget.onChanged(
                    d.copyWith(
                      speciesIds: [
                        for (final s in d.speciesIds)
                          if (s != id) s,
                      ],
                    ),
                  ),
                ),
            ],
          ),
        Autocomplete<Species>(
          textEditingController: _species,
          focusNode: _speciesFocus,
          displayStringForOption: (s) => s.localizedCommonName(l10n),
          optionsBuilder: (value) {
            final needle = normalize(value.text);
            if (needle.isEmpty) return const Iterable<Species>.empty();
            return allSpecies
                .where(
                  (s) =>
                      !d.speciesIds.contains(s.id) &&
                      (normalize(
                            s.localizedCommonName(l10n),
                          ).contains(needle) ||
                          normalize(s.commonName).contains(needle) ||
                          normalize(s.scientificName ?? '').contains(needle)),
                )
                .take(8);
          },
          onSelected: (s) {
            widget.onChanged(d.copyWith(speciesIds: [...d.speciesIds, s.id]));
            _species.clear();
          },
          fieldViewBuilder: (context, controller, focusNode, _) => TextField(
            key: kRefineSpeciesFieldKey,
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: l10n.diveLog_filter_speciesSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ),
      ],
    );
  }
}
