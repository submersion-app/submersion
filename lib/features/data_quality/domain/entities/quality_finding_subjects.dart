import 'package:submersion/features/data_quality/domain/entities/quality_finding.dart';

/// Detectors whose findings are about one tank (or a pair of them) of the
/// dive. Transmitter role findings name their tank in the message already.
const _tankDetectors = {'pressure_anomaly', 'tank_assignment'};

/// The data source a finding is about, from its `sourceId` param: the clock
/// offset and source conflict findings each judge one secondary source
/// against the primary (issue #4209).
String? findingSourceId(QualityFinding f) {
  final id = f.params['sourceId'];
  return id is String && id.isNotEmpty ? id : null;
}

/// The tanks a finding is about, in the order it names them: one tank for a
/// pressure or inactive-tank finding, both tanks for a twin pair.
List<String> findingTankIds(QualityFinding f) {
  if (!_tankDetectors.contains(f.detectorId)) return const [];
  return [
    for (final key in const ['tankId', 'tankIdA', 'tankIdB'])
      if (f.params[key] case final String id when id.isNotEmpty) id,
  ];
}

/// A tank as the dive shows it: its 1-based position among the dive's tanks
/// ordered by tank order, and its name when the diver gave it one.
class QualityTankRef {
  const QualityTankRef({required this.number, this.name});

  final int number;
  final String? name;

  QualityTankRef copyWith({int? number, String? name}) =>
      QualityTankRef(number: number ?? this.number, name: name ?? this.name);

  @override
  bool operator ==(Object other) =>
      other is QualityTankRef && other.number == number && other.name == name;

  @override
  int get hashCode => Object.hash(number, name);
}

/// Value-type provider key for the source ids [findings] name: sorted and
/// comma-joined, so equal id sets share one lookup instead of re-querying on
/// every rebuild. Empty when no finding names a source.
String qualitySourceIdsKey(Iterable<QualityFinding> findings) =>
    _idsKey({for (final f in findings) ?findingSourceId(f)});

/// Value-type provider key for the tank ids [findings] name, like
/// [qualitySourceIdsKey].
String qualityTankIdsKey(Iterable<QualityFinding> findings) =>
    _idsKey({for (final f in findings) ...findingTankIds(f)});

/// The ids a [qualitySourceIdsKey] or [qualityTankIdsKey] holds.
List<String> idsOfSubjectKey(String key) =>
    key.isEmpty ? const [] : key.split(',');

String _idsKey(Set<String> ids) => (ids.toList()..sort()).join(',');

/// Display data for the sources and tanks the inbox's findings name.
class QualityFindingSubjects {
  const QualityFindingSubjects({
    this.sourceLabels = const {},
    this.tanks = const {},
  });

  static const empty = QualityFindingSubjects();

  /// Source id to the name a diver knows the recording by: the saved
  /// computer's name, else the recorded model. Absent when neither is known.
  final Map<String, String> sourceLabels;

  /// Tank id to the tank's position and name.
  final Map<String, QualityTankRef> tanks;

  QualityFindingSubjects copyWith({
    Map<String, String>? sourceLabels,
    Map<String, QualityTankRef>? tanks,
  }) => QualityFindingSubjects(
    sourceLabels: sourceLabels ?? this.sourceLabels,
    tanks: tanks ?? this.tanks,
  );

  String? sourceLabelOf(QualityFinding f) {
    final id = findingSourceId(f);
    return id == null ? null : sourceLabels[id];
  }

  /// The tanks [f] names that still exist, in the finding's own order.
  List<QualityTankRef> tanksOf(QualityFinding f) => [
    for (final id in findingTankIds(f)) ?tanks[id],
  ];
}
