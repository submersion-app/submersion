import 'package:flutter/widgets.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

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
  }
}
