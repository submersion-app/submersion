import 'package:flutter/material.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/media/presentation/widgets/perdix_overlay/perdix_face_resolver.dart';

/// Perdix-style dive computer face. Pure presentation: renders one
/// [PerdixFaceData] snapshot with real-device layout and color conventions
/// (no Shearwater branding).
///
/// Layout mirrors the recreational Perdix screen: a large top row of
/// DEPTH | NDL | TIME, then MAX | TEMP | GAS, then TANK | CNS | PPO2. When
/// the sample carries a deco obligation the NDL cell becomes STOP (ceiling
/// rounded up to the next stop increment) and MAX becomes TTS, as on the
/// real device. Cells without data are omitted; empty rows collapse.
class PerdixFace extends StatelessWidget {
  const PerdixFace({
    super.key,
    required this.data,
    required this.settings,
    this.width = 300,
  });

  final PerdixFaceData data;
  final AppSettings settings;
  final double width;

  static const perdixGreen = Color(0xFF35D43C);
  static const perdixYellow = Color(0xFFFFD83A);
  static const perdixRed = Color(0xFFFF4A3A);
  static const perdixCyan = Color(0xFF9ADCF0);
  static const _panelColor = Color(0x8C000000); // black at 55% opacity

  @override
  Widget build(BuildContext context) {
    final units = UnitFormatter(settings);
    final rows = [
      _topRow(context, units),
      _middleRow(context, units),
      _bottomRow(context, units),
    ].where((cells) => cells.isNotEmpty).toList();

    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (final cell in rows[i]) Expanded(child: cell),
                for (var j = rows[i].length; j < 3; j++)
                  const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _topRow(BuildContext context, UnitFormatter units) {
    final l10n = context.l10n;
    final ndlSeconds = data.ndlSeconds;
    final ceiling = data.ceilingMeters;
    return [
      _cell(
        l10n.media_perdixOverlay_labelDepth,
        units.formatDepth(data.depthMeters ?? 0),
        Colors.white,
        large: true,
      ),
      if (data.inDeco && ceiling != null)
        _cell(
          l10n.media_perdixOverlay_labelStop,
          units.formatDepth(_stopDepthMeters(ceiling), decimals: 0),
          perdixRed,
          large: true,
        )
      else if (ndlSeconds != null)
        _cell(
          l10n.media_perdixOverlay_labelNdl,
          '${ndlSeconds ~/ 60}',
          _ndlColor(ndlSeconds),
          large: true,
        )
      else
        const SizedBox(),
      _cell(
        l10n.media_perdixOverlay_labelTime,
        _formatMinSec(data.diveTimeSeconds),
        Colors.white,
        large: true,
      ),
    ];
  }

  List<Widget> _middleRow(BuildContext context, UnitFormatter units) {
    final l10n = context.l10n;
    final tts = data.ttsSeconds;
    final runningMax = data.runningMaxDepthMeters;
    return [
      if (data.inDeco && tts != null)
        _cell(l10n.media_perdixOverlay_labelTts, '${tts ~/ 60}', Colors.white)
      else if (!data.inDeco && runningMax != null)
        _cell(
          l10n.media_perdixOverlay_labelMax,
          units.formatDepth(runningMax),
          Colors.white,
        ),
      if (data.temperatureCelsius != null)
        _cell(
          l10n.media_perdixOverlay_labelTemp,
          units.formatTemperature(data.temperatureCelsius),
          Colors.white,
        ),
      if (data.gasLabel != null)
        _cell(l10n.media_perdixOverlay_labelGas, data.gasLabel!, Colors.white),
    ];
  }

  List<Widget> _bottomRow(BuildContext context, UnitFormatter units) {
    final l10n = context.l10n;
    final cns = data.cnsPercent;
    final ppO2 = data.ppO2Bar;
    return [
      if (data.tankPressureBar != null)
        _cell(
          l10n.media_perdixOverlay_labelTank,
          units.formatPressure(data.tankPressureBar),
          Colors.white,
        ),
      if (cns != null)
        _cell(
          l10n.media_perdixOverlay_labelCns,
          '${cns.round()}%',
          _cnsColor(cns),
        ),
      if (ppO2 != null)
        _cell(
          l10n.media_perdixOverlay_labelPpo2,
          ppO2.toStringAsFixed(2),
          _ppO2Color(ppO2),
        ),
    ];
  }

  /// Ceiling rounded UP to the next stop increment: 3 m metric, 10 ft
  /// imperial (matching real-device stop conventions).
  double _stopDepthMeters(double ceilingMeters) {
    if (settings.depthUnit == DepthUnit.feet) {
      const feetPerMeter = 3.280839895;
      final stopFeet = (ceilingMeters * feetPerMeter / 10).ceil() * 10;
      return stopFeet / feetPerMeter;
    }
    return ((ceilingMeters / 3).ceil() * 3).toDouble();
  }

  Color _ndlColor(int seconds) {
    if (seconds <= 0) return perdixRed;
    if (seconds <= 5 * 60) return perdixYellow;
    return perdixGreen;
  }

  Color _ppO2Color(double bar) {
    if (bar >= 1.6) return perdixRed;
    if (bar >= 1.4) return perdixYellow;
    return Colors.white;
  }

  Color _cnsColor(double percent) {
    if (percent >= 80) return perdixRed;
    if (percent >= 50) return perdixYellow;
    return Colors.white;
  }

  static String _formatMinSec(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _cell(String label, String value, Color color, {bool large = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            letterSpacing: 0.5,
            color: perdixCyan,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: large ? 28 : 15,
            fontWeight: FontWeight.w700,
            height: 1.05,
            color: color,
          ),
        ),
      ],
    );
  }
}
