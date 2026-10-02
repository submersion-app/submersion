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
    this.describeError,
  });

  final QueryEditorContext context;
  final QueryNode? value;
  final ValueChanged<QueryNode?> onChanged;
  final QueryEditorStrings strings;

  /// Shown as a Save button when set; enabled while [value] is not null.
  final VoidCallback? onSave;

  /// How the text tab words a parse or validation error; the engine's
  /// English message when null.
  final String Function(QueryError error)? describeError;

  @override
  State<QueryEditor> createState() => _QueryEditorState();
}

class _QueryEditorState extends State<QueryEditor>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Horizontal label padding Material gives each scrollable tab
  /// (`kTabLabelPadding`), needed on both sides of every tab's own text.
  static const double _tabLabelPadding = 16;

  /// Icon, gap and button padding the Save button carries around its own
  /// label text; approximate, since only the decision to wrap needs it, not
  /// a pixel-perfect layout.
  static const double _saveButtonChrome = 64;

  static const double _rowSpacing = 8;

  /// Whether the tabs and the Save button fit on one row without squeezing
  /// the tabs down to a sliver that needs scrolling just to read "Builder"
  /// (#2787 follow-up). Mirrors how [EquipmentSectionToggle.naturalWidth]
  /// measures its own labels to decide a layout rather than guessing a
  /// breakpoint in logical pixels, which would drift from the actual text at
  /// another locale or text scale.
  bool _rowFits(BuildContext context, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final tabStyle =
        Theme.of(context).textTheme.titleSmall ?? const TextStyle(fontSize: 14);
    final buttonStyle =
        Theme.of(context).textTheme.labelLarge ?? const TextStyle(fontSize: 14);
    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final strings = widget.strings;
    final tabsWidth =
        measure(strings.tabText, tabStyle) +
        measure(strings.tabBuilder, tabStyle) +
        4 * _tabLabelPadding;
    final saveWidth = measure(strings.save, buttonStyle) + _saveButtonChrome;
    return maxWidth >= tabsWidth + _rowSpacing + saveWidth;
  }

  @override
  Widget build(BuildContext context) {
    final strings = widget.strings;
    final tabBar = TabBar(
      controller: _tabs,
      // A fixed TabBar stretches both tabs into equal slots across the row;
      // a label too wide for its slot is clipped outright with no
      // ellipsis. Scrollable gives each tab its natural width instead, the
      // same fix already used for the Equipment/Sets toggle (issue #2256,
      // #2787).
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        Tab(text: strings.tabText),
        Tab(text: strings.tabBuilder),
      ],
    );
    final saveButton = widget.onSave == null
        ? null
        : FilledButton.tonalIcon(
            icon: const Icon(Icons.bookmark_add_outlined),
            label: Text(strings.save),
            onPressed: widget.value == null ? null : widget.onSave,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (saveButton == null)
          tabBar
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (_rowFits(context, constraints.maxWidth)) {
                return Row(
                  children: [
                    Expanded(child: tabBar),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: _rowSpacing,
                      ),
                      child: saveButton,
                    ),
                  ],
                );
              }
              // Not enough room for both: stack them, so the tabs keep the
              // full row's width instead of being squeezed down to a sliver
              // that needs scrolling to read "Builder" (#2787 follow-up).
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  tabBar,
                  Padding(
                    padding: const EdgeInsets.only(top: _rowSpacing),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: saveButton,
                    ),
                  ),
                ],
              );
            },
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
