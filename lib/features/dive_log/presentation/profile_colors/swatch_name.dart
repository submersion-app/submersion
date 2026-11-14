import 'package:flutter/material.dart';

import 'package:submersion/features/equipment/presentation/utils/equipment_color_names.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The name a diver and a screen reader know [color] by: the nearest (CIE76)
/// of the app's named equipment colours. None of the profile swatches is an
/// equipment colour exactly, so an exact lookup would name none of them.
String swatchName(AppLocalizations l10n, Color color) =>
    equipmentColorName(l10n, nearestEquipmentColor(color));
