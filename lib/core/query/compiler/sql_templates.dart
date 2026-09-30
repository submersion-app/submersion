/// `{r}` is the alias of the row a field is read from.
String substituteRow(String template, String alias) =>
    template.replaceAll('{r}', alias);

/// Where a field's own dive subquery takes the active diver:
/// `{diver:ad}` over the subquery's alias `ad`. Only field SQL carries it.
final kDiverToken = RegExp(r'\{diver:(\w+)\}');

/// [template]'s diver tokens as ` AND <alias>.diver_id = ?` when [scoped]
/// (one bind each, see [kDiverToken]), or as nothing.
String substituteDiver(String template, {required bool scoped}) =>
    template.replaceAllMapped(
      kDiverToken,
      (m) => scoped ? ' AND ${m[1]}.diver_id = ?' : '',
    );

/// `{from}` is the row we are on, `{to}` the related row.
String substituteJoin(String template, String from, String to) =>
    template.replaceAll('{from}', from).replaceAll('{to}', to);

/// How many bind placeholders a fragment carries. Every `?` outside a quoted
/// literal counts; the registry never puts a `?` inside one.
int countPlaceholders(String sql) => '?'.allMatches(sql).length;

/// Escapes a LIKE term so `%` and `_` match literally. Pair it with
/// `ESCAPE '\'` in the template.
String escapeLike(String term) =>
    term.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
