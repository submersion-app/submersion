import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';

/// Why [check] may not set a dive's Notes, or null (#4815). The apply keeps
/// the dive's annotations in step with the Notes it writes, and reads every
/// annotation whose link no longer reads as one as removed, so Notes that
/// damage a link (a bracket, a parenthesis or part of its id deleted, or
/// its id changed) would delete that annotation. Deleting a link whole,
/// address and all, still removes it; that is planned, and the plan's reach
/// shows the annotation going.
Future<PlanBlock?> annotationLinksProblem(
  AnnotationRepository annotations,
  WriteCheck check,
) async {
  final id = check.id;
  final notes = check.values['notes'];
  if (id == null || notes is! String) return null;
  final stored = check.document?['notes'] as String? ?? '';
  if (notes == stored) return null;
  final held = await annotations.annotationsForDive(id);
  if (held.isEmpty) return null;
  final damaged = AnnotationLinkBaseline.of(
    stored,
  ).damagedBy(notes, {for (final a in held) a.id});
  if (damaged.isEmpty) return null;
  final named = [
    for (final a in held)
      if (damaged.contains(a.id))
        '"${a.description ?? ''}" ($annotationLinkScheme:${a.id})',
  ];
  return PlanBlock(
    BlockReason.invalidValue,
    'notes: the link of annotation ${named.join(', ')} is damaged, so this '
    'change would delete the annotation. Keep each link whole as '
    '[words]($annotationLinkScheme:id), or remove the link whole, address '
    'and all, to delete the annotation.',
  );
}
