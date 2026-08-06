import 'dart:convert';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/reef/data/repositories/reef_cache_dao.dart';
import 'package:submersion/features/reef/data/services/nearby_species_service.dart';
import 'package:submersion/features/reef/data/services/reef_habitat_service.dart';
import 'package:submersion/features/reef/data/services/reef_health_service.dart';
import 'package:submersion/features/reef/data/services/reef_protection_service.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/domain/entities/reef_habitat.dart';
import 'package:submersion/features/reef/domain/entities/reef_health.dart';
import 'package:submersion/features/reef/domain/entities/reef_protection.dart';
import 'package:submersion/features/reef/domain/entities/reef_snapshot.dart';
import 'package:submersion/features/reef/domain/services/reef_coordinate_key.dart';

/// Cache-aside orchestration across the four reef-data providers.
///
/// Providers run concurrently with individually captured failures, so one
/// outage never blocks the others. Concurrent callers for the same provider
/// and coordinate share a single in-flight request.
class ReefRepository {
  final ReefCacheDao _cache;
  final ReefHabitatService _habitat;
  final ReefHealthService _health;
  final ReefProtectionService _protection;
  final NearbySpeciesService _species;

  final Map<String, Future<void>> _inFlight = {};

  ReefRepository({
    required ReefCacheDao cache,
    required ReefHabitatService habitat,
    required ReefHealthService health,
    required ReefProtectionService protection,
    required NearbySpeciesService species,
  }) : _cache = cache,
       _habitat = habitat,
       _health = health,
       _protection = protection,
       _species = species;

  /// Fetches all four parts for [point], using cache where fresh.
  Future<ReefSnapshot> snapshotFor(GeoPoint point, {DateTime? date}) async {
    final quantized = ReefCoordinateKey.quantize(point);
    final key = ReefCoordinateKey.format(point);

    final results = await Future.wait([
      _resolve<ReefHabitat>(
        provider: ReefProviderId.habitat,
        coordKey: key,
        fetch: () => _habitat.fetch(quantized),
        encode: (v) => jsonEncode(v.toJson()),
        decode: (j) => ReefHabitat.fromJson(j as Map<String, dynamic>),
      ),
      _resolve<ReefHealth>(
        provider: ReefProviderId.health,
        coordKey: key,
        variant: date == null ? '' : _dateVariant(date),
        fetch: () => _health.fetch(quantized, date: date),
        encode: (v) => jsonEncode(v.toJson()),
        decode: (j) => ReefHealth.fromJson(j as Map<String, dynamic>),
      ),
      _resolve<List<ReefProtection>>(
        provider: ReefProviderId.protection,
        coordKey: key,
        fetch: () => _protection.fetch(quantized),
        encode: (v) => jsonEncode(v.map((p) => p.toJson()).toList()),
        decode: (j) => (j as List)
            .cast<Map<String, dynamic>>()
            .map(ReefProtection.fromJson)
            .toList(),
      ),
      _resolve<NearbySpecies>(
        provider: ReefProviderId.species,
        coordKey: key,
        fetch: () => _species.fetch(quantized),
        encode: (v) => jsonEncode(v.toJson()),
        decode: (j) => NearbySpecies.fromJson(j as Map<String, dynamic>),
      ),
    ]);

    return ReefSnapshot(
      habitat: results[0] as ReefPart<ReefHabitat>,
      health: results[1] as ReefPart<ReefHealth>,
      protection: results[2] as ReefPart<List<ReefProtection>>,
      species: results[3] as ReefPart<NearbySpecies>,
    );
  }

  /// Fetches reef health as it was on [date]. Historical readings are
  /// immutable and cached permanently.
  Future<ReefPart<ReefHealth>> healthFor(GeoPoint point, DateTime date) {
    final quantized = ReefCoordinateKey.quantize(point);
    return _resolve<ReefHealth>(
      provider: ReefProviderId.health,
      coordKey: ReefCoordinateKey.format(point),
      variant: _dateVariant(date),
      fetch: () => _health.fetch(quantized, date: date),
      encode: (v) => jsonEncode(v.toJson()),
      decode: (j) => ReefHealth.fromJson(j as Map<String, dynamic>),
    );
  }

  /// Deliberately NOT `async`: the in-flight registration below must happen
  /// synchronously. An async body suspends at its first `await`, which would
  /// let every concurrent caller observe an empty map and fetch in parallel.
  Future<ReefPart<T>> _resolve<T>({
    required ReefProviderId provider,
    required String coordKey,
    required Future<ReefPart<T>> Function() fetch,
    required String Function(T) encode,
    required T Function(Object?) decode,
    String variant = '',
  }) {
    final lock = '${provider.name}|$coordKey|$variant';

    // Someone else is already resolving this key. Wait for them, then read
    // what they stored rather than issuing a second request.
    final pending = _inFlight[lock];
    if (pending != null) {
      return pending.then(
        (_) => _readStored<T>(provider, coordKey, variant, decode),
      );
    }

    final work = _fetchAndStore<T>(
      provider: provider,
      coordKey: coordKey,
      variant: variant,
      fetch: fetch,
      encode: encode,
      decode: decode,
    );

    // Registered before any suspension point, so later callers in this same
    // microtask see it. Errors are swallowed on the tracking future only;
    // `work` still surfaces them to this caller.
    _inFlight[lock] = work.then((_) {}, onError: (_) {});

    return work.whenComplete(() => _inFlight.remove(lock));
  }

  Future<ReefPart<T>> _fetchAndStore<T>({
    required ReefProviderId provider,
    required String coordKey,
    required String variant,
    required Future<ReefPart<T>> Function() fetch,
    required String Function(T) encode,
    required T Function(Object?) decode,
  }) async {
    final cached = await _cache.read(provider, coordKey, variant: variant);
    if (cached != null) return _decodeEntry<T>(cached, decode);

    final part = await fetch();
    await _cache.write(
      provider: provider,
      coordKey: coordKey,
      variant: variant,
      status: part.status,
      payloadJson: part.hasValue ? encode(part.value as T) : '{}',
    );
    return part;
  }

  Future<ReefPart<T>> _readStored<T>(
    ReefProviderId provider,
    String coordKey,
    String variant,
    T Function(Object?) decode,
  ) async {
    final entry = await _cache.read(provider, coordKey, variant: variant);
    if (entry == null) return ReefPart<T>.unavailable();
    return _decodeEntry<T>(entry, decode);
  }

  ReefPart<T> _decodeEntry<T>(
    ReefCacheEntry entry,
    T Function(Object?) decode,
  ) {
    switch (entry.status) {
      case ReefDataStatus.ok:
        return ReefPart<T>.ok(decode(jsonDecode(entry.payloadJson)));
      case ReefDataStatus.empty:
        return ReefPart<T>.empty();
      case ReefDataStatus.unavailable:
        return ReefPart<T>.unavailable();
    }
  }

  String _dateVariant(DateTime date) {
    final utc = date.toUtc();
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$m-$d';
  }
}
