import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

const String _libraryFieldsKey = 'site.libraryFields';

/// What a sitting on a site needs as it starts, before any card is open
/// (issue #4527, phase 2): the site's own rows that are not columns of the
/// site, read now, so each card's read layout can show the sitting's rows
/// once they change.
void startSiteSitting(EditSession<DiveSite> session, ProviderRead read) {}

/// Records that a held write touched [fields] of a library site, for the
/// stamp made once the sitting has committed: held writes write without
/// stamping, since a rollback would not undo a stamp.
void noteSiteLibraryFields(EditSession<DiveSite> session, Set<String> fields) {
  if (fields.isEmpty || session.isDisposed) return;
  session.remember(_libraryFieldsKey, {
    ...siteLibraryFields(session),
    ...fields,
  });
}

/// The library fields the sitting's held writes have touched in this save.
Set<String> siteLibraryFields(EditSession<DiveSite> session) =>
    session.isDisposed
    ? const {}
    : session.recall<Set<String>>(_libraryFieldsKey) ?? const {};

/// Forgets the fields noted by an earlier attempt, before a save: one that
/// did not commit stamped nothing.
void clearSiteLibraryFields(EditSession<DiveSite> session) {
  if (session.isDisposed) return;
  session.remember(_libraryFieldsKey, null);
}
