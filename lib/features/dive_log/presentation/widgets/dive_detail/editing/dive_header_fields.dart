import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/text/blank_text.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/helpers/seeded_dive_times.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

// The values edited on the dive page's header block, and the rules that keep
// them in step (issue #4527). Emptying one clears it.

const _log = LoggerService('DiveHeaderFields');

/// The header block's card id. Not a section: the header is fixed above
/// them, and the diver cannot hide or move it.
const String diveHeaderCardId = 'header';

bool _sameWords(String? a, String? b) => trimmedOrNull(a) == trimmedOrNull(b);

/// The dive's own name. Stored trimmed; blank is no name, and the page then
/// names the dive after its site.
final diveNameField = EditField<Dive, String?>(
  id: 'name',
  cardId: diveHeaderCardId,
  read: (dive) => dive.name,
  write: (dive, value) {
    final words = trimmedOrNull(value);
    return dive.copyWith(name: words, clearName: words == null);
  },
  equals: _sameWords,
);

/// The dive's number in the log, held as a whole number in a `double` so the
/// number row can edit it.
final diveNumberField = EditField<Dive, double?>(
  id: 'diveNumber',
  cardId: diveHeaderCardId,
  read: (dive) => dive.diveNumber?.toDouble(),
  write: (dive, value) => value == null
      ? dive.copyWith(clearDiveNumber: true)
      : dive.copyWith(diveNumber: value.round()),
);

/// The dive's site. Two values are the same when they are the same site: a
/// site renamed underneath the sitting is not a change to the dive.
final diveSiteField = EditField<Dive, DiveSite?>(
  id: 'site',
  cardId: diveHeaderCardId,
  read: (dive) => dive.site,
  write: (dive, site) =>
      site == null ? dive.copyWith(clearSite: true) : dive.copyWith(site: site),
  equals: (a, b) => a?.id == b?.id,
);

/// When the diver entered the water. Written to `entryTime` and to the
/// older `dateTime` together, as the dive form saves them, so the trip
/// stretch (which reads the date) and its check (which reads the entry)
/// agree.
final diveEntryField = EditField<Dive, DateTime>(
  id: 'entryTime',
  cardId: diveHeaderCardId,
  read: (dive) => dive.effectiveEntryTime,
  write: (dive, value) => dive.copyWith(entryTime: value, dateTime: value),
);

/// When the diver left the water, as recorded. A dive with none is shown
/// to end at an estimate ([estimatedExit]), which is never stored.
final diveExitField = EditField<Dive, DateTime?>(
  id: 'exitTime',
  cardId: diveHeaderCardId,
  read: (dive) => dive.exitTime,
  write: (dive, value) => value == null
      ? dive.copyWith(clearExitTime: true)
      : dive.copyWith(exitTime: value),
);

double? _seconds(Duration? duration) => duration?.inSeconds.toDouble();

Duration? _duration(double? seconds) =>
    seconds == null ? null : Duration(seconds: seconds.round());

/// The runtime, entry to exit, in seconds. Held as a `double` so the number
/// row's rule keeps a stored 43 min 27 s when 43 is typed back.
final diveRuntimeField = EditField<Dive, double?>(
  id: 'runtime',
  cardId: diveHeaderCardId,
  read: (dive) => _seconds(dive.runtime),
  write: (dive, value) => value == null
      ? dive.copyWith(clearRuntime: true)
      : dive.copyWith(runtime: _duration(value)),
);

/// The bottom time in seconds. Never worked out from the profile here: a
/// dive without one is offered the profile's as a suggestion.
final diveBottomTimeField = EditField<Dive, double?>(
  id: 'bottomTime',
  cardId: diveHeaderCardId,
  read: (dive) => _seconds(dive.bottomTime),
  write: (dive, value) => value == null
      ? dive.copyWith(clearBottomTime: true)
      : dive.copyWith(bottomTime: _duration(value)),
);

/// The deepest point, in metres.
final diveMaxDepthField = EditField<Dive, double?>(
  id: 'maxDepth',
  cardId: diveHeaderCardId,
  read: (dive) => dive.maxDepth,
  write: (dive, value) =>
      dive.copyWith(maxDepth: value, clearMaxDepth: value == null),
);

