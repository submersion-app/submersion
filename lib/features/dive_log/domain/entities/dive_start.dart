/// A dive's id and when it started, for a reader that needs to order or
/// window dives without hydrating them.
///
/// [start] is the dive's `entry_time`, falling back to its dive date: the
/// same key `DiveRepository.getAllDives` orders by, decoded as the stored
/// wall clock flagged UTC like every other dive time.
typedef DiveStart = ({String id, DateTime start});
