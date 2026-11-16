import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/dive_detail_profile_section.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// Hands the open Profile card the page's own profile section, whose
/// inputs (the export key, the page's scrolls, its source actions) only the
/// page has. The section list puts it around the Profile card's frame.
class DiveProfileEditorSource extends InheritedWidget {
  const DiveProfileEditorSource({
    super.key,
    required this.section,
    required super.child,
  });

  /// The page's profile section, or null for a dive drawn as an estimated
  /// outline, which has no chart to annotate.
  final DiveDetailProfileSection? section;

  static DiveDetailProfileSection? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DiveProfileEditorSource>()
      ?.section;

  @override
  bool updateShouldNotify(DiveProfileEditorSource oldWidget) =>
      section != oldWidget.section;
}

/// The Profile card's editor: the chart with its pin, placement and marker
/// actions writing to the sitting, held until Save (issue #4527, plan 6).
class DiveProfileCardEditor extends StatefulWidget {
  const DiveProfileCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  State<DiveProfileCardEditor> createState() => _DiveProfileCardEditorState();
}

class _DiveProfileCardEditorState extends State<DiveProfileCardEditor> {
  /// The chart's key, held so a rebuild (each change in the sitting) keeps
  /// the plot rather than mounting it again.
  final _exportKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final section = DiveProfileEditorSource.maybeOf(context);
    if (section == null) return const SizedBox.shrink();
    return section.editingIn(widget.session, exportKey: _exportKey);
  }
}
