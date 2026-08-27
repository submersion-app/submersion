import 'package:submersion/core/services/sync/crypto/keyslots.dart';

/// Cheap Argon2id for tests only (production default stays 64 MiB / t=3).
/// Keeps password wrap/unwrap fast enough for unit tests.
const KdfParams testKdf = KdfParams(m: 64, t: 1, p: 1);
