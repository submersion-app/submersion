import 'dart:convert';
import 'dart:developer' as developer;

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
import 'package:submersion/features/reef/domain/services/reef_coordinate_key.dart';

/// Cache-aside orchestration across the four reef-data providers.
///
/// Each part resolves on its own with its failure captured, so a slow or
/// failed provider never holds up another. Concurrent callers for the same
/// provider and coordinate share a single in-flight request.
class ReefRepository {
  final ReefCacheDao _cache;
  final ReefHabitatService _habitat;
  final ReefHealthService _health;
  final ReefProtectionService _protection;
  final NearbySpeciesService _species;

  /// Each entry completes with the leader's answer, or null if it threw.
  final Map<String, Future<ReefPart<Object?>?>> _inFlight = {};

  /// Cache generation for nearby species. Bump this whenever the taxon
  /// whitelist or what a cached result can contain changes, so previously
  /// cached results are refetched rather than served for the rest of their
  /// 30-day lifetime. v3 drops lists cached with failed name lookups.
  static const String _speciesWhitelistVariant = 'v3';

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

  /// Fetches current reef health at [point]. Freshwater sites must not call
  /// this: NOAA's grid covers only oceans, and the nearest-water-pixel fallback
  /// would hand a coastal quarry the adjacent ocean's temperature.
  Future<ReefPart<ReefHealth>> currentHealthFor(GeoPoint point) =>
      _healthPart(point);

  /// Fetches reef health as it was on [date]. Historical readings are
  /// immutable and cached permanently.
  Future<ReefPart<ReefHealth>> healthFor(GeoPoint point, DateTime date) =>
      _healthPart(point, date: date);

  /// Fetches reef presence and threat level at [point].
  Future<ReefPart<ReefHabitat>> habitatFor(GeoPoint point) {
    final quantized = ReefCoordinateKey.quantize(point);
    return _resolve<ReefHabitat>(
      provider: ReefProviderId.habitat,
      coordKey: ReefCoordinateKey.format(point),
      fetch: () => _habitat.fetch(quantized),
      encode: (v) => jsonEncode(v.toJson()),
      decode: (j) => ReefHabitat.fromJson(j as Map<String, dynamic>),
    );
  }

  /// Fetches the marine protected areas containing [point].
  Future<ReefPart<List<ReefProtection>>> protectionFor(GeoPoint point) {
    final quantized = ReefCoordinateKey.quantize(point);
    return _resolve<List<ReefProtection>>(
      provider: ReefProviderId.protection,
      coordKey: ReefCoordinateKey.format(point),
      fetch: () => _protection.fetch(quantized),
      encode: (v) => jsonEncode(v.map((p) => p.toJson()).toList()),
      decode: (j) => (j as List)
          .cast<Map<String, dynamic>>()
          .map(ReefProtection.fromJson)
          .toList(),
    );
  }

  /// Fetches species recorded near [point]. A result with lookup gaps is
  /// returned but not cached, so the gap is not kept for 30 days.
  Future<ReefPart<NearbySpecies>> speciesFor(GeoPoint point) {
    final quantized = ReefCoordinateKey.quantize(point);
    return _resolve<NearbySpecies>(
      provider: ReefProviderId.species,
      coordKey: ReefCoordinateKey.format(point),
      // Bumped when the taxon whitelist narrowed (issue #1036). Entries
      // cached under the old whitelist hold terrestrial mammals and would
      // otherwise survive their 30-day lifetime after the update.
      variant: _speciesWhitelistVariant,
      fetch: () => _species.fetch(quantized),
      encode: (v) => jsonEncode(v.toJson()),
      decode: (j) => NearbySpecies.fromJson(j as Map<String, dynamic>),
      skipStore: (v) => v.namesIncomplete,
    );
  }

  /// Forgets the cached failure of [provider]'s current data at [point], so a
  /// diver's retry reaches the network instead of reading the failure back.
  /// Other parts and any good result are untouched.
  Future<void> forgetFailure(ReefProviderId provider, GeoPoint point) =>
      _cache.deleteFailure(
        provider,
        ReefCoordinateKey.format(point),
        variant: provider == ReefProviderId.species
            ? _speciesWhitelistVariant
            : '',
      );

  Future<ReefPart<ReefHealth>> _healthPart(GeoPoint point, {DateTime? date}) {
    final quantized = ReefCoordinateKey.quantize(point);
    return _resolve<ReefHealth>(
      provider: ReefProviderId.health,
      coordKey: ReefCoordinateKey.format(point),
      variant: date == null ? '' : _dateVariant(date),
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
    bool Function(T)? skipStore,
  }) {
    final lock = '${provider.name}|$coordKey|$variant';

    // Someone else is already resolving this key. Share their answer rather
    // than issuing a second request. It is taken from them, not the cache,
    // because a partial species result is never stored.
    final pending = _inFlight[lock];
    if (pending != null) {
      return pending.then(
        (shared) => shared is ReefPart<T> ? shared : ReefPart<T>.unavailable(),
      );
    }

    final work = _fetchAndStore<T>(
      provider: provider,
      coordKey: coordKey,
      variant: variant,
      fetch: fetch,
      encode: encode,
      decode: decode,
      skipStore: skipStore,
    );

    // Registered before any suspension point, so later callers in this same
    // microtask see it. Errors are swallowed on the tracking future only;
    // `work` still surfaces them to this caller.
    _inFlight[lock] = work.then<ReefPart<Object?>?>(
      (part) => part,
      onError: (_) => null,
    );

    return work.whenComplete(() => _inFlight.remove(lock));
  }

  Future<ReefPart<T>> _fetchAndStore<T>({
    required ReefProviderId provider,
    required String coordKey,
    required String variant,
    required Future<ReefPart<T>> Function() fetch,
    required String Function(T) encode,
    required T Function(Object?) decode,
    bool Function(T)? skipStore,
  }) async {
    // The cache only saves a request, so when it cannot answer the network
    // still gets asked. That includes a row this build cannot read: habitat
    // never expires, so nothing else would ever replace it.
    try {
      final cached = await _cache.read(provider, coordKey, variant: variant);
      if (cached != null) return _decodeEntry<T>(cached, decode);
    } catch (e) {
      developer.log('Unreadable reef cache: $e', name: 'ReefRepository');
    }

    final part = await fetch();
    if (part.hasValue && (skipStore?.call(part.value as T) ?? false)) {
      return part;
    }
    try {
      await _cache.write(
        provider: provider,
        coordKey: coordKey,
        variant: variant,
        status: part.status,
        payloadJson: part.hasValue ? encode(part.value as T) : '{}',
      );
    } catch (e) {
      developer.log('Reef cache write failed: $e', name: 'ReefRepository');
    }
    return part;
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