/// The average depth, in metres. The Details card shows it too.
final diveAvgDepthField = EditField<Dive, double?>(
  id: 'avgDepth',
  cardId: diveHeaderCardId,
  alsoShownOn: {'details'},
  read: (dive) => dive.avgDepth,
  write: (dive, value) =>
      dive.copyWith(avgDepth: value, clearAvgDepth: value == null),
);

/// The water temperature, in Celsius.
final diveWaterTempField = EditField<Dive, double?>(
  id: 'waterTemp',
  cardId: diveHeaderCardId,
  read: (dive) => dive.waterTemp,
  write: (dive, value) =>
      dive.copyWith(waterTemp: value, clearWaterTemp: value == null),
);

/// The diver's rating, 1 to 5. Nothing and 0 are the same: no rating.
final diveRatingField = EditField<Dive, int?>(
  id: 'rating',
  cardId: diveHeaderCardId,
  read: (dive) => dive.rating == 0 ? null : dive.rating,
  write: (dive, value) => value == null || value == 0
      ? dive.copyWith(clearRating: true)
      : dive.copyWith(rating: value),
  equals: (a, b) => (a ?? 0) == (b ?? 0),
);

/// Whether the diver marked the dive a favourite.
final diveFavoriteField = EditField<Dive, bool>(
  id: 'isFavorite',
  cardId: diveHeaderCardId,
  read: (dive) => dive.isFavorite,
  write: (dive, value) => dive.copyWith(isFavorite: value),
);

/// Whether the dive is planned rather than logged (issue #2002).
final divePlannedField = EditField<Dive, bool>(
  id: 'isPlanned',
  cardId: diveHeaderCardId,
  read: (dive) => dive.isPlanned,
  write: (dive, value) => dive.copyWith(isPlanned: value),
);

/// The instant a picker's [picked] minute stands for. A picker shows whole
/// minutes, so a time read back at its own minute keeps its seconds (issue
/// #3901): [stored], the value stored before the sitting, so that a time
/// moved and moved back is no change; else [current], the one on show. A
/// new day at the same time of day keeps [current]'s seconds too. Any other
/// minute is taken as picked.
DateTime pickedInstant(DateTime picked, DateTime? current, {DateTime? stored}) {
  if (stored != null && wholeMinute(stored) == picked) return stored;
  if (current == null) return picked;
  if (wholeMinute(current) == picked) return current;
  if (current.hour == picked.hour && current.minute == picked.minute) {
    return picked.add(
      Duration(seconds: current.second, milliseconds: current.millisecond),
    );
  }
  return picked;
}

/// Moves the entry, and a recorded exit with it, so the dive keeps its
/// length (issue #241). The runtime is left as it is. An exit a runtime
/// typed in this sitting moved, and the exit to give back for it, move too.
void setEntryTime(EditSession<Dive> session, DateTime entry) {
  final shift = entry.difference(session.valueOf(diveEntryField));
  final exit = session.valueOf(diveExitField);
  session.set(diveEntryField, entry);
  if (exit == null) return;
  session.set(diveExitField, exit.add(shift));
  final moved = session.recall<({DateTime before, DateTime after})>(
    _runtimeExitKey,
  );
  if (moved != null && moved.after == exit) {
    session.remember(_runtimeExitKey, (
      before: moved.before.add(shift),
      after: exit.add(shift),
    ));
  }
}

/// Whether the sitting's entry and exit are both the stored ones.
bool _timesAsStored(EditSession<Dive> session) =>
    session.valueOf(diveEntryField) == diveEntryField.read(session.stored) &&
    session.valueOf(diveExitField) == session.stored.exitTime;

/// Sets the exit. A changed exit sets the runtime to exit minus entry, or
/// clears it when the exit is before the entry; back at the stored times,
/// the stored runtime comes back with them. An exit cleared leaves the
/// runtime alone.
void setExitTime(EditSession<Dive> session, DateTime? exit) {
  if (exit == session.valueOf(diveExitField)) return;
  // Picked by hand: no runtime typed earlier gives it back.
  session.remember(_runtimeExitKey, null);
  session.set(diveExitField, exit);
  if (exit == null) return;
  if (_timesAsStored(session)) {
    session.set(diveRuntimeField, diveRuntimeField.read(session.stored));
    return;
  }
  final span = exit.difference(session.valueOf(diveEntryField));
  session.set(diveRuntimeField, span.isNegative ? null : _seconds(span));
}

