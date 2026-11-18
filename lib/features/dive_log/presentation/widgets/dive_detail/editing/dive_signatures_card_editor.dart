import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_signature_section.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_signatures_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Signatures card's editor: the read card's own signatures, with
/// capture, request and delete going to the sitting.
///
/// The training signature is offered while the sitting has a course, and a
/// buddy can be asked to sign while the sitting has them on the dive, a
/// buddy added in this sitting included (their record exists already).
class DiveSignaturesCardEditor extends StatefulWidget {
  const DiveSignaturesCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  State<DiveSignaturesCardEditor> createState() =>
      _DiveSignaturesCardEditorState();
}

class _DiveSignaturesCardEditorState extends State<DiveSignaturesCardEditor> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DiveSignaturesCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _load();
  }

  void _load() {
    final session = widget.session;
    Future.wait([
      diveBuddiesList.load(session),
      diveSignaturesList.load(session),
    ]).then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Reads again after a read that failed, waiting with a spinner.
  void _retry() {
    _load();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final buddies = diveBuddiesList.current(session);
        final signatures = diveSignaturesList.current(session);
        if ((buddies == null && diveBuddiesList.failed(session)) ||
            (signatures == null && diveSignaturesList.failed(session))) {
          return SittingLoadFailed(onRetry: _retry);
        }
        if (buddies == null || signatures == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return DiveSignaturesSection(dive: session.working, editing: session);
      },
    );
  }
}
