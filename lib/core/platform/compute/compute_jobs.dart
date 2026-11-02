/// CPU-heavy sync work off the UI thread: inflating and compressing
/// payloads, AES-GCM, Argon2id and hashing.
///
/// Native builds run a job on a one-shot isolate once the payload is large
/// enough to be worth it (`compute_jobs_io.dart`); the browser posts it to
/// the compute worker (`compute_jobs_web.dart`). Below the threshold both run
/// it inline. Every job is implemented once, in `ComputeJobHandler`, so the
/// two paths produce the same bytes.
library;

export 'package:submersion/core/platform/compute/compute_jobs_io.dart'
    if (dart.library.js_interop) 'package:submersion/core/platform/compute/compute_jobs_web.dart';
