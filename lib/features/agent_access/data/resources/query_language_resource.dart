import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/registry/query_entity.dart';
import 'package:submersion/features/agent_access/data/resources/agent_resource.dart';
import 'package:submersion/features/agent_access/domain/agent_tool.dart';
import 'package:submersion/features/query/app_query_registry.dart';

/// The grammar, as the query language design records it
/// (docs/design/specs/2026-09-25-entity-query-language-design.md).
const kQueryGrammarText = '''
# Submersion query language

Case-insensitive keywords. Whitespace-separated terms are ANDed. Precedence:
NOT binds tightest, then AND, then OR; parentheses group.

```
query      := or
or         := and ( 'OR' and )*          '|' is an alias for OR
and        := not ( 'AND'? not )*        '&' is an alias for AND
not        := ( 'NOT' | '-' ) not | primary
primary    := '(' or ')' | condition | text
condition  := path op value
            | path ':' ( 'none' | 'any' | value )
            | path 'in' '[' value ( ',' value )* ']'
            | path 'in' daterange                     date in 2025
            | path 'between' value 'and' value
path       := ident ( '.' ident )*
op         := '=' | '!=' | '<' | '<=' | '>' | '>=' | '~'
value      := number unit? | quoted | word | date | daterange
text       := quoted | word                (a bare term that is not a path)
```

The shorthand `:`: `field:none` means empty, `field:any` means set,
`field:value` means equals for enum, reference, bool, number and date fields
and contains for text fields. `~` is always contains.

Numbers: a bare number on a dimensioned field takes the diver's display unit
for that dimension (see `list_divers` or the `submersion://units` resource);
an explicit unit suffix (`m`, `ft`, `c`, `f`, `bar`, `psi`, `kg`, `lb`,
`min`) converts to the storage unit. A unit on a unitless field is an error.

Dates: `2025` (a year), `2025-03` (a month), `2025-03-14`, and the phrases
`last N days|weeks|months|years`, `this year`, `last year`, `since 2024`.
`date in 2025` and `date = 2025` both mean the year range.

References (a site, a buddy, a trip) are matched by name: `site:"Blue Hole"`.
Paths follow relations: `site.country = Mexico`, `buddies.name ~ Ann`.

Examples:

```
weights:none                              dives with no weight entry
NOT gear.type in [wetsuit, drysuit]       dives with no exposure gear
(weights:none OR temp:none) AND year = 2025
site.country = Mexico AND depth > 30
"night dive"                              free text over the search columns
```

Field keys are lowerCamel (`waterTemp`, `bottomTime`) with aliases listed
below. An empty query matches every record.
''';

/// Serves the grammar plus a field and relation list generated from the
/// query registry, so the document can never drift from the parser.
class QueryLanguageResource implements AgentResource {
  @override
  String get uri => 'submersion://query-language';

  @override
  String get name => 'Submersion query language reference';

  @override
  String get mimeType => 'text/markdown';

  @override
  Future<String> read(AgentToolContext context) async {
    final out = StringBuffer(kQueryGrammarText);
    out.writeln();
    out.writeln('# Roots and fields');
    for (final subject in QuerySubject.values.take(9)) {
      _writeEntity(out, appQueryRegistry.entityFor(subject));
    }
    return out.toString();
  }

  void _writeEntity(StringBuffer out, QueryEntity entity) {
    out.writeln();
    out.writeln('## ${entity.subject.name}');
    out.writeln();
    out.writeln('Fields:');
    for (final f in entity.fields) {
      out.write('- ${f.key} (${f.type.name}, ${f.dimension.name})');
      if (f.aliases.isNotEmpty) out.write(' aliases: ${f.aliases.join(', ')}');
      final values = f.enumValues;
      if (values != null && values.isNotEmpty) {
        out.write('; values: ${values.join(', ')}');
      }
      out.writeln();
    }
    if (entity.relations.isNotEmpty) {
      out.writeln();
      out.writeln('Relations (follow with a dot, e.g. site.country):');
      for (final r in entity.relations) {
        out.write('- ${r.key} -> ${r.target.name}');
        if (r.isMany) out.write(' (many)');
        if (r.aliases.isNotEmpty) {
          out.write(' aliases: ${r.aliases.join(', ')}');
        }
        out.writeln();
      }
    }
  }
}
