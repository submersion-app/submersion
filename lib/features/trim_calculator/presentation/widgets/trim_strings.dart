import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/weight_planner/presentation/widgets/weight_enum_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The trim figure's words (issue #5028).
extension TrimVerdictText on TrimVerdict {
  String label(AppLocalizations l10n) => switch (this) {
    TrimVerdict.level => l10n.trim_verdict_level,
    TrimVerdict.slightlyFeetHeavy => l10n.trim_verdict_slightlyFeetHeavy,
    TrimVerdict.feetHeavy => l10n.trim_verdict_feetHeavy,
    TrimVerdict.slightlyHeadHeavy => l10n.trim_verdict_slightlyHeadHeavy,
    TrimVerdict.headHeavy => l10n.trim_verdict_headHeavy,
  };
}

extension RollVerdictText on RollVerdict {
  /// Null when there is no roll worth naming.
  String? phrase(AppLocalizations l10n) => switch (this) {
    RollVerdict.level => null,
    RollVerdict.slightlyLeft => l10n.trim_roll_slightlyLeft,
    RollVerdict.left => l10n.trim_roll_left,
    RollVerdict.slightlyRight => l10n.trim_roll_slightlyRight,
    RollVerdict.right => l10n.trim_roll_right,
  };
}

/// "Slightly feet-heavy, rolls right", or the pitch alone.
String trimVerdictLine(TrimResult result, AppLocalizations l10n) {
  final pitch = result.pitch.label(l10n);
  final roll = result.roll.phrase(l10n);
  return roll == null ? pitch : l10n.trim_verdictLine(pitch, roll);
}

extension TrimSpotName on TrimSpot {
  String label(AppLocalizations l10n) => switch (this) {
    TrimSpot.head => l10n.trim_spot_head,
    TrimSpot.mouth => l10n.trim_spot_mouth,
    TrimSpot.chest => l10n.trim_spot_chest,
    TrimSpot.chestClip => l10n.trim_spot_chestClip,
    TrimSpot.upperBack => l10n.trim_spot_upperBack,
    TrimSpot.backTank => l10n.trim_spot_backTank,
    TrimSpot.wing => l10n.trim_spot_wing,
    TrimSpot.trimPockets => l10n.trim_spot_trimPockets,
    TrimSpot.backplate => l10n.trim_spot_backplate,
    TrimSpot.buttDRing => l10n.trim_spot_buttDRing,
    TrimSpot.waist => l10n.trim_spot_waist,
    TrimSpot.hipPockets => l10n.trim_spot_hipPockets,
    TrimSpot.sidemount => l10n.trim_spot_sidemount,
    TrimSpot.stageClip => l10n.trim_spot_stageClip,
    TrimSpot.console => l10n.trim_spot_console,
    TrimSpot.thigh => l10n.trim_spot_thigh,
    TrimSpot.calf => l10n.trim_spot_calf,
    TrimSpot.ankles => l10n.trim_spot_ankles,
    TrimSpot.feet => l10n.trim_spot_feet,
    TrimSpot.fins => l10n.trim_spot_fins,
    TrimSpot.hand => l10n.trim_spot_hand,
    TrimSpot.wrist => l10n.trim_spot_wrist,
    TrimSpot.cameraArm => l10n.trim_spot_cameraArm,
    TrimSpot.floatPoint => l10n.trim_spot_floatPoint,
  };
}

/// An element's name: the diver's label, else a weight's placement, else
/// "Test item", else where it sits.
String trimElementName(TrimElement e, AppLocalizations l10n) {
  if (e.label.trim().isNotEmpty) return e.label.trim();
  if (e.weightType case final type?) return type.localizedName(l10n);
  if (e.kind == TrimElementKind.test) return l10n.trim_testItem;
  return trimSpotLabelFor(e, l10n);
}

/// A suit or layer drawn over the body: its lift is spread along it. Other
/// float-point elements (hoses, tools, bags) simply have no spot.
bool trimIsSpreadOverBody(TrimElement e) =>
    e.spot == TrimSpot.floatPoint && e.pieceIds.isNotEmpty;

/// Where [e] sits, in words.
String trimSpotLabelFor(TrimElement e, AppLocalizations l10n) =>
    e.spot == TrimSpot.floatPoint && !trimIsSpreadOverBody(e)
    ? l10n.trim_spot_noSpot
    : e.spot.label(l10n);

/// "L" or "R" for an element on one side of a sided spot, else empty.
String trimSideMark(TrimElement e, AppLocalizations l10n) {
  if (!e.spot.sided) return '';
  return switch (e.lateral) {
    TrimLateral.left => l10n.trim_chip_left,
    TrimLateral.right => l10n.trim_chip_right,
    TrimLateral.centre => '',
  };
}

/// [kg] as it is shown: a weight too small to print reads as 0, never as
/// minus zero.
double trimShownKg(double kg) => kg.abs() < 0.05 ? 0 : kg;

/// A slide along the body, [metres] either way: whole centimetres, or with
/// feet for depth, inches to a tenth (a whole inch shows no decimal).
String formatTrimDistance(UnitFormatter units, double metres) {
  final m = metres.abs();
  if (units.settings.depthUnit == DepthUnit.feet) {
    final inches = (m / 0.0254 * 10).round() / 10;
    final whole = inches == inches.roundToDouble();
    return '${formatFixedForDisplay(inches, whole ? 0 : 1)} in';
  }
  return '${formatFixedForDisplay(m * 100, 0)} cm';
}

/// One pound, in kilograms.
const double kTrimPoundKg = 0.45359237;

/// The step lead moves in for this diver: half a kilo, or a pound.
double trimLeadStepKg(UnitFormatter units) =>
    units.settings.weightUnit == WeightUnit.pounds ? kTrimPoundKg : 0.5;

/// [kg] of lead in the diver's weight unit, with a decimal only when it is
/// not whole.
String formatTrimLead(UnitFormatter units, double kg) {
  final value =
      (WeightUnit.kilograms.convert(kg, units.settings.weightUnit) * 10)
          .round() /
      10;
  final whole = value == value.roundToDouble();
  return '${formatFixedForDisplay(value, whole ? 0 : 1)} '
      '${units.settings.weightUnit.symbol}';
}
