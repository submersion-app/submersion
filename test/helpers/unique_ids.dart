/// A process-unique id for a fixture row, in place of one derived from the
/// clock.
///
/// Fixtures used to build ids from `DateTime.now().microsecondsSinceEpoch`.
/// Windows' clock granularity is coarser than a microsecond, so two rows
/// created inside one tick were given the same id and the second failed its
/// primary key -- intermittently, and never on Linux, which is why CI stayed
/// green (issue #2279).
///
/// Zero-padded to a fixed width so the ids still sort lexicographically in
/// creation order, as the constant-width clock values did.
String uniqueTestId(String prefix) =>
    '$prefix-${(_next++).toString().padLeft(9, '0')}';

int _next = 0;
