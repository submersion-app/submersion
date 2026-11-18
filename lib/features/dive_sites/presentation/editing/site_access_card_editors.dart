import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_plain_fields.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_text_binding.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/enum_multi_picker_row.dart';
import 'package:submersion/shared/widgets/forms/suggestion_form_row.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The Hazards card's editor (issue #4527, phase 2).
class SiteHazardsCardEditor extends StatefulWidget {
  const SiteHazardsCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  State<SiteHazardsCardEditor> createState() => _SiteHazardsCardEditorState();
}

class _SiteHazardsCardEditorState extends State<SiteHazardsCardEditor> {
  late FieldTextBinding<DiveSite, String?> _hazards = siteWordsBinding(
    widget.session,
    siteHazardsField,
  );

  @override
  void didUpdateWidget(SiteHazardsCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session == widget.session) return;
    _hazards.dispose();
    _hazards = siteWordsBinding(widget.session, siteHazardsField);
  }

  @override
  void dispose() {
    _hazards.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SuggestionFormRow(
      label: l10n.diveSites_edit_hazards_label,
      controller: _hazards.controller,
      suggestions: const [],
      placeholder: l10n.diveSites_edit_hazards_hint,
      maxLines: 3,
    );
  }
}

/// The Access card's editor: parking, access notes (Markdown), how divers
/// get in and out, with the form's one-tap fill from the dives logged here,
/// and the mooring number (issue #4527, phase 2).
class SiteAccessCardEditor extends ConsumerStatefulWidget {
  const SiteAccessCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  ConsumerState<SiteAccessCardEditor> createState() =>
      _SiteAccessCardEditorState();
}

class _SiteAccessCardEditorState extends ConsumerState<SiteAccessCardEditor> {
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
  void didUpdateWidget(SiteAccessCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _disposeBindings();
  }

  @override
  void dispose() {
    _disposeBindings();
    super.dispose();
  }

  /// The form's one-tap fill when the site has no entry or exit method yet
  /// but the diver has logged dives here. Offered only while both are
  /// empty: once the site carries a value, dives that inherited it would
  /// read as evidence for it.
  Widget? _entrySuggestion(EditSession<DiveSite> session) {
    if (session.isNew) return null;
    if (session.valueOf(siteEntryMethodsField).isNotEmpty ||
        session.valueOf(siteExitMethodsField).isNotEmpty) {
      return null;
    }
    final suggestion = ref
        .watch(siteEntryExitSuggestionProvider(session.stored.id))
        .value;
    if (suggestion == null) return null;
    final l10n = context.l10n;
    final entryLabel = suggestion.entry.localizedName(l10n);
    final exit = suggestion.exit;
    final label = exit == null
        ? l10n.diveSites_edit_access_entrySuggestionEntryOnly(
            suggestion.count,
            entryLabel,
          )
        : l10n.diveSites_edit_access_entrySuggestionPair(
            suggestion.count,
            entryLabel,
            exit.localizedName(l10n),
          );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ActionChip(
          avatar: const Icon(Icons.history, size: 18),
          label: Text(label),
          onPressed: () {
            session.set(siteEntryMethodsField, [suggestion.entry]);
            session.set(siteExitMethodsField, [?exit]);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        Widget methods(
          EditField<DiveSite, List<EntryMethod>> field,
          String label,
        ) => EnumMultiPickerRow<EntryMethod>(
          label: label,
          value: session.valueOf(field),
          values: EntryMethod.values,
          displayName: (v) => v.localizedName(l10n),
          onChanged: (value) => session.set(field, value),
        );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SuggestionFormRow(
              label: l10n.diveSites_edit_access_parkingInfo_label,
              controller: _bind(siteParkingInfoField).controller,
              suggestions: const [],
              placeholder: l10n.diveSites_edit_access_parkingInfo_hint,
              maxLines: 2,
            ),
            SuggestionFormRow(
              label: l10n.diveSites_edit_access_accessNotes_label,
              controller: _bind(siteAccessNotesField).controller,
              suggestions: const [],
              placeholder: l10n.diveSites_edit_access_accessNotes_hint,
              maxLines: 3,
              markdown: true,
            ),
            ?_entrySuggestion(session),
            methods(
              siteEntryMethodsField,
              l10n.diveSites_edit_access_entryMethod_label,
            ),
            methods(
              siteExitMethodsField,
              l10n.diveSites_edit_access_exitMethod_label,
            ),
            SuggestionFormRow(
              label: l10n.diveSites_edit_access_mooringNumber_label,
              controller: _bind(siteMooringNumberField).controller,
              suggestions: const [],
              placeholder: l10n.diveSites_edit_access_mooringNumber_hint,
            ),
          ],
        );
      },
    );
  }
}
