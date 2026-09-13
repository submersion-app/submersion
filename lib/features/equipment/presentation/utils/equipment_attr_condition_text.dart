import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_attribute_l10n.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Short label for an active choice condition, e.g. "Hose type: HP (high
/// pressure), LPI (inflator)". Options follow the catalog's order rather than
/// the order they were tapped, so one filter always reads the same way.
String attrConditionLabel(
  AppLocalizations l10n,
  EquipmentAttrCondition condition,
) {
  final order =
      EquipmentAttributeCatalog.defFor(condition.key)?.choiceKeys ??
      const <String>[];
  int rank(String option) {
    final index = order.indexOf(option);
    return index < 0 ? order.length : index;
  }

  final options = condition.choices.toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.compareTo(b);
    });
  return l10n.equipment_list_activeFilter_attribute(
    attributeLabel(l10n, condition.key),
    options
        .map((option) => attributeChoiceLabel(l10n, condition.key, option))
        .join(', '),
  );
}
