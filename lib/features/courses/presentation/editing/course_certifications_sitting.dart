import 'dart:async';

import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_multi_select_field.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_ids.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

/// The certifications a course earned, held in its page's sitting (issue
/// #4527, phase 3). Written at Save through `setCourseCertifications`, which
/// moves a certification off another course and recomputes both courses'
/// representative, in the sitting's one entry. Only the sitting's own
/// difference is applied to the set as stored then, so a certification
/// linked meanwhile on another device stays linked.
final courseCertificationsList = SittingList<Course, Certification>(
  key: 'course.certifications',
  cardId: CourseCardId.earnedCertifications.name,
  read: (c) => CertificationRepository().getCertificationsForCourse(c.id),
  write: (c, loaded, current) async {
    final stored = await CertificationRepository().getCertificationIdsForCourse(
      c.id,
    );
    await CourseRepository().setCourseCertifications(
      c.id,
      earnedCertificationIdsAtSave(
        stored: stored,
        loaded: [for (final cert in loaded) cert.id],
        current: [for (final cert in current) cert.id],
      ),
    );
    // Whether any link changed is not told.
    return null;
  },
  same: (a, b) => sameIdSets(a, b, (cert) => cert.id),
);

/// The ids a course earns at Save: those [stored] then, less the ones the
/// sitting removed from what it [loaded], plus its [current] ones.
List<String> earnedCertificationIdsAtSave({
  required List<String> stored,
  required List<String> loaded,
  required List<String> current,
}) {
  final kept = current.toSet();
  final removed = loaded.where((id) => !kept.contains(id)).toSet();
  return {
    for (final id in stored)
      if (!removed.contains(id)) id,
    ...current,
  }.toList();
}

/// The Earned certifications card's editor: which certifications the
/// course earned, ticked in the sheet the form used. Inert until the
/// sitting has read them, so nothing starts empty and unlinks them all; it
/// draws the list once the read answers.
class CourseEarnedCertificationsEditor extends ConsumerStatefulWidget {
  const CourseEarnedCertificationsEditor({super.key, required this.session});

  final EditSession<Course> session;

  @override
  ConsumerState<CourseEarnedCertificationsEditor> createState() =>
      _CourseEarnedCertificationsEditorState();
}

class _CourseEarnedCertificationsEditorState
    extends ConsumerState<CourseEarnedCertificationsEditor> {
  EditSession<Course> get _session => widget.session;

  @override
  void initState() {
    super.initState();
    // The read the sitting asked for, or one of its own when none was.
    unawaited(courseCertificationsList.currentOrRead(_session));
  }

  @override
  Widget build(BuildContext context) {
    final all =
        ref.watch(certificationListNotifierProvider).value ??
        const <Certification>[];
    return ListenableBuilder(
      listenable: courseCertificationsList.changes(_session),
      builder: (context, _) {
        final current = courseCertificationsList.current(_session);
        if (current == null) {
          if (courseCertificationsList.failed(_session)) {
            return SittingLoadFailed(
              onRetry: () => courseCertificationsList.load(_session),
            );
          }
          return const LinearProgressIndicator();
        }
        final theme = Theme.of(context);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.courses_field_linkCertificationsHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            CertificationMultiSelectField(
              courseId: _session.stored.id,
              selectedCertificationIds: [for (final c in current) c.id],
              onChanged: (ids) {
                if (_session.isDisposed || !mounted) return;
                // Read as the sheet reports, not as the field was built:
                // a certification created from the sheet (#4809) is only
                // in the list read since.
                final byId = {
                  for (final c
                      in courseCertificationsList.current(_session) ?? current)
                    c.id: c,
                  for (final c
                      in ref.read(certificationListNotifierProvider).value ??
                          all)
                    c.id: c,
                };
                courseCertificationsList.set(_session, [
                  for (final id in ids) ?byId[id],
                ]);
              },
            ),
          ],
        );
      },
    );
  }
}
