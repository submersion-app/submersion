import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

import 'package:submersion/core/text/markdown/notes_markdown.dart';
import 'package:submersion/shared/utils/browser_launch.dart';
import 'package:submersion/shared/utils/link_open.dart';

/// A Markdown note drawn formatted (#3683): headings, emphasis, lists,
/// tasks, quotes, code, tables and tappable web and mail links, all in the
/// app theme. The whole note is selectable. An image is drawn as a link and
/// never fetched.
///
/// Callers keep their own empty state; an empty [source] draws nothing.
class MarkdownNotesView extends StatefulWidget {
  const MarkdownNotesView(this.source, {super.key, this.style, this.launch});

  final String source;

  /// The body text style. Defaults to the theme's `bodyMedium`.
  final TextStyle? style;

  /// Opens a link. Defaults to [openInBrowser]; injectable so tests never
  /// leave the app.
  final UrlLaunch? launch;

  @override
  State<MarkdownNotesView> createState() => _MarkdownNotesViewState();
}

class _MarkdownNotesViewState extends State<MarkdownNotesView> {
  final _recognizers = <TapGestureRecognizer>[];

  /// The built note, kept while the note, its style and the theme stay the
  /// same, so an ancestor rebuild neither re-parses it nor replaces the link
  /// recognizers (which would cancel a tap in progress).
  List<Widget>? _blocks;
  String? _builtSource;
  TextStyle? _builtStyle;
  ThemeData? _builtTheme;

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _open(Uri uri) =>
      openLinkOrOfferCopy(context, uri, launch: widget.launch ?? openInBrowser);

  List<Widget> _build(ThemeData theme) {
    if (_blocks != null &&
        _builtSource == widget.source &&
        _builtStyle == widget.style &&
        identical(_builtTheme, theme)) {
      return _blocks!;
    }
    _disposeRecognizers();
    final builder = _NotesBuilder(
      theme: theme,
      base: widget.style ?? theme.textTheme.bodyMedium ?? const TextStyle(),
      recognizers: _recognizers,
      onOpen: _open,
    );
    _builtSource = widget.source;
    _builtStyle = widget.style;
    _builtTheme = theme;
    return _blocks = builder.blocks(parseNotesMarkdown(widget.source));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.source.trim().isEmpty) return const SizedBox.shrink();
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: _build(Theme.of(context)),
      ),
    );
  }
}

const _blockGap = 6.0;
const _markerWidth = 18.0;
const _markerGap = 6.0;
const _monospace = 'monospace';

/// Turns the parsed note into widgets. Rebuilt on every build, so the
/// recognizers it creates are owned (and disposed) by the view's state.
class _NotesBuilder {
  _NotesBuilder({
    required this.theme,
    required this.base,
    required this.recognizers,
    required this.onOpen,
  });

  final ThemeData theme;
  final TextStyle base;
  final List<TapGestureRecognizer> recognizers;
  final void Function(Uri uri) onOpen;

  ColorScheme get _colors => theme.colorScheme;

  List<Widget> blocks(List<md.Node> nodes, {TextStyle? style}) {
    final out = <Widget>[];
    for (final node in nodes) {
      final widget = _block(node, style ?? base);
      if (widget == null) continue;
      if (out.isNotEmpty) out.add(const SizedBox(height: _blockGap));
      out.add(widget);
    }
    return out;
  }

