import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// One dive's Shearwater Avelo samples as the private block holds them, each
/// keyed by the waypoint `<divetime>` in seconds.
typedef UddfDiveAveloSamples = ({
  Map<int, double> buoyancyByTime,
  Map<int, int> gasRemainingByTime,
  Map<int, double> computerRmvByTime,
});

/// The values Shearwater's Avelo mode logs per sample, in UDDF (issue
/// #4664).
///
/// UDDF has no element for them, so they ride in the per-dive entry of the
/// private `<computertissue>` block (see `UddfComputerTissue`), beside the
/// N2 load and in the same `divetime:value` pair format:
///
/// ```xml
/// <dive ref="dive_ID">
///   <avelobuoyancy>0:-0.096 120:-0.393</avelobuoyancy>
///   <avelogasremaining>0:100 120:64</avelogasremaining>
///   <computerrmv>120:10.68</computerrmv>
/// </dive>
/// ```
///
/// Riding in that block reuses its place in both writers and in the
/// streamed export; a build that does not know these elements skips them.
/// The sample map keys this produces are the ones the libdivecomputer path
/// sets: `aveloBuoyancy`, `aveloGasRemaining`, `computerRmv`.
abstract final class UddfAveloSamples {
  static const _buoyancyElement = 'avelobuoyancy';
  static const _gasRemainingElement = 'avelogasremaining';
  static const _computerRmvElement = 'computerrmv';

  /// Whether [dive] has an Avelo value on any sample.
  static bool hasData(Dive dive) => dive.profile.any(
    (p) =>
        p.aveloBuoyancy != null ||
        p.aveloGasRemaining != null ||
        p.computerRmv != null,
  );

  /// Writes [dive]'s Avelo elements into the `<dive>` entry being built;
  /// writes nothing for a value no sample carries.
  static void writeChildren(XmlBuilder builder, Dive dive) {
    void pairs(String element, Object? Function(DiveProfilePoint) valueOf) {
      final text = [
        for (final point in dive.profile)
          if (valueOf(point) case final value?) '${point.timestamp}:$value',
      ];
      if (text.isNotEmpty) builder.element(element, nest: text.join(' '));
    }

    pairs(_buoyancyElement, (p) => p.aveloBuoyancy);
    pairs(_gasRemainingElement, (p) => p.aveloGasRemaining);
    pairs(_computerRmvElement, (p) => p.computerRmv);
  }

  /// Reads the Avelo elements of every `<dive ref>` in [block], skipping a
  /// dive that has none. An unreadable pair is dropped on its own.
  static Map<String, UddfDiveAveloSamples> parse(XmlElement block) {
    final byDive = <String, UddfDiveAveloSamples>{};
    for (final dive in block.findElements('dive')) {
      final ref = dive.getAttribute('ref');
      if (ref == null || ref.isEmpty) continue;
      final samples = (
        buoyancyByTime: _pairs(
          dive.getElement(_buoyancyElement)?.innerText,
          double.tryParse,
        ),
        gasRemainingByTime: _pairs(
          dive.getElement(_gasRemainingElement)?.innerText,
          int.tryParse,
        ),
        computerRmvByTime: _pairs(
          dive.getElement(_computerRmvElement)?.innerText,
          double.tryParse,
        ),
      );
      if (samples.buoyancyByTime.isEmpty &&
          samples.gasRemainingByTime.isEmpty &&
          samples.computerRmvByTime.isEmpty) {
        continue;
      }
      byDive[ref] = samples;
    }
    return byDive;
  }

  static Map<int, T> _pairs<T>(String? text, T? Function(String) parse) {
    if (text == null) return const {};
    final values = <int, T>{};
    for (final pair in text.trim().split(RegExp(r'\s+'))) {
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      final time = int.tryParse(parts[0]);
      final value = parse(parts[1]);
      if (time != null && value != null) values[time] = value;
    }
    return values;
  }

  /// Puts [data] on the profile samples of the parsed [dive] map at their
  /// dive times. Samples with no value carry no key.
  static void apply(Map<String, dynamic> dive, UddfDiveAveloSamples data) {
    final profile = dive['profile'];
    if (profile is! List) return;
    for (final point in profile) {
      if (point is! Map<String, dynamic>) continue;
      final time = point['timestamp'];
      if (data.buoyancyByTime[time] case final value?) {
        point['aveloBuoyancy'] = value;
      }
      if (data.gasRemainingByTime[time] case final value?) {
        point['aveloGasRemaining'] = value;
      }
      if (data.computerRmvByTime[time] case final value?) {
        point['computerRmv'] = value;
      }
    }
  }
}
