import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';

/// A browser has no Identify, so it never opens one.
AppDatabase openInMemoryLogbook() =>
    throw UnsupportedError('No in-memory logbook in a browser');

/// A browser has no Identify, so it never opens one.
LocalCacheDatabase openInMemoryLocalCache() =>
    throw UnsupportedError('No in-memory local cache in a browser');