  Widget? _block(md.Node node, TextStyle style) {
    if (node is md.Text) {
      return node.text.trim().isEmpty ? null : _rich([node], style);
    }
    if (node is! md.Element) return null;
    final children = node.children ?? const <md.Node>[];
    switch (node.tag) {
      case 'h1':
        return _rich(children, _heading(theme.textTheme.titleMedium));
      case 'h2':
        return _rich(children, _heading(theme.textTheme.titleSmall));
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _rich(children, _heading(style));
      case 'ul':
      case 'ol':
        return _list(node, style);
      case 'blockquote':
        return Container(
          padding: const EdgeInsets.only(left: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: _colors.outlineVariant, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: blocks(
              children,
              style: style.copyWith(color: _colors.onSurfaceVariant),
            ),
          ),
        );
      case 'pre':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              node.textContent.replaceFirst(RegExp(r'\n$'), ''),
              style: style.copyWith(fontFamily: _monospace),
            ),
          ),
        );
      case 'hr':
        return const Divider(height: 12);
      case 'table':
        return _table(node, style);
      default:
        return _rich(children, style);
    }
  }

  TextStyle _heading(TextStyle? style) =>
      (style ?? base).copyWith(fontWeight: FontWeight.w600);

  Widget _rich(List<md.Node> nodes, TextStyle style) =>
      Text.rich(TextSpan(children: _inline(nodes, style)));

  Widget _list(md.Element list, TextStyle style) {
    final ordered = list.tag == 'ol';
    var number = notesListStart(list);
    final rows = <Widget>[];
    for (final item in list.children ?? const <md.Node>[]) {
      if (item is! md.Element) continue;
      final children = item.children ?? const <md.Node>[];
      final task = notesTaskState(item);
      final Widget marker = task != null
          ? Icon(
              task ? Icons.check_box_outlined : Icons.check_box_outline_blank,
              size: (style.fontSize ?? 14) + 2,
              color: _colors.onSurfaceVariant,
            )
          : Text(ordered ? '$number.' : '•', style: style, softWrap: false);
      number++;
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 2));
      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // At least the marker column's width, wider for a long number
            // ('100.') or large text, and never wrapped.
            Padding(
              padding: const EdgeInsets.only(right: _markerGap),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _markerWidth),
                child: marker,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: _itemContent(children, style),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }

  /// A list item's children: runs of inline nodes (a tight list) become one
  /// rich text; blocks (a loose list's paragraphs, a nested list) stay
  /// blocks. The task checkbox is drawn as the marker, not here.
  List<Widget> _itemContent(List<md.Node> children, TextStyle style) {
    final out = <Widget>[];
    var run = <md.Node>[];
    void flush() {
      if (run.isEmpty) return;
      final text = run.map((n) => n.textContent).join();
      if (text.trim().isNotEmpty) out.add(_rich(run, style));
      run = <md.Node>[];
    }

    for (final child in children) {
      if (child is md.Element && child.tag == 'input') continue;
      if (child is md.Element && _isBlock(child.tag)) {
        flush();
        final widget = _block(child, style);
        if (widget != null) out.add(widget);
      } else {
        run.add(child);
      }
    }
    flush();
    return out;
  }

  static const _blockTags = {
    'p', 'ul', 'ol', 'blockquote', 'pre', 'hr', 'table', //
    'h1', 'h2', 'h3', 'h4', 'h5', 'h6',
  };

  bool _isBlock(String tag) => _blockTags.contains(tag);

  Widget _table(md.Element table, TextStyle style) {
    final rows = notesTableRows(table);
    if (rows.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: _colors.outlineVariant),
        children: [
          for (final row in rows)
            TableRow(
              children: [
                for (final cell in row.cells)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: _rich(
                      cell.children ?? const [],
                      row.header
                          ? style.copyWith(fontWeight: FontWeight.w600)
                          : style,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<InlineSpan> _inline(List<md.Node> nodes, TextStyle style) {
    final spans = <InlineSpan>[];
    for (final node in nodes) {
      if (node is md.Text) {
        spans.add(TextSpan(text: node.text, style: style));
        continue;
      }
      if (node is! md.Element) continue;
      final children = node.children ?? const <md.Node>[];
      switch (node.tag) {
        case 'strong':
          spans.addAll(
            _inline(children, style.copyWith(fontWeight: FontWeight.bold)),
          );
        case 'em':
          spans.addAll(
            _inline(children, style.copyWith(fontStyle: FontStyle.italic)),
          );
        case 'del':
          spans.addAll(
            _inline(
              children,
              style.copyWith(decoration: TextDecoration.lineThrough),
            ),
          );
        case 'code':
          spans.add(
            TextSpan(
              text: node.textContent,
              style: style.copyWith(
                fontFamily: _monospace,
                backgroundColor: _colors.surfaceContainerHighest,
              ),
            ),
          );
        case 'br':
          spans.add(TextSpan(text: '\n', style: style));
        case 'a':
          spans.addAll(_link(children, node.attributes['href'], style));
        case 'img':
          final src = node.attributes['src'];
          final alt = node.attributes['alt'] ?? '';
          spans.addAll(
            _link([md.Text(alt.isEmpty ? (src ?? '') : alt)], src, style),
          );
        default:
          spans.addAll(_inline(children, style));
      }
    }
    return spans;
  }

  List<InlineSpan> _link(
    List<md.Node> children,
    String? href,
    TextStyle style,
  ) {
    if (!isTappableNotesLink(href)) return _inline(children, style);
    final uri = Uri.parse(href!);
    final recognizer = TapGestureRecognizer()..onTap = () => onOpen(uri);
    recognizers.add(recognizer);
    final linkStyle = style.copyWith(
      color: _colors.primary,
      decoration: TextDecoration.underline,
      decorationColor: _colors.primary,
    );
    return [
      for (final span in _inline(children, linkStyle))
        if (span is TextSpan)
          TextSpan(
            text: span.text,
            style: span.style,
            recognizer: recognizer,
            mouseCursor: SystemMouseCursors.click,
          )
        else
          span,
    ];
  }
}
