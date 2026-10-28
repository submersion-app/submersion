import 'package:markdown/markdown.dart' as md;

/// The Markdown dialect for notes and descriptions (#3683): CommonMark plus
/// the GitHub extensions, minus four constructs that stay literal text
/// because they would change how notes typed before formatting existed
/// look: indented code blocks (an indented imported line would turn into a
/// code box), setext headings (a dashed separator would turn the line above
/// into a heading), raw HTML (Flutter cannot draw it) and nothing that
/// fetches over the network (an image parses, but every renderer draws it
/// as a link).
///
/// Single line breaks are kept inside paragraph text, so every renderer
/// draws them as breaks, as GitHub comments do. Strict CommonMark would
/// join them and collapse every multi-line note written so far.
List<md.Node> parseNotesMarkdown(String source) {
  final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  return _document().parse(normalized);
}

/// A fresh document per parse: the document collects link reference
/// definitions as it parses, so sharing one would leak references between
/// notes.
md.Document _document() => md.Document(
  encodeHtml: false,
  withDefaultBlockSyntaxes: false,
  withDefaultInlineSyntaxes: false,
  extensionSet: md.ExtensionSet.none,
  blockSyntaxes: const [
    md.EmptyBlockSyntax(),
    md.FencedCodeBlockSyntax(),
    md.HeaderSyntax(),
    md.BlockquoteSyntax(),
    md.HorizontalRuleSyntax(),
    md.TableSyntax(),
    md.UnorderedListWithCheckboxSyntax(),
    md.OrderedListWithCheckboxSyntax(),
    md.LinkReferenceDefinitionSyntax(),
    md.ParagraphSyntax(),
  ],
  inlineSyntaxes: [
    md.EscapeSyntax(),
    md.AutolinkExtensionSyntax(),
    md.AutolinkSyntax(),
    md.EmailAutolinkSyntax(),
    md.LinkSyntax(),
    md.ImageSyntax(),
    md.CodeSyntax(),
    md.EmphasisSyntax.asterisk(),
    md.EmphasisSyntax.underscore(),
    md.StrikethroughSyntax(),
    md.LineBreakSyntax(),
  ],
);

/// The number a parsed list's first item carries: a numbered list may start
/// anywhere (`3. ` gives 3); every other list starts at 1.
int notesListStart(md.Element list) =>
    int.tryParse(list.attributes['start'] ?? '') ?? 1;

/// A list item's task box: true when ticked, false when empty, null for an
/// ordinary item. In a tight list the box is the item's first child; in a
/// loose list (items apart by blank lines) the parser puts it inside the
/// item's paragraph.
bool? notesTaskState(md.Element item) {
  for (final child in item.children ?? const <md.Node>[]) {
    if (child is! md.Element) continue;
    if (child.tag == 'input') return child.attributes['checked'] == 'true';
    if (child.tag == 'p') {
      final first = child.children?.firstOrNull;
      if (first is md.Element && first.tag == 'input') {
        return first.attributes['checked'] == 'true';
      }
    }
  }
  return null;
}

/// One row of a parsed table: its cells, and whether it is the header.
typedef NotesTableRow = ({bool header, List<md.Element> cells});

/// A parsed table's rows in order, header first, for every renderer.
List<NotesTableRow> notesTableRows(md.Element table) {
  final rows = <NotesTableRow>[];
  void visit(md.Node node, {required bool header}) {
    if (node is! md.Element) return;
    if (node.tag == 'tr') {
      rows.add((
        header: header,
        cells: [
          for (final cell in node.children ?? const <md.Node>[])
            if (cell is md.Element) cell,
        ],
      ));
      return;
    }
    for (final child in node.children ?? const <md.Node>[]) {
      visit(child, header: header || node.tag == 'thead');
    }
  }

  visit(table, header: false);
  return rows;
}

const _tappableSchemes = {'http', 'https', 'mailto'};

/// Whether a link in a note may be opened: web and mail addresses only, so
/// a `javascript:` or `file:` link draws as plain text.
bool isTappableNotesLink(String? href) {
  if (href == null) return false;
  final uri = Uri.tryParse(href);
  return uri != null && _tappableSchemes.contains(uri.scheme.toLowerCase());
}

/// [existing] with [text] appended as a new paragraph, so appended text
/// never joins the last paragraph or list item.
String appendMarkdownParagraph(String existing, String text) =>
    existing.isEmpty ? text : '$existing\n\n$text';
