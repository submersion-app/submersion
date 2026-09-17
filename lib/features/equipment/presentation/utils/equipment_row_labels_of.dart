import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Row labels for [items] as one list shows them, in the app's language and
/// the active diver's date format. Pass every row the list shows, not one
/// row at a time: collisions are detected across the list.
Map<String, EquipmentRowLabel> equipmentRowLabelsOf(
  BuildContext context,
  WidgetRef ref,
  Iterable<EquipmentItem> items,
) {
  final l10n = context.l10n;
  final units = UnitFormatter(ref.watch(settingsProvider));
  return buildEquipmentRowLabels(
    items,
    EquipmentRowLabelStrings(
      identifier: l10n.equipment_rowLabel_identifier,
      serial: l10n.equipment_rowLabel_serial,
      purchased: l10n.equipment_rowLabel_purchased,
      formatDate: units.formatDate,
    ),
  );
}
