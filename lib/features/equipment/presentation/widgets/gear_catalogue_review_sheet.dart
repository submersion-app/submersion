import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_offer.dart';
import 'package:submersion/features/equipment/domain/catalogue/equipment_catalogue_record.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_catalogue_sitting.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_units.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Shows what [offer] would give the item, field by field, with a tick
/// each (issue #5118). Writes nothing: it answers with what the diver
/// chose, or null when dismissed.
Future<GearCatalogueReviewResult?> showGearCatalogueReview(
  BuildContext context,
  CatalogueOffer offer,
) => showModalBottomSheet<GearCatalogueReviewResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => _Review(offer: offer),
);

/// The publisher and newest date of [record]'s sources, for the line
/// under its name: the manufacturer when any source is theirs. With
/// [fieldPrefix], only the sources that give a field starting with it (the
/// manufacturer card dates its links by the pages that gave them).
({CataloguePublisher publisher, DateTime? checked})? catalogueSourceSummary(
  EquipmentCatalogueRecord record, {
  String? fieldPrefix,
}) {
  final sources = [
    for (final source in record.sources)
      if (fieldPrefix == null ||
          source.fields.any((f) => f.startsWith(fieldPrefix)))
        source,
  ];
  if (sources.isEmpty) return null;
  final publisher = CataloguePublisher.values.firstWhere(
    (p) => sources.any((s) => s.publisher == p),
  );
  DateTime? newest;
  for (final source in sources) {
    final checked = source.checked;
    if (checked != null && (newest == null || checked.isAfter(newest))) {
      newest = checked;
    }
  }
  return (publisher: publisher, checked: newest);
}

/// "From the manufacturer, checked Nov 27, 2026", or null with no sources.
String? catalogueSourceLine(
  AppLocalizations l10n,
  String locale,
  EquipmentCatalogueRecord record,
) {
  final summary = catalogueSourceSummary(record);
  if (summary == null || summary.checked == null) return null;
  final publisher = switch (summary.publisher) {
    CataloguePublisher.manufacturer =>
      l10n.equipment_catalogue_publisher_manufacturer,
    CataloguePublisher.libdivecomputer =>
      l10n.equipment_catalogue_publisher_libdivecomputer,
    CataloguePublisher.thirdParty =>
      l10n.equipment_catalogue_publisher_thirdParty,
  };
  return l10n.equipment_catalogue_sheetSource(
    publisher,
    DateFormat.yMMMd(locale).format(summary.checked!),
  );
}

class _Review extends ConsumerStatefulWidget {
  const _Review({required this.offer});

  final CatalogueOffer offer;

  @override
  ConsumerState<_Review> createState() => _ReviewState();
}

class _ReviewState extends ConsumerState<_Review> {
  late Set<String> _ticked = {
    for (final row in widget.offer.rows)
      if (row.startTicked) row.fieldName,
  };

  void _toggle(String field) => setState(() {
    _ticked = _ticked.contains(field)
        ? _ticked.difference({field})
        : {..._ticked, field};
  });

  String _label(AppLocalizations l10n, CatalogueOfferRow row) =>
      switch (row.kind) {
        CatalogueOfferFieldKind.brand => l10n.equipment_edit_brandLabel,
        CatalogueOfferFieldKind.model => l10n.equipment_edit_modelLabel,
        CatalogueOfferFieldKind.attribute => attributeLabel(
          l10n,
          row.fieldName,
        ),
      };

  String _value(
    AppLocalizations l10n,
    UnitFormatter units,
    CatalogueOfferRow row,
    Object? value,
  ) {
    if (value == null) return l10n.equipment_catalogue_none;
    if (row.kind != CatalogueOfferFieldKind.attribute) return '$value';
    final attr = EquipmentAttribute(
      id: '',
      equipmentId: '',
      key: row.fieldName,
      valueText: value is String ? value : null,
      valueNum: value is num ? value.toDouble() : null,
    );
    final def = EquipmentAttributeCatalog.defFor(row.fieldName);
    if (def?.kind == AttributeKind.choice && value is String) {
      return attributeChoiceLabel(l10n, row.fieldName, value);
    }
    final shown = formatAttributeValue(attr, def, units, l10n);
    return shown.isEmpty ? '$value' : shown;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final offer = widget.offer;
    final record = offer.record;
    final source = catalogueSourceLine(
      l10n,
      Localizations.localeOf(context).toLanguageTag(),
      record,
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${record.manufacturer} ${record.model}',
            style: theme.textTheme.titleMedium,
          ),
          if (source != null) Text(source, style: muted),
          const SizedBox(height: 12),
          if (offer.rows.isEmpty)
            Text(l10n.equipment_catalogue_nothingToFill)
          else
            for (final row in offer.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      key: ValueKey('catalogue-tick-${row.fieldName}'),
                      value: _ticked.contains(row.fieldName),
                      onChanged: (_) => _toggle(row.fieldName),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _label(l10n, row),
                            style: theme.textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _Captioned(
                                  caption: l10n.equipment_catalogue_col_yours,
                                  value: _value(
                                    l10n,
                                    units,
                                    row,
                                    row.itemValue,
                                  ),
                                  muted: muted,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _Captioned(
                                  caption:
                                      l10n.equipment_catalogue_col_catalogue,
                                  value: _value(
                                    l10n,
                                    units,
                                    row,
                                    row.recordValue,
                                  ),
                                  muted: muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          if (!record.links.isEmpty) ...[
            const SizedBox(height: 12),
            Text(l10n.equipment_catalogue_linksNote, style: muted),
          ],
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(const GearCatalogueNotThisModel()),
                child: Text(l10n.equipment_catalogue_notThisModel),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.of(context).pop(GearCatalogueApply(_ticked)),
                child: Text(l10n.equipment_catalogue_apply(_ticked.length)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A caption over a value, as the site catalogue's comparison shows them.
class _Captioned extends StatelessWidget {
  const _Captioned({
    required this.caption,
    required this.value,
    required this.muted,
  });

  final String caption;
  final String value;
  final TextStyle? muted;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(caption, style: muted),
      Text(value),
    ],
  );
}
