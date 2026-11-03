import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/constants/enums.dart' show ProfileEventType;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/dive_time_limit.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';

/// A dive's annotations, the only profile events a diver writes: an event a
/// dive computer recorded is left as it is, as the app leaves it. An
/// annotation's words live in the dive's Notes, so a create appends a linked
/// paragraph there and a delete turns the link back into plain words, through
/// the repository the dive page uses. Rewording one is a Notes edit.
class AnnotationWrites extends WritableEntry {
  AnnotationWrites(this._r, {AnnotationRepository? annotations})
    : _annotations = annotations ?? AnnotationRepository();

  final RecordRepositories _r;
  final AnnotationRepository _annotations;

  @override
  String get name => 'dive_events';

  @override
  String get table => 'dive_profile_events';

  @override
  ChildOf get parent => const ChildOf(entity: 'dives', field: 'dive_id');

  @override
  final Map<String, FieldCodec> fields = const {
    'dive_id': FieldCodec.reference('dives'),
    't_s': FieldCodec.integer(min: 0, max: 172800),
    'depth_m': FieldCodec.number(min: 0, max: 350, nullable: true),
    'description': FieldCodec.text(maxLength: 500),
  };

  @override
  Set<String> get requiredOnCreate => const {'t_s', 'description'};

  @override
  Set<String> get createOnly => const {'description'};

  @override
  Set<ChangeKind> get writesParent => const {
    ChangeKind.create,
    ChangeKind.delete,
  };

  @override
  Set<String> get parentFieldsWritten => const {'notes'};

  @override
  String get note =>
      'Annotations only: a create links its description in the dive\'s '
      'Notes, a delete turns the link back into plain words, and an event a '
      'dive computer recorded cannot be changed';

  @override
  String? titleOf(Map<String, Object?> document) =>
      document['description'] as String?;

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.create ||
        check.document?['type'] == ProfileEventType.annotation.name) {
      final diveId =
          (check.values['dive_id'] ?? check.document?['dive_id']) as String?;
      return beyondDive(_r, diveId, check.values);
    }
    return const PlanBlock(
      BlockReason.notPermitted,
      'A dive computer recorded this event, and the app does not change it. '
      'Only annotations can be changed.',
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) =>
      _annotations.addAnnotation(
        diveId: values['dive_id']! as String,
        timestamp: values['t_s']! as int,
        depth: values['depth_m'] as double?,
        words: values['description']! as String,
      );

  /// A move keeps what it does not name: the repository would clear a depth
  /// it is not given.
  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final current = await _row(id);
    final v = update.values;
    await _annotations.moveAnnotation(
      id: id,
      timestamp: v['t_s'] as int? ?? current.timestamp,
      depth: v.containsKey('depth_m') ? v['depth_m'] as double? : current.depth,
    );
  }

  @override
  Future<void> delete(String id, String? ownerId) async {
    final current = await _row(id);
    await _annotations.removeAnnotation(diveId: current.diveId, id: id);
  }

  Future<({String diveId, int timestamp, double? depth})> _row(
    String id,
  ) async {
    final row = await DatabaseService.instance.database
        .customSelect(
          'SELECT dive_id, timestamp, depth FROM dive_profile_events '
          'WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingleOrNull();
    if (row == null) {
      throw AgentToolException(
        AgentToolErrorCode.writeRefused,
        'Annotation $id no longer exists.',
        details: {'id': id},
      );
    }
    return (
      diveId: row.read<String>('dive_id'),
      timestamp: row.read<int>('timestamp'),
      depth: row.readNullable<double>('depth'),
    );
  }
}
