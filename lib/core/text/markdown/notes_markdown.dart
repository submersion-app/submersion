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
