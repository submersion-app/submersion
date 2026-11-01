import 'package:submersion/features/table_editor/domain/table_draft.dart';
import 'package:submersion/features/table_editor/domain/table_editor_column.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/constants/entity_field.dart';

/// One tab of the table editor (#3422): the entity's table adapter, which
/// columns edit, how a row is matched when pasting, and how its drafts are
/// written. A fourth entity is a new implementation of this, nothing more.
abstract class TableEditorEntity<T, F extends EntityField> {
  EntityFieldAdapter<T, F> get adapter;

  F fieldFromName(String name);

  List<TableEditorColumn<T, F>> get columns;

  TableEditorColumn<T, F>? columnFor(F field) {
    for (final c in columns) {
      if (c.field == field) return c;
    }
    return null;
  }

  String idOf(T entity);

  /// The column a pasted block's key lives in: the dive number, or the name.
  F get keyField;

  /// The record's number, for paste matching; null for entities without one.
  int? numberOf(T entity);

  /// The record's name, for paste matching; null for dives.
  String? nameOf(T entity);

  /// Adds or adjusts drafts that depend on each other, such as a coordinate
  /// pair. The default keeps them as they are.
  List<TableDraft> reconcile(T entity, List<TableDraft> drafts) => drafts;

  /// Fresh rows for the stale check, by id.
  Future<List<T>> reload(List<String> ids);

  /// Writes the saveable drafts, grouped by entity id. Called inside the
  /// change log scope and the outer transaction, so it opens neither.
  Future<void> save(
    Map<String, List<TableDraft>> draftsByEntity,
    Map<String, T> fresh,
  );

  /// Fields saved as one value (a coordinate pair): when one of a record's
  /// drafts in a group is left out as stale, the others are too, so a cleared
  /// half never meets a moved partner. Default: none.
  List<Set<String>> get linkedFields => const [];

  /// Extra lines for the save summary (site snapping, pair clearing).
  List<String> summaryNotes(List<TableDraft> drafts, AppLocalizations l10n) =>
      const [];
}
