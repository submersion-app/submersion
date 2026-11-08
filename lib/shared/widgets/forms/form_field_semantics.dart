import 'package:flutter/widgets.dart';

/// Names [field] for a screen reader after a label shown outside its
/// decoration, such as a form row's label (issue #4166).
///
/// A container node, not [MergeSemantics]: the text field's own semantics
/// merge into it while its error and counter text stay child nodes. Forcing
/// those to merge trips a framework assertion once an error appears mid-typing.
Widget namedFormField(String label, Widget field) =>
    Semantics(container: true, label: label, child: field);

/// A label shown beside a field that [namedFormField] already names, kept out
/// of the semantics tree so a screen reader does not read it twice.
Widget visibleFormLabel(String label, {TextStyle? style}) =>
    ExcludeSemantics(child: Text(label, style: style));
