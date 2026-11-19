import 'package:flutter/material.dart';

import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_editors.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_card_ids.dart';
import 'package:submersion/features/certifications/presentation/editing/certification_edit_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Edits one of a buddy's certifications in a dialog (issue #4527, phase
/// 3), with the certification page's own card editors over a sitting of its
/// own on [initial]. Done returns the certification as edited, for the
/// buddy's sitting to hold until its Save; Cancel returns null, and
/// changes nothing. A certification with neither a title nor a level stays
/// open.
Future<Certification?> showBuddyCertificationDialog(
  BuildContext context, {
  required Certification initial,
}) => showDialog<Certification>(
  context: context,
  builder: (context) => _BuddyCertificationDialog(initial: initial),
);

class _BuddyCertificationDialog extends StatefulWidget {
  const _BuddyCertificationDialog({required this.initial});

  final Certification initial;

  @override
  State<_BuddyCertificationDialog> createState() =>
      _BuddyCertificationDialogState();
}

class _BuddyCertificationDialogState extends State<_BuddyCertificationDialog> {
  late final EditSession<Certification> _session = EditSession(widget.initial);

  @override
  void dispose() {
    _session.dispose();
    super.dispose();
  }

  void _done() {
    final edited = _session.applyTo(widget.initial);
    if (!certificationHasTitleOrLevel(edited)) return;
    Navigator.of(context).pop(edited);
  }

  Widget _section(String title, Widget editor) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        editor,
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    String title(CertificationCardId id) => id.localizedDisplayName(l10n);
    return AlertDialog(
      title: Text(
        widget.initial.name.isEmpty && widget.initial.level == null
            ? l10n.buddies_action_addCertification
            : l10n.buddies_section_certifications,
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _section(
                title(CertificationCardId.details),
                CertificationDetailsCardEditor(session: _session),
              ),
              _section(
                title(CertificationCardId.dates),
                CertificationDatesCardEditor(session: _session),
              ),
              _section(
                title(CertificationCardId.instructor),
                CertificationInstructorCardEditor(session: _session),
              ),
              _section(
                title(CertificationCardId.cardPhotos),
                CertificationCardPhotosEditor(session: _session),
              ),
              _section(
                title(CertificationCardId.notes),
                CertificationNotesCardEditor(
                  session: _session,
                  autofocus: false,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('buddy-cert-dialog-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        ListenableBuilder(
          listenable: _session,
          builder: (context, _) => FilledButton(
            key: const ValueKey('buddy-cert-dialog-done'),
            onPressed: certificationHasTitleOrLevel(_session.working)
                ? _done
                : null,
            child: Text(l10n.common_action_done),
          ),
        ),
      ],
    );
  }
}
