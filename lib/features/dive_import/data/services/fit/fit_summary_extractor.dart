import 'package:fit_tool/fit_tool.dart';

/// Dive-level fields gathered from the FIT summary/session/settings messages.
class FitSummary {
  FitSummary({
    this.diveNumber,
    this.bottomTime,
    this.surfaceInterval,
    this.cnsStart,
    this.cnsEnd,
    this.otu,
    this.entryLat,
    this.entryLong,
    this.waterType,
    this.decoModel,
    this.gfLow,
    this.gfHigh,
  });

  final int? diveNumber;
  final Duration? bottomTime;
  final Duration? surfaceInterval;
  final double? cnsStart;
  final double? cnsEnd;
  final double? otu;
  final double? entryLat; // degrees
  final double? entryLong; // degrees
  final String? waterType; // 'salt' | 'fresh' | ...
  final String? decoModel; // e.g. 'zhl_16c'
  final int? gfLow;
  final int? gfHigh;
}

/// Extracts dive-level fields from `dive_summary` (msg 268), `session` (msg 18)
/// and `dive_settings` (msg 258). GPS comes back from fit_tool already in
/// degrees (the field carries the semicircle scale), so it is passed through.
class FitSummaryExtractor {
  const FitSummaryExtractor._();

  static FitSummary extract({
    DiveSummaryMessage? summary,
    SessionMessage? session,
    DiveSettingsMessage? settings,
  }) {
    Duration? secs(num? v) => v == null ? null : Duration(seconds: v.round());
    final model = settings?.model;
    return FitSummary(
      diveNumber: summary?.diveNumber,
      bottomTime: secs(summary?.bottomTime),
      surfaceInterval: secs(summary?.surfaceInterval),
      cnsStart: summary?.startCns?.toDouble(),
      cnsEnd: summary?.endCns?.toDouble(),
      otu: summary?.o2Toxicity?.toDouble(),
      entryLat: session?.startPositionLat,
      entryLong: session?.startPositionLong,
      waterType: settings?.waterType?.name,
      decoModel: model == null
          ? null
          : (model == TissueModelType.zhl16c ? 'zhl_16c' : model.name),
      gfLow: settings?.gfLow,
      gfHigh: settings?.gfHigh,
    );
  }
}
