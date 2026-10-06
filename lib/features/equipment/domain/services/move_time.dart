/// When a move is recorded: the chosen [day] at the chosen [time]. With no
/// time chosen, today is [now] (so two moves today stay in the order they
/// were made) and an earlier day is local noon. A chosen time lets a
/// backdated move land before or after another move on the same day, which
/// decides where the item is now. A time later today is held at [now]: a
/// future move would outrank every move made before it comes round.
DateTime resolveMovedAt({
  required DateTime day,
  ({int hour, int minute})? time,
  required DateTime now,
}) {
  if (time != null) {
    return notAfterNow(
      DateTime(day.year, day.month, day.day, time.hour, time.minute),
      now,
    );
  }
  final isToday =
      day.year == now.year && day.month == now.month && day.day == now.day;
  return isToday ? now : DateTime(day.year, day.month, day.day, 12);
}

/// [movedAt], or [now] when it is later: a move the diver dates is never in
/// the future.
DateTime notAfterNow(DateTime movedAt, DateTime now) =>
    movedAt.isAfter(now) ? now : movedAt;
