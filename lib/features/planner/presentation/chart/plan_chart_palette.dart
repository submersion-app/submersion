import 'package:flutter/material.dart';

/// Theme-derived colors for the plan profile chart. Every color comes from
/// the active [ColorScheme] so all theme presets, light and dark, render
/// coherently (no hard-coded values).
class PlanChartPalette {
  final Color backdrop;
  final Color gridLine;
  final Color axisLabel;
  final Color profileLine;
  final Color profileFillTop;
  final Color profileFillBottom;
  final Color ceilingLine;
  final Color ceilingFill;
  final Color meanDepthLine;
  final Color gasFlag;
  final Color gasFlagBackground;
  final Color stopTagBackground;
  final Color stopTagBorder;
  final Color stopTagText;
  final Color ghostLine;
  final Color scrubCursor;
  final Color readoutBackground;
  final Color readoutBorder;
  final Color readoutText;

  const PlanChartPalette({
    required this.backdrop,
    required this.gridLine,
    required this.axisLabel,
    required this.profileLine,
    required this.profileFillTop,
    required this.profileFillBottom,
    required this.ceilingLine,
    required this.ceilingFill,
    required this.meanDepthLine,
    required this.gasFlag,
    required this.gasFlagBackground,
    required this.stopTagBackground,
    required this.stopTagBorder,
    required this.stopTagText,
    required this.ghostLine,
    required this.scrubCursor,
    required this.readoutBackground,
    required this.readoutBorder,
    required this.readoutText,
  });

  factory PlanChartPalette.of(ThemeData theme) {
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    Color tint(Color base, Color over, double amount) =>
        Color.alphaBlend(over.withValues(alpha: amount), base);
    return PlanChartPalette(
      backdrop: dark
          ? tint(scheme.surfaceContainerLowest, scheme.primary, 0.04)
          : tint(scheme.surfaceContainerLow, scheme.primary, 0.03),
      gridLine: scheme.outline.withValues(alpha: dark ? 0.14 : 0.18),
      axisLabel: scheme.onSurfaceVariant.withValues(alpha: 0.8),
      // Lerp toward onSurface brightens in dark themes and is a no-op in
      // light themes - stays in the primary family either way.
      profileLine: dark
          ? Color.lerp(scheme.primary, scheme.onSurface, 0.25)!
          : scheme.primary,
      profileFillTop: scheme.primary.withValues(alpha: 0.02),
      profileFillBottom: scheme.primary.withValues(alpha: dark ? 0.30 : 0.18),
      ceilingLine: scheme.error.withValues(alpha: 0.75),
      ceilingFill: scheme.error.withValues(alpha: 0.07),
      meanDepthLine: scheme.outline.withValues(alpha: 0.5),
      gasFlag: scheme.tertiary,
      gasFlagBackground: tint(scheme.surface, scheme.tertiary, 0.18),
      stopTagBackground: tint(scheme.surface, scheme.primary, 0.10),
      stopTagBorder: scheme.primary.withValues(alpha: 0.45),
      stopTagText: Color.lerp(scheme.primary, scheme.onSurface, 0.45)!,
      ghostLine: scheme.outline.withValues(alpha: 0.6),
      scrubCursor: scheme.onSurfaceVariant,
      readoutBackground: scheme.surfaceContainerHighest.withValues(alpha: 0.95),
      readoutBorder: scheme.outline.withValues(alpha: 0.3),
      readoutText: scheme.onSurface,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlanChartPalette &&
      other.backdrop == backdrop &&
      other.gridLine == gridLine &&
      other.axisLabel == axisLabel &&
      other.profileLine == profileLine &&
      other.profileFillTop == profileFillTop &&
      other.profileFillBottom == profileFillBottom &&
      other.ceilingLine == ceilingLine &&
      other.ceilingFill == ceilingFill &&
      other.meanDepthLine == meanDepthLine &&
      other.gasFlag == gasFlag &&
      other.gasFlagBackground == gasFlagBackground &&
      other.stopTagBackground == stopTagBackground &&
      other.stopTagBorder == stopTagBorder &&
      other.stopTagText == stopTagText &&
      other.ghostLine == ghostLine &&
      other.scrubCursor == scrubCursor &&
      other.readoutBackground == readoutBackground &&
      other.readoutBorder == readoutBorder &&
      other.readoutText == readoutText;

  @override
  int get hashCode => Object.hashAll([
    backdrop,
    gridLine,
    axisLabel,
    profileLine,
    profileFillTop,
    profileFillBottom,
    ceilingLine,
    ceilingFill,
    meanDepthLine,
    gasFlag,
    gasFlagBackground,
    stopTagBackground,
    stopTagBorder,
    stopTagText,
    ghostLine,
    scrubCursor,
    readoutBackground,
    readoutBorder,
    readoutText,
  ]);
}
