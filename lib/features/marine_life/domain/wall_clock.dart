/// [d]'s calendar fields as a UTC instant, whatever its zone flag.
///
/// Dive times are stored wall-clock-as-UTC and `DateTime.now()` is local, so
/// comparing them as instants would shift by the device's offset. Comparing
/// their fields keeps "90 days ago" and "this year" in the diver's calendar.
DateTime wallClock(DateTime d) => DateTime.utc(
  d.year,
  d.month,
  d.day,
  d.hour,
  d.minute,
  d.second,
  d.millisecond,
);
