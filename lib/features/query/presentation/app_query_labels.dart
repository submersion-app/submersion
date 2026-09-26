import 'package:flutter/widgets.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/presentation/query_labels.dart';
import 'package:submersion/core/query/registry/query_field.dart';
import 'package:submersion/core/query/registry/query_relation.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weekday_filter_selector.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/features/query/presentation/query_label_lookup.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// [QueryLabels] over the app's ARB strings and enum display extensions.
///
/// Enum values are matched by the registry field's label key, which names
/// the subject and field (`query_dives_waterType`), so the same stored name
/// on two entities cannot be confused.
class AppQueryLabels implements QueryLabels {
  AppQueryLabels(this._context) : _l10n = _context.l10n;

  final BuildContext _context;
  final AppLocalizations _l10n;

  static const _weekdays = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  String field(QueryField field) => queryLabelForKey(_l10n, field.labelKey);

  @override
  String relation(QueryRelation relation) =>
      queryLabelForKey(_l10n, relation.labelKey);

  @override
  String entity(QuerySubject subject) =>
      queryLabelForKey(_l10n, 'query_entity_${subject.name}');

  @override
  String op(QueryOp op) => queryLabelForKey(_l10n, 'query_op_${op.name}');

  @override
  String enumValue(QueryField field, String value) {
    T? byName<T extends Enum>(List<T> values) {
      for (final v in values) {
        if (v.name == value) return v;
      }
      return null;
    }

    switch (field.labelKey) {
      case 'query_dives_waterType':
        return byName(WaterType.values)?.localizedName(_l10n) ?? value;
      case 'query_dives_currentStrength':
        return byName(CurrentStrength.values)?.localizedName(_l10n) ?? value;
      case 'query_dives_entryMethod':
      case 'query_dives_exitMethod':
        return byName(EntryMethod.values)?.localizedName(_l10n) ?? value;
      case 'query_dives_diveMode':
        return byName(DiveMode.values)?.localizedName(_l10n) ?? value;
      case 'query_dives_weekday':
        final i = _weekdays.indexOf(value);
        return i < 0 ? value : weekdayAbbreviation(_context, i + 1);
      case 'query_weights_type':
        return byName(WeightType.values)?.localizedName(_l10n) ?? value;
      case 'query_equipment_type':
        return byName(EquipmentType.values)?.localizedName(_l10n) ?? value;
      case 'query_equipment_status':
        return byName(EquipmentStatus.values)?.localizedName(_l10n) ?? value;
      default:
        return value;
    }
  }
}
