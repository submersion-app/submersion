import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/searchable_filter_dropdown.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const kRefineCustomValueKey = ValueKey('refine-custom-value');

/// The Refine panel's Custom fields group (#2773): a key the diver has used,
/// then text its value contains. Clearing the key clears the value.
class RefineCustomFieldsGroup extends ConsumerStatefulWidget {
  const RefineCustomFieldsGroup({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {'customFieldKey', 'customFieldValue'};

  static int activeCount(DiveFilterState f) =>
      (f.customFieldKey?.isNotEmpty ?? false) ? 1 : 0;

  static String title(AppLocalizations l10n) =>
      l10n.diveLog_refine_groupCustomFields;

  @override
  ConsumerState<RefineCustomFieldsGroup> createState() =>
      _RefineCustomFieldsGroupState();
}

class _RefineCustomFieldsGroupState
    extends ConsumerState<RefineCustomFieldsGroup> {
  late final _value = TextEditingController(
    text: widget.draft.customFieldValue ?? '',
  );

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = widget.draft;
    final diverId = ref.watch(currentDiverIdProvider);
    // `.value` keeps the last keys through a reload, failed or pending, so
    // the controls never blink out to the "no custom fields" text.
    final keys = diverId == null
        ? const <String>[]
        : ref.watch(customFieldKeySuggestionsProvider(diverId)).value ??
              const <String>[];
    if (keys.isEmpty) {
      return Text(
        l10n.diveLog_search_customFieldValue,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SearchableFilterDropdown<String>(
          value: d.customFieldKey,
          labelText: l10n.diveLog_search_customFieldKey,
          allOptionLabel: l10n.diveLog_search_customFieldKey,
          searchHintText: l10n.diveLog_filter_searchFieldsHint,
          icon: Icons.extension,
          options: [
            for (final key in keys)
              FilterDropdownOption(value: key, label: key),
          ],
          onChanged: (key) {
            if (key == null) _value.clear();
            widget.onChanged(
              d.copyWith(
                customFieldKey: key,
                clearCustomFieldKey: key == null,
                clearCustomFieldValue: key == null,
              ),
            );
          },
        ),
        if (d.customFieldKey != null) ...[
          const SizedBox(height: 16),
          TextField(
            key: kRefineCustomValueKey,
            controller: _value,
            decoration: InputDecoration(
              labelText: l10n.diveLog_search_customFieldValue,
              prefixIcon: const Icon(Icons.search),
            ),
            onChanged: (text) => widget.onChanged(
              d.copyWith(
                customFieldValue: text,
                clearCustomFieldValue: text.isEmpty,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
