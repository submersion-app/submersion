import 'package:flutter/material.dart';

import 'package:submersion/core/query/domain/query_errors.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/presentation/query_builder_group.dart';
import 'package:submersion/core/query/presentation/query_builder_strings.dart';
import 'package:submersion/core/query/presentation/query_editor_context.dart';
import 'package:submersion/core/query/presentation/query_text_field.dart';

@immutable
class QueryEditorStrings {
  const QueryEditorStrings({
    required this.tabText,
    required this.tabBuilder,
    required this.hint,
    required this.save,
    required this.builder,
  });

  final String tabText;
  final String tabBuilder;
  final String hint;
  final String save;
  final QueryBuilderStrings builder;
}

/// The shared editor of spec Unit 6: two tabs over one tree. The text tab
/// and the builder each write [onChanged]; both render [value], so an edit
/// on one is what the other shows.
class QueryEditor extends StatefulWidget {
  const QueryEditor({
    super.key,
    required this.context,
    required this.value,
    required this.onChanged,
    required this.strings,
    this.onSave,
    this.canSave,
    this.describeError,
    this.initialTab = 0,
    this.onValidityChanged,
  });

  final QueryEditorContext context;
  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;
  final QueryEditorStrings strings;

  /// Shown as a Save button when set; enabled per [canSave].
  final VoidCallback? onSave;

  /// Whether Save is enabled; while [value] is not null when unset. A
  /// caller whose Save stores more than this editor's tree (a whole filter,
  /// its other controls included) says so here (#2989).
  final bool? canSave;

  /// How the text tab words a parse or validation error; the engine's
  /// English message when null.
  final String Function(QueryError error)? describeError;

  /// The tab shown first: 0 is Text, 1 is the Builder (#2984: the dive
  /// table's Add filter opens on the rule it just added).
  final int initialTab;

  /// False while the text tab's text does not parse (its last valid tree
  /// stays committed as [value], so the screen and [value] disagree), true
  /// again once it parses, empties, or the tab changes: the builder and a
  /// fresh text tab both show [value] itself. For a host whose Save stores
  /// [value] (#3513).
  final ValueChanged<bool>? onValidityChanged;

  @override
  State<QueryEditor> createState() => _QueryEditorState();
}

class _QueryEditorState extends State<QueryEditor>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab,
  )..addListener(_tabChanged);

  void _tabChanged() {
    if (!_tabs.indexIsChanging) widget.onValidityChanged?.call(true);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A Row with Save beside the tabs squeezed the second tab's label
        // behind the button on any narrow host (a phone sheet, or the
        // Refine panel's fixed 440dp desktop side panel, see #3076) -
        // Save always sits on its own row below the tabs instead, which
        // costs a little vertical space but never hides either label.
        TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: strings.tabText),
            Tab(text: strings.tabBuilder),
          ],
        ),
        if (widget.onSave != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(strings.save),
                onPressed: (widget.canSave ?? widget.value != null)
                    ? widget.onSave
                    : null,
              ),
            ),
          ),
        const SizedBox(height: 8),
        // Not a TabBarView: that needs a bounded height, which a section
        // inside a ListView does not give it. Swapping the child takes the
        // height of whichever tab is showing.
        AnimatedBuilder(
          animation: _tabs,
          builder: (context, _) => _tabs.index == 0
              ? QueryTextField(
                  context: widget.context,
                  value: widget.value,
                  onChanged: widget.onChanged,
                  hintText: strings.hint,
                  describeError: widget.describeError,
                  onValidityChanged: widget.onValidityChanged,
                )
              : QueryBuilderGroup(
                  context: widget.context,
                  root: widget.value,
                  onChanged: widget.onChanged,
                  strings: strings.builder,
                ),
        ),
      ],
    );
  }
}
