import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_catalogue_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_comparison_sheet.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_catalogue_offer_line.dart';
import 'package:submersion/core/data/visibility/item_sharing.dart';
import 'package:submersion/core/data/visibility/shared_item_policy.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sharing_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_sitting_load_on_open.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';
import 'package:submersion/shared/widgets/shared_items/shared_item_dialogs.dart';
import 'package:submersion/core/built_ins/built_in_catalog.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/edit_sections/site_type_chips.dart';
import 'package:submersion/features/settings/presentation/providers/hidden_built_ins_provider.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/services/site_suggestions.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_enum_chips_row.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_reader_sitting.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/similar_value_hint.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_form.dart';

/// Whether the sitting's name can be saved: not blank, unless it is the
/// stored name unchanged, which is not the diver's to fix before saving
/// another card (issue #4527, phase 2).
bool siteNameIsValid(EditSession<DiveSite> session) {
  final name = session.valueOf(siteNameField);
  return name.trim().isNotEmpty || name == session.stored.name;
}

/// The header block's editor: the site's name, with the hint that a site of
/// a similar name exists, and its water (issue #4527, phase 2).
class SiteHeaderCardEditor extends ConsumerStatefulWidget {
  const SiteHeaderCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  ConsumerState<SiteHeaderCardEditor> createState() =>
      _SiteHeaderCardEditorState();
}

class _SiteHeaderCardEditorState extends ConsumerState<SiteHeaderCardEditor>
    with SiteSittingLoadOnOpen<SiteHeaderCardEditor> {
  late FieldTextBinding<DiveSite, String> _name = _bindName();

  FieldTextBinding<DiveSite, String> _bindName() => FieldTextBinding(
    session: widget.session,
    field: siteNameField,
    format: (name) => name,
    parse: (text) => FieldValue(text.trim()),
  );

  @override
  void didUpdateWidget(SiteHeaderCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    _name.dispose();
    _name = _bindName();
  }

  @override
  EditSession<DiveSite> sittingOf(SiteHeaderCardEditor widget) =>
      widget.session;

  /// The site's types afresh unless the diver has changed them, and who it
  /// is shared with unless read already.
  @override
  Future<void> loadSitting(EditSession<DiveSite> session) => Future.wait([
    siteTypesList.load(session),
    if (siteSharing.loaded(session) == null) loadSiteSharing(session, ref.read),
  ]);

  /// Holds what the diver chose for [pair]; says so when what it needed
  /// could not be read, as the Review said a write that failed.
  Future<void> _holdReview(
    CataloguePair pair,
    CatalogueComparisonResult result,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final held = await holdCatalogueReviewFrom(
      ProviderScope.containerOf(context, listen: false),
      widget.session,
      pair,
      result,
    );
    // A sitting cancelled meanwhile has nothing to say about it.
    if (!held && !widget.session.isDisposed) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.diveSites_gapReview_error)),
      );
    }
  }

  /// "Shared with", as the form offered it: never on a library site, which
  /// follows its library, and only with two or more divers (the field hides
  /// itself otherwise). Locked while the profile, or the sharing, is not
  /// known yet, and to anyone but the owner.
  Widget? _sharingField(EditSession<DiveSite> session) {
    final stored = session.stored;
    if (stored.isLibrarySite) return null;
    final loaded = siteSharing.loaded(session);
    final unread = siteSharing.unread(session);
    if (loaded == null && !unread) return null;
    final current = siteSharing.inSitting(session) ?? ItemSharing.none;
    final activeDiver = ref.watch(validatedCurrentDiverIdProvider);
    return ItemSharingField(
      kind: SharedItemKind.site,
      value: current,
      original: loaded ?? ItemSharing.none,
      mayShare: unread
          ? null
          : canDestroySharedItemOnceKnown(activeDiver, ownerId: stored.diverId),
      ownerId: stored.diverId ?? activeDiver.value,
      itemName: session.working.name,
      onChanged: (next) => siteSharing.set(
        session,
        next,
        // The profile acting now, which the repository checks.
        actingDiverId: ref.read(validatedCurrentDiverIdProvider).value,
      ),
    );
  }

  /// Holds [ids] as the site's types, each as [allTypes] has it.
  void _setTypes(Set<String> ids, List<SiteTypeEntity> allTypes) {
    final byId = {
      for (final t in [...?siteTypesList.current(widget.session), ...allTypes])
        t.id: t,
    };
    siteTypesList.set(widget.session, [for (final id in ids) ?byId[id]]);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = widget.session;
    final allSites = ref.watch(sitesProvider).value ?? const <DiveSite>[];
    final names = suggestedSiteNames(allSites, excludeId: session.stored.id);
    return RecordCardForm<DiveSite>(
      cardId: siteHeaderCardId,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SuggestionFormRow(
            label: l10n.diveSites_edit_field_siteName_label,
            controller: _name.controller,
            // A new site starts at its name, which it needs (plan 6).
            autofocus: session.isNew,
            suggestions: names,
            textCapitalization: TextCapitalization.words,
            validator: (_) => siteNameIsValid(session)
                ? null
                : l10n.diveSites_edit_field_siteName_validation,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _name.controller,
              builder: (context, name, _) => SimilarValueHint(
                query: name.text,
                candidates: names,
                onAccept: (value) => _name.controller.text = value,
              ),
            ),
          ),
          // The types once read; until then a spinner, or Try again.
          if (sittingListPending(siteTypesList) case final pending?)
            pending
          else if (siteTypesList.current(session) case final types?)
            ListenableBuilder(
              listenable: session,
              builder: (context, _) {
                final all = ref.watch(siteTypesProvider).value ?? const [];
                final current = siteTypesList.current(session) ?? types;
                return SiteTypeChips(
                  allTypes: all,
                  hiddenTypeIds: ref.watch(
                    hiddenBuiltInIdsProvider(BuiltInCatalog.siteTypes),
                  ),
                  keepTypeIds: {
                    for (final t in siteTypesList.loaded(session) ?? types)
                      t.id,
                  },
                  selectedTypeIds: {for (final t in current) t.id},
                  onTypesChanged: (ids) => _setTypes(ids, all),
                  // Created there exist at once, and outlive a cancelled
                  // sitting, as a type made from the form's link does.
                  onManageTypes: () => context.push('/site-types'),
                );
              },
            ),
          ListenableBuilder(
            listenable: session,
            builder: (context, _) =>
                _sharingField(session) ?? const SizedBox.shrink(),
          ),
          // The catalogue offer's Review, held until Save; not in a library
          // reader's sitting, and gone once reviewed in this one.
          ListenableBuilder(
            listenable: session,
            builder: (context, _) => siteCatalogueReviewed(session)
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: SiteCatalogueOfferLine(
                      site: session.stored,
                      onReviewed: (pair, result) => _holdReview(pair, result),
                      // A fill writes the library's site, which a reader's
                      // sitting cannot (plan 5): the offer reads only.
                      reviewable: !isReaderSitting(session),
                    ),
                  ),
          ),
          SiteEnumChipsRow<WaterType>(
            session: session,
            field: siteWaterTypeField,
            label: l10n.diveSites_edit_section_waterType,
            values: WaterType.values,
            name: (value) => value.localizedName(l10n),
          ),
        ],
      ),
    );
  }
}
