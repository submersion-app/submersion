import 'package:equatable/equatable.dart';

/// Outcome of one reef-data provider lookup.
///
/// [empty] and [unavailable] must never render identically: "not in a
/// protected area" is a fact, "could not check" is a failure.
enum ReefDataStatus { ok, empty, unavailable }

/// One provider's contribution to a [ReefSnapshot].
class ReefPart<T> extends Equatable {
  final ReefDataStatus status;
  final T? value;

  const ReefPart.ok(T this.value) : status = ReefDataStatus.ok;
  const ReefPart.empty() : status = ReefDataStatus.empty, value = null;
  const ReefPart.unavailable()
    : status = ReefDataStatus.unavailable,
      value = null;

  bool get hasValue => status == ReefDataStatus.ok && value != null;

  @override
  List<Object?> get props => [status, value];
}

/// The four reef-data providers, each with its own cache lifetime.
enum ReefProviderId {
  /// WRI Reefs at Risk, a frozen 2011 dataset.
  habitat(null),

  /// NOAA Coral Reef Watch. Current conditions only; historical variants
  /// never expire and are handled by the cache DAO.
  health(Duration(days: 1)),

  /// ProtectedSeas Navigator. Designations change yearly at most.
  protection(Duration(days: 90)),

  /// GBIF occurrence facets. Records accrue slowly.
  species(Duration(days: 30));

  /// Null means the entry never expires.
  final Duration? ttl;
  const ReefProviderId(this.ttl);
}
