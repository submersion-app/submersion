/// `{r}` is the alias of the row a field is read from.
String substituteRow(String template, String alias) =>
    template.replaceAll('{r}', alias);

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
