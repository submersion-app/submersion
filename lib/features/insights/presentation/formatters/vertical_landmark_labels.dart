import 'package:submersion/features/insights/domain/vertical_distance/vertical_landmarks.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A landmark's localized name, or "n × name" for a multiple (issue #4569).
String verticalLandmarkName(AppLocalizations l10n, VerticalLandmark landmark) {
  final name = _name(l10n, landmark.id);
  return landmark.multiple == 1
      ? name
      : l10n.insights_profile_verticalDistance_multiple(
          landmark.multiple,
          name,
        );
}

/// Exhaustive with no default, so a landmark added without a name does not
/// compile.
String _name(AppLocalizations l10n, VerticalLandmarkId id) => switch (id) {
  VerticalLandmarkId.statueOfLiberty => l10n.insights_landmark_statueOfLiberty,
  VerticalLandmarkId.greatPyramid => l10n.insights_landmark_greatPyramid,
  VerticalLandmarkId.eiffelTower => l10n.insights_landmark_eiffelTower,
  VerticalLandmarkId.empireStateBuilding =>
    l10n.insights_landmark_empireStateBuilding,
  VerticalLandmarkId.burjKhalifa => l10n.insights_landmark_burjKhalifa,
  VerticalLandmarkId.benNevis => l10n.insights_landmark_benNevis,
  VerticalLandmarkId.mountKosciuszko => l10n.insights_landmark_mountKosciuszko,
  VerticalLandmarkId.mountFuji => l10n.insights_landmark_mountFuji,
  VerticalLandmarkId.matterhorn => l10n.insights_landmark_matterhorn,
  VerticalLandmarkId.montBlanc => l10n.insights_landmark_montBlanc,
  VerticalLandmarkId.kilimanjaro => l10n.insights_landmark_kilimanjaro,
  VerticalLandmarkId.denali => l10n.insights_landmark_denali,
  VerticalLandmarkId.aconcagua => l10n.insights_landmark_aconcagua,
  VerticalLandmarkId.k2 => l10n.insights_landmark_k2,
  VerticalLandmarkId.everest => l10n.insights_landmark_everest,
  VerticalLandmarkId.olympusMons => l10n.insights_landmark_olympusMons,
  VerticalLandmarkId.karmanLine => l10n.insights_landmark_karmanLine,
  VerticalLandmarkId.internationalSpaceStation =>
    l10n.insights_landmark_internationalSpaceStation,
  VerticalLandmarkId.recreationalLimit =>
    l10n.insights_landmark_recreationalLimit,
  VerticalLandmarkId.greatBlueHole => l10n.insights_landmark_greatBlueHole,
  VerticalLandmarkId.deansBlueHole => l10n.insights_landmark_deansBlueHole,
  VerticalLandmarkId.dragonHole => l10n.insights_landmark_dragonHole,
  VerticalLandmarkId.deepestScubaDive =>
    l10n.insights_landmark_deepestScubaDive,
  VerticalLandmarkId.craterLake => l10n.insights_landmark_craterLake,
  VerticalLandmarkId.lakeTanganyika => l10n.insights_landmark_lakeTanganyika,
  VerticalLandmarkId.lakeBaikal => l10n.insights_landmark_lakeBaikal,
  VerticalLandmarkId.deepestWhaleDive =>
    l10n.insights_landmark_deepestWhaleDive,
  VerticalLandmarkId.averageOceanDepth =>
    l10n.insights_landmark_averageOceanDepth,
  VerticalLandmarkId.titanic => l10n.insights_landmark_titanic,
  VerticalLandmarkId.bismarck => l10n.insights_landmark_bismarck,
  VerticalLandmarkId.molloyDeep => l10n.insights_landmark_molloyDeep,
  VerticalLandmarkId.deepestShipwreck =>
    l10n.insights_landmark_deepestShipwreck,
  VerticalLandmarkId.javaTrench => l10n.insights_landmark_javaTrench,
  VerticalLandmarkId.southSandwichTrench =>
    l10n.insights_landmark_southSandwichTrench,
  VerticalLandmarkId.puertoRicoTrench =>
    l10n.insights_landmark_puertoRicoTrench,
  VerticalLandmarkId.tongaTrench => l10n.insights_landmark_tongaTrench,
  VerticalLandmarkId.challengerDeep => l10n.insights_landmark_challengerDeep,
  VerticalLandmarkId.kolaBorehole => l10n.insights_landmark_kolaBorehole,
};
