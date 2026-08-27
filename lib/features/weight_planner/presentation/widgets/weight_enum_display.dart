import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized display names for the weight-placement enum.
///
/// The `displayName` field on [WeightType] stays English on purpose: it feeds
/// data interchange (CSV/Excel export, the field extractor) where a stable,
/// locale-independent value is wanted. This getter drives on-screen UI -- the
/// weight planner's suggested-placement rows -- so those values honor the
/// active locale, matching `environment_enum_display.dart`.
///
/// The switch is exhaustive by enum value, so adding a new value is a compile
/// error until its localization key is wired in.
extension WeightTypeDisplay on WeightType {
  String localizedName(AppLocalizations l10n) => switch (this) {
    WeightType.belt => l10n.enum_weightType_belt,
    WeightType.integrated => l10n.enum_weightType_integrated,
    WeightType.ankleWeights => l10n.enum_weightType_ankleWeights,
    WeightType.trimWeights => l10n.enum_weightType_trimWeights,
    WeightType.backplate => l10n.enum_weightType_backplate,
    WeightType.mixed => l10n.enum_weightType_mixed,
  };
}
