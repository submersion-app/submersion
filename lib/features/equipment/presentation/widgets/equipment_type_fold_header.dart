import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/collapsible_group_header.dart';

/// A type's foldable heading on a gear list (issues #3364, #4184): the type
/// name, its item count and a chevron. Indented under a place or an owner
/// when [nested]. A folded group shows [summary] under its name.
class EquipmentTypeFoldHeader extends StatelessWidget {
  EquipmentTypeFoldHeader({
    required String foldKey,
    required this.type,
    required this.count,
    required this.isExpanded,
    required this.onTap,
    this.nested = false,
    this.summary,
  }) : super(key: ValueKey('equipment-type-fold-$foldKey'));

  final EquipmentType type;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool nested;
  final String? summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CollapsibleGroupHeader(
      label: type.localizedName(l10n),
      countLabel: l10n.equipment_location_groupCount(count),
      isExpanded: isExpanded,
      onTap: onTap,
      summary: summary,
      indent: nested ? 40 : 16,
      isHeading: true,
    );
  }
}
