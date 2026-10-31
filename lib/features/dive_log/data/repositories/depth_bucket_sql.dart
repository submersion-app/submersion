/// The depth distribution's buckets: 10 m wide from the surface to 130 m,
/// plus an open-ended one for anything deeper (issue #641).
const depthBucketSizeMeters = 10;
const depthBucketCount = 13; // 0-10m, 10-20m, ..., 120-130m

/// A dive's bucket index, by its max depth, for a `dives` table aliased `d`.
///
/// The inner CAST forces real division whatever affinity the column value
/// carries; the outer one truncates toward zero. Truncation is not floor for
/// a negative, so the MAX/MIN pair clamps both ends: a stray negative depth
/// lands in the first bucket, and anything at or past 130 m lands in the
/// open-ended last one.
const depthBucketSql =
    'MIN(MAX(CAST(CAST(d.max_depth AS REAL) / $depthBucketSizeMeters '
    'AS INTEGER), 0), $depthBucketCount)';
