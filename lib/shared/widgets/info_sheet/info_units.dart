import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';

/// The diver's unit formatter, read when an info icon is tapped.
///
/// Info content builds on tap, not on build, so a card that holds no `ref`
/// still fills its sheet with the diver's units without watching settings.
UnitFormatter infoUnits(BuildContext context) => ProviderScope.containerOf(
  context,
  listen: false,
).read(unitFormatterProvider);
