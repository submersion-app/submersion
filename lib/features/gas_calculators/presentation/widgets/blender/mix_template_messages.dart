import 'package:flutter/widgets.dart';
import 'package:submersion/features/gas_calculators/domain/blending/blender_preferences.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The message for a [MixTemplateRejection], or null when there was none.
///
/// Kept in one place so the template menu and the manage dialog say the same
/// thing for the same reason. They previously disagreed: the menu explained
/// itself and the dialog just did nothing (PR #1215 review).
String? describeTemplateRejection(
  BuildContext context,
  MixTemplateRejection? rejection,
) => switch (rejection) {
  null => null,
  MixTemplateRejection.invalid =>
    context.l10n.gasCalculators_blender_templateInvalid,
  MixTemplateRejection.duplicate =>
    context.l10n.gasCalculators_blender_templateExists,
  MixTemplateRejection.limitReached =>
    context.l10n.gasCalculators_blender_templateLimit(
      BlenderPreferences.maxTemplates,
    ),
};
