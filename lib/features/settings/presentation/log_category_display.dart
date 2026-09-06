import 'package:submersion/core/models/log_entry.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized label for [LogCategory], shown as filter chips on the debug log
/// viewer. [LogCategory.displayName] and [LogCategory.tag] stay English (they
/// are matched against stored log lines); this getter is UI only (issue #1608).
extension LogCategoryDisplay on LogCategory {
  String localizedName(AppLocalizations l10n) => switch (this) {
    LogCategory.app => l10n.enum_logCategory_app,
    LogCategory.bluetooth => l10n.enum_logCategory_bluetooth,
    LogCategory.serial => l10n.enum_logCategory_serial,
    LogCategory.libdc => l10n.enum_logCategory_libdc,
    LogCategory.database => l10n.enum_logCategory_database,
  };
}
