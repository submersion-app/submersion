import 'package:flutter/widgets.dart';

import 'package:submersion/features/dive_log/domain/services/source_name_resolver.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Localized source-name fallbacks, for [resolveSourceName].
SourceNameLabels sourceNameLabelsFor(BuildContext context) {
  return SourceNameLabels(
    unknownComputer: context.l10n.diveLog_sources_unknownComputer,
    manualEntry: context.l10n.diveLog_sources_manualEntry,
    importedFile: context.l10n.diveLog_sources_importedFile,
    editedSuffix: context.l10n.diveLog_sources_editedSuffix,
  );
}