/// The exit before a runtime typed in this sitting started moving it, and
/// the exit that runtime last set: `({DateTime before, DateTime after})`.
const _runtimeExitKey = 'runtimeMovedExit';

/// Sets the runtime. A positive runtime moves a recorded exit to entry plus
/// the runtime; back to the stored runtime with the stored entry, the exit
/// goes back to the stored exit, when the dive was stored with one. A dive
/// with no exit keeps none.
///
/// Zero or none moves no exit of its own, and gives back the exit as it was
/// before a runtime typed in this sitting moved it: a field emptied a digit
/// at a time passes through runtimes the diver never meant (52, 5, none).
/// An exit picked by hand since is kept.
void setRuntime(EditSession<Dive> session, Duration? runtime) {
  session.set(diveRuntimeField, _seconds(runtime));
  final moved = session.recall<({DateTime before, DateTime after})>(
    _runtimeExitKey,
  );
  if (runtime == null || runtime <= Duration.zero) {
    if (moved != null && session.valueOf(diveExitField) == moved.after) {
      session.set(diveExitField, moved.before);
    }
    session.remember(_runtimeExitKey, null);
    return;
  }
  final exit = session.valueOf(diveExitField);
  if (exit == null) return;
  final entry = session.valueOf(diveEntryField);
  final stored = session.stored;
  final storedExit = stored.exitTime;
  // Back at the stored runtime and entry, the stored exit comes back. A dive
  // stored with no exit has none to give back: the exit the diver picked in
  // this sitting moves like any other.
  final next =
      storedExit != null &&
          runtime == stored.runtime &&
          entry == diveEntryField.read(stored)
      ? storedExit
      : entry.add(runtime);
  session.set(diveExitField, next);
  // The exit before the first move of this run is the one to give back.
  final before = moved != null && exit == moved.after ? moved.before : exit;
  session.remember(_runtimeExitKey, (before: before, after: next));
}

/// Where a dive with no exit is shown to end: entry plus its runtime, or
/// failing that its bottom time. Null for a dive with an exit, or with
/// neither. A hint only: never stored, since a bottom time must never stand
/// in for a runtime.
DateTime? estimatedExit(Dive dive) {
  if (dive.exitTime != null) return null;
  final span = dive.runtime ?? dive.bottomTime;
  return span == null ? null : dive.effectiveEntryTime.add(span);
}

/// Marks the dive planned or not (issue #2002). A planned dive holds no
/// number until it is logged, so planned clears it. Not planned gives back
/// the stored number when the sitting has none, or failing that asks
/// [nextNumber], and sets the answer only if the number is still empty and
/// the dive still not planned when it comes. The ask is tracked, so a save
/// waits for it.
void setPlanned(
  EditSession<Dive> session,
  bool planned, {
  required Future<int?> Function() nextNumber,
}) {
  session.set(divePlannedField, planned);
  if (planned) {
    session.set(diveNumberField, null);
    return;
  }
  if (session.valueOf(diveNumberField) != null) return;
  final stored = diveNumberField.read(session.stored);
  if (stored != null) {
    session.set(diveNumberField, stored);
    return;
  }
  session.track(_suggestNumber(session, nextNumber));
}

Future<void> _suggestNumber(
  EditSession<Dive> session,
  Future<int?> Function() nextNumber,
) async {
  final int? number;
  try {
    number = await nextNumber();
  } catch (error, stackTrace) {
    // A suggestion: the diver can type the number.
    _log.warning(
      'Could not suggest a dive number',
      error: error,
      stackTrace: stackTrace,
    );
    return;
  }
  if (number == null || session.isDisposed || session.isFrozen) return;
  if (session.valueOf(divePlannedField)) return;
  if (session.valueOf(diveNumberField) != null) return;
  session.set(diveNumberField, number.toDouble());
}

/// Whether the header editor offers the planned switch: for a dive stored
/// as logged, with no primary data source, that is not a draft. A stored
/// plan is logged with "Mark as logged", which numbers it and runs the
/// logbook rules. [hasPrimarySource] is null while the dive's sources are
/// still loading, and an unknown source offers no switch: a downloaded dive
/// must not be marked as planned before its source is known.
bool plannedSwitchOffered(Dive stored, {required bool? hasPrimarySource}) =>
    !stored.isPlanned && hasPrimarySource == false && !stored.isDraft;
