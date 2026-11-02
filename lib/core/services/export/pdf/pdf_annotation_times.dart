import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/annotation_links.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';

const _log = LoggerService('PdfAnnotationTimes');

/// Each dive's annotation id to its m:ss (#4109), so a linked passage in a
/// PDF's notes prints its time. Reads the events only of dives whose Notes
/// can link one, once for the whole export. The time is a courtesy after the
/// words, so a failed read prints the words alone rather than failing the
/// export.
Future<Map<String, Map<String, String>>> annotationTimesForPdf(
  List<Dive> dives, {
  DiveComputerRepository? repository,
}) async {
  final linked = [
    for (final dive in dives)
      if (mayLinkAnnotations(dive.notes)) dive,
  ];
  if (linked.isEmpty) return const {};
  try {
    final rows = await (repository ?? DiveComputerRepository())
        .getEventsForDives([for (final dive in linked) dive.id]);
    return {
      for (final dive in linked)
        if (rows[dive.id] case final events?)
          dive.id: annotationTimesOf(
            dropOrphanAnnotations(
              events.map(mapDiveProfileEventToProfileEvent).toList(),
              dive.notes,
            ),
          ),
    };
  } catch (e, stackTrace) {
    _log.warning(
      'Annotation times left out of the PDF',
      error: e,
      stackTrace: stackTrace,
    );
    return const {};
  }
}
