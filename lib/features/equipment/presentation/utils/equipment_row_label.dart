import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// What one gear row shows: the item's name, and the details under it.
class EquipmentRowLabel {
  final String title;
  final List<String> subtitleParts;

  const EquipmentRowLabel({required this.title, required this.subtitleParts});

  /// Null rather than empty, because a non-null ListTile subtitle forces the
  /// two-line layout.
  String? get subtitle =>
      subtitleParts.isEmpty ? null : subtitleParts.join(' · ');
}

/// The localized pieces [buildEquipmentRowLabels] needs. Passed in so the
/// builder stays pure: no BuildContext, no provider, no settings.
class EquipmentRowLabelStrings {
  final String Function(String identifier) identifier;
  final String Function(String serial) serial;
  final String Function(String date) purchased;
  final String Function(DateTime date) formatDate;

  const EquipmentRowLabelStrings({
    required this.identifier,
    required this.serial,
    required this.purchased,
    required this.formatDate,
  });
}

/// Labels for every row of one list, keyed by item id (issue #1549).
///
/// Built for the whole list at once because telling identical items apart
/// is a property of the list, not of a row: when two rows would read the
/// same, each gains the first detail that differs between them (serial
/// number, then size, then purchase date), and rows that still read the
/// same after one detail go on to the next. Rows that are identical in all
/// three stay identical; a counter would not be stable from one list to
/// the next.
Map<String, EquipmentRowLabel> buildEquipmentRowLabels(
  Iterable<EquipmentItem> rows,
  EquipmentRowLabelStrings strings,
) {
  final items = rows.toList(growable: false);
  final parts = {for (final item in items) item.id: _baseParts(item, strings)};

  final tieBreaks = <String? Function(EquipmentItem)>[
    (e) => _text(e.serialNumber, strings.serial),
    (e) => _text(e.size, (v) => v),
    (e) => e.purchaseDate == null
        ? null
        : strings.purchased(strings.formatDate(e.purchaseDate!)),
  ];

  // Regrouped before every tie-break, not once: a detail that separates
  // some rows of a group can leave others still reading the same (two of
  // four pouches have a serial number, the other two only a purchase date),
  // and those move on to the next detail.
  for (final detailOf in tieBreaks) {
    for (final group in _collidingGroups(items, parts)) {
      final details = {for (final e in group) e.id: detailOf(e)};
      if (details.values.toSet().length < 2) continue;
      for (final e in group) {
        final detail = details[e.id];
        if (detail != null) parts[e.id] = [...parts[e.id]!, detail];
      }
    }
  }

  return {
    for (final item in items)
      item.id: EquipmentRowLabel(
        title: item.name,
        subtitleParts: parts[item.id]!,
      ),
  };
}

/// The rows that currently read the same as at least one other row.
List<List<EquipmentItem>> _collidingGroups(
  List<EquipmentItem> items,
  Map<String, List<String>> parts,
) {
  final groups = <String, List<EquipmentItem>>{};
  for (final item in items) {
    final key = '${item.name}\u0000${parts[item.id]!.join('\u0000')}';
    (groups[key] ??= []).add(item);
  }
  return [
    for (final group in groups.values)
      if (group.length > 1) group,
  ];
}

List<String> _baseParts(EquipmentItem item, EquipmentRowLabelStrings strings) {
  final identifier = _text(item.identifier, strings.identifier);
  return [if (item.fullName != item.name) item.fullName, ?identifier];
}

String? _text(String? value, String Function(String) wrap) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : wrap(trimmed);
}
