import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Whether a dive's gear should carry today's service state (#2260).
///
/// Service state is a statement about now, so it belongs only where the
/// diver can still act. A planned dive qualifies even once its date has
/// passed: it has not been executed, so the gear on it has not been used
/// and the diver may be about to dive it late. A logged dive in the past
/// does not: it is a record of what happened, and a mark about today beside
/// it would read as a claim about that dive.
///
/// [Dive.effectiveEntryTime] prefers the recorded entry over the legacy
/// header date, so a dive the diver actually entered in the past reads as
/// past. The comparison is strict, so a dive starting at [now] is not future.
bool diveGearShowsLiveServiceStatus(Dive dive, DateTime now) =>
    dive.isPlanned || dive.effectiveEntryTime.isAfter(now);
