import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Localized labels for [SiteDifficulty]. The enum's own `displayName`
/// stays English on purpose (exports, stored configs); UI goes through this.
extension SiteDifficultyDisplay on SiteDifficulty {
  String localizedName(AppLocalizations l10n) => switch (this) {
    SiteDifficulty.beginner => l10n.diveSites_difficulty_beginner,
    SiteDifficulty.intermediate => l10n.diveSites_difficulty_intermediate,
    SiteDifficulty.advanced => l10n.diveSites_difficulty_advanced,
    SiteDifficulty.technical => l10n.diveSites_difficulty_technical,
  };
}
