import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
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

class _SiteHeaderCardEditorState extends ConsumerState<SiteHeaderCardEditor> {
  late FieldTextBinding<DiveSite, String> _name = _bindName();

  FieldTextBinding<DiveSite, String> _bindName() => FieldTextBinding(
    session: widget.session,
    field: siteNameField,
    format: (name) => name,
    parse: (text) => FieldValue(text.trim()),
  );

  @override
  void initState() {
    super.initState();
    _loadTypes();
  }

  @override
  void didUpdateWidget(SiteHeaderCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    _name.dispose();
    _name = _bindName();
    _loadTypes();
  }

  /// Reads the site's types afresh unless the diver has changed them, and
  /// draws them once read: keeping them does not notify the sitting.
  void _loadTypes() {
    siteTypesList.load(widget.session).then((_) {
      if (mounted) setState(() {});
    });
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
          if (siteTypesList.current(session) case final types?)
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
