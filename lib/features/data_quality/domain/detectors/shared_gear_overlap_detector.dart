import 'package:submersion/features/data_quality/domain/detectors/quality_detector.dart';
import 'package:submersion/features/data_quality/domain/entities/dive_quality_context.dart';
import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';
import 'package:submersion/features/data_quality/domain/services/shared_gear_overlap_rules.dart';

/// The same item on two different profiles' dives at the same time (issue
/// #2853), usually the wrong mask or light picked on one of them.
/// Informational: pooled weights or a "2x pouches" item can legitimately be
/// on two divers at once, so nothing is blocked.
///
/// One finding per topmost matched item per pair of dives: installed parts
/// and assembly components fold into their host's finding. The finding is
/// anchored on the smaller dive id and its params list both dives in
/// ascending id order, so scanning either side writes the same row (the
/// findings repository compares params as JSON).
class SharedGearOverlapDetector extends QualityDetector {
  const SharedGearOverlapDetector();

  @override
  String get id => 'shared_gear_overlap';
  @override
  int get version => 1;
  @override
  QualityCategory get category => QualityCategory.time;

  @override
  List<QualityFinding> detect(DiveQualityContext ctx) {
    final entry = ctx.dive.effectiveEntryTime;
    final exit = sharedGearExit(
      entry: entry,
      exit: ctx.dive.exitTime,
      runtime: ctx.dive.runtime,
      bottomTime: ctx.dive.bottomTime,
    );
    if (exit == null) return const [];
    final out = <QualityFinding>[];
    for (final o in ctx.sharedGearOverlaps) {
      final otherExit = o.otherExit;
      if (otherExit == null) continue;
      if (!gearUseOverlaps(
        aStart: entry,
        aEnd: exit,
        bStart: o.otherEntry,
        bEnd: otherExit,
      )) {
        continue;
      }
      final byId = {for (final i in o.items) i.equipmentId: i};
      final folded = foldToTopmost({
        for (final i in o.items) i.equipmentId: i.hostIds,
      });
      final tops = folded.keys.toList()..sort();
      for (final top in tops) {
        final item = byId[top]!;
        final parts = {...folded[top]!, ...item.installedPartIds}.toList()
          ..sort();
        // A side can lose this setup only when every matched item of it is
        // on that dive by its gear list alone: a tank link left behind
        // would keep the overlap, and the rescan would reopen it.
        final setup = [item, for (final id in folded[top]!) byId[id]!];
        bool gearListOnly(Set<String> kinds) =>
            kinds.length == 1 && kinds.single == 'gearList';
        final sides = {
          ctx.dive.id: {
            'diverId': ctx.dive.diverId,
            'diverName': o.thisDiverName,
            'entryMs': entry.millisecondsSinceEpoch,
            'linkKinds': item.thisLinkKinds.toList()..sort(),
            'removable': setup.every((i) => gearListOnly(i.thisLinkKinds)),
          },
          o.otherDiveId: {
            'diverId': o.otherDiverId,
            'diverName': o.otherDiverName,
            'entryMs': o.otherEntry.millisecondsSinceEpoch,
            'linkKinds': item.otherLinkKinds.toList()..sort(),
            'removable': setup.every((i) => gearListOnly(i.otherLinkKinds)),
          },
        };
        final diveIds = sides.keys.toList()..sort();
        out.add(
          makePair(
            ctx,
            otherDiveId: o.otherDiveId,
            discriminator: top,
            severity: QualitySeverity.info,
            params: {
              'equipmentId': top,
              'itemName': item.name,
              'partIds': parts,
              // Ascending dive id, whichever side was scanned.
              'dives': {for (final id in diveIds) id: sides[id]},
            },
          ),
        );
      }
    }
    return out;
  }
}
