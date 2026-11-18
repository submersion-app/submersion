import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_load_failed.dart';

/// For a site card's editor whose rows are not columns of the site (issue
/// #4527, phase 2): reads them as the editor opens and again when it is
/// handed another sitting, and draws them once read, since keeping read
/// rows does not notify the sitting.
mixin SiteSittingLoadOnOpen<W extends StatefulWidget> on State<W> {
  /// The sitting [widget] edits.
  EditSession<DiveSite> sittingOf(W widget);

  /// Reads the editor's rows for [session], unless already changed there.
  Future<void> loadSitting(EditSession<DiveSite> session);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(W oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (sittingOf(oldWidget) != sittingOf(widget)) _load();
  }

  void _load() {
    loadSitting(sittingOf(widget)).then((_) {
      if (mounted) setState(() {});
    });
    // Drawn as being read (or read again) until it answers.
    if (mounted) setState(() {});
  }

  /// What the editor shows in place of its rows while [list] is not read
  /// for the sitting: a spinner while it is read, or, when the read failed,
  /// the failure with Try again, as the dive's cards show it. Null once the
  /// rows are in, so nothing the diver picks meanwhile is lost to a list
  /// that cannot take it yet.
  Widget? sittingListPending(SittingList<DiveSite, Object?> list) {
    final session = sittingOf(widget);
    if (list.failed(session)) return SittingLoadFailed(onRetry: _load);
    if (list.current(session) != null) return null;
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
