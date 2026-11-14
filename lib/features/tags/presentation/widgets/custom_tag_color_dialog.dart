import 'package:flutter/material.dart';

import 'package:submersion/features/tags/presentation/widgets/tag_chip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/color_picker/custom_color_dialog.dart';

/// Opens the custom tag colour dialog on [initial] (issue #4384). Completes
/// with the chosen colour as `#RRGGBB` in capitals, or null when the diver
/// cancels or dismisses it. [name] labels the preview chip.
Future<String?> showCustomTagColorDialog(
  BuildContext context, {
  required Color initial,
  required String name,
}) {
  return showCustomColorDialog(
    context,
    initial: initial,
    title: context.l10n.common_color_custom,
    preview: (color) => TagChip.unsaved(name: name, color: color),
  );
}
