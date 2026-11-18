import 'package:submersion/l10n/arb/app_localizations.dart';

/// A held write of a sitting that the database refused without failing,
/// such as sharing a record this profile may not share, or a catalogue
/// record claimed by another site since the diver reviewed it (issue
/// #4527).
///
/// Thrown from inside the sitting's write, it rolls the whole Save back:
/// Save is all or nothing. The page stays unlocked with the sitting intact
/// and shows [message], which names what was refused.
class RecordSittingRefusal implements Exception {
  const RecordSittingRefusal(this.message);

  /// What was refused, in the diver's language.
  final String Function(AppLocalizations l10n) message;

  @override
  String toString() => 'RecordSittingRefusal';
}
