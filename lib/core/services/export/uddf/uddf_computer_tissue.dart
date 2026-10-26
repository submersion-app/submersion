import 'package:xml/xml.dart';

import 'package:submersion/features/dive_log/domain/entities/computer_tissue_legacy_scalars.dart';
import 'package:submersion/features/dive_log/domain/entities/computer_tissue_snapshot.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// One dive's computer-reported tissue data as the private block holds it.
/// [legacy] is the CNS, OTU and deco model a snapshot written before issue
/// #2555 carried, null when it carried none.
typedef UddfDiveTissue = ({
  ComputerTissueSnapshot? snapshot,
  Map<int, int> n2LoadByTime,
  LegacyTissueScalars? legacy,
});

/// The tissue state a dive computer reported, in UDDF (issue #2557).
///
/// UDDF has no element for the dive-level snapshot (`Dive.computerTissue`)
/// or for a sample's aggregate N2 load (`DiveProfilePoint.n2Load`, Garmin
/// FIT `n2_load`). Both writers put them in the private
/// `<applicationdata><submersion><computertissue>` block, one `<dive ref>`
/// per dive that has either, so the waypoints stay standard:
///
/// ```xml
/// <computertissue>
///   <dive ref="dive_ID">
///     <snapshot>{"start":{...},"end":{...}}</snapshot>
///     <n2load>0:12 60:34</n2load>
///   </dive>
/// </computertissue>
/// ```
///
/// `<snapshot>` holds the same JSON the `dives.computer_tissue_json` column
/// stores. `<n2load>` holds space separated `divetime:percent` pairs, keyed
/// by the waypoint `<divetime>` in seconds.
///
/// The dive map keys this produces are the ones every importer sets and
/// `UddfEntityImporter` reads: `computerTissue` on the dive and `n2Load` on
/// each profile sample.
abstract final class UddfComputerTissue {
  static const sectionName = 'computertissue';

  static const _snapshotElement = 'snapshot';
  static const _n2LoadElement = 'n2load';

  /// Whether [dive] has anything for the block to carry.
  static bool hasData(Dive dive) =>
      dive.computerTissue != null || dive.profile.any((p) => p.n2Load != null);

  /// Writes the block for the [dives] that have data; writes nothing when
  /// none has.
  static void write(XmlBuilder builder, Iterable<Dive> dives) {
    final withData = dives.where(hasData).toList();
    if (withData.isEmpty) return;
    builder.element(
      sectionName,
      nest: () {
        for (final dive in withData) {
          builder.element(
            'dive',
            attributes: {'ref': 'dive_${dive.id}'},
            nest: () {
              final snapshot = dive.computerTissue;
              if (snapshot != null) {
                builder.element(_snapshotElement, nest: snapshot.encode());
              }
              final pairs = [
                for (final point in dive.profile)
                  if (point.n2Load case final load?) '${point.timestamp}:$load',
              ];
              if (pairs.isNotEmpty) {
                builder.element(_n2LoadElement, nest: pairs.join(' '));
              }
            },
          );
        }
      },
    );
  }

  /// Reads the block: per dive ref, the snapshot and the N2 load by dive
  /// time, and the dive-level values an older snapshot carried. An
  /// unreadable snapshot or pair is dropped on its own; a dive left with
  /// none of them is skipped.
  static Map<String, UddfDiveTissue> parse(XmlElement block) {
    final byDive = <String, UddfDiveTissue>{};
    for (final dive in block.findElements('dive')) {
      final ref = dive.getAttribute('ref');
      if (ref == null || ref.isEmpty) continue;
      final json = _snapshotJson(dive.getElement(_snapshotElement)?.innerText);
      final decoded = json == null
          ? null
          : ComputerTissueSnapshot.fromJson(json);
      final snapshot = decoded?.start == null && decoded?.end == null
          ? null
          : decoded;
      final scalars = json == null ? null : LegacyTissueScalars.of(json);
      final legacy = scalars == null || scalars.isEmpty ? null : scalars;
      final n2LoadByTime = _n2Loads(dive.getElement(_n2LoadElement)?.innerText);
      if (snapshot == null && n2LoadByTime.isEmpty && legacy == null) {
        continue;
      }
      byDive[ref] = (
        snapshot: snapshot,
        n2LoadByTime: n2LoadByTime,
        legacy: legacy,
      );
    }
    return byDive;
  }

  /// The snapshot element's JSON object, or null when it is absent, blank
  /// or not a JSON object.
  static Map<String, dynamic>? _snapshotJson(String? text) {
    try {
      return ComputerTissueSnapshot.decodeObject(text);
    } on FormatException {
      return null;
    }
  }

  static Map<int, int> _n2Loads(String? text) {
    if (text == null) return const {};
    final loads = <int, int>{};
    for (final pair in text.trim().split(RegExp(r'\s+'))) {
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      final time = int.tryParse(parts[0]);
      final load = int.tryParse(parts[1]);
      if (time != null && load != null) loads[time] = load;
    }
    return loads;
  }

  /// Puts [data] on the parsed [dive] map: the snapshot under
  /// `computerTissue`, each N2 load on the profile samples at its dive
  /// time, and an older snapshot's dive-level values under the keys every
  /// importer sets for them (`cnsStart`, `cnsEnd`, `otu`, `decoAlgorithm`),
  /// each only where the file gave the dive none. Samples with no N2 load
  /// carry no key.
  static void apply(Map<String, dynamic> dive, UddfDiveTissue data) {
    if (data.snapshot case final snapshot?) {
      dive['computerTissue'] = snapshot;
    }
    if (data.legacy case final legacy?) {
      void fill(String key, Object? value) {
        if (value != null && dive[key] == null) dive[key] = value;
      }

      fill('cnsStart', legacy.cnsStart);
      fill('cnsEnd', legacy.cnsEnd);
      fill('otu', legacy.otu);
      fill('decoAlgorithm', legacy.algorithm);
    }
    if (data.n2LoadByTime.isEmpty) return;
    final profile = dive['profile'];
    if (profile is! List) return;
    for (final point in profile) {
      if (point is! Map<String, dynamic>) continue;
      final load = data.n2LoadByTime[point['timestamp']];
      if (load != null) point['n2Load'] = load;
    }
  }
}
