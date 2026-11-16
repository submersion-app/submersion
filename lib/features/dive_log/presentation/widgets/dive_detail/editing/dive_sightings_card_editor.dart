import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/sightings_editor.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Sightings card's editor: the dive form's sightings editor over the
/// sitting's sightings, suggesting from the site the sitting has.
///
/// A species created from the picker exists at once and outlives a
/// cancelled sitting; only which sightings the dive has is held until Save.
class DiveSightingsCardEditor extends StatefulWidget {
  const DiveSightingsCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  State<DiveSightingsCardEditor> createState() =>
      _DiveSightingsCardEditorState();
}

class _DiveSightingsCardEditorState extends State<DiveSightingsCardEditor> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DiveSightingsCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _load();
  }

  /// Reads the sightings again while the diver has not changed them, and
  /// draws them once they are in.
  void _load() {
    diveSightingsList.load(widget.session).then((_) {
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
        final current = diveSightingsList.current(session);
        if (current == null && diveSightingsList.failed(session)) {
          return SittingLoadFailed(onRetry: _retry);
        }
        if (current == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final site = session.working.site;
        return SightingsEditor(
          sightings: current,
          onChanged: (sightings) => diveSightingsList.set(session, sightings),
          diveId: session.stored.id,
          // The site the sitting has, which the header may have changed.
          siteId: site?.id,
          siteName: site?.name,
          excludeDiveId: session.stored.id,
          showTitle: false,
        );
      },
    );
  }
}
