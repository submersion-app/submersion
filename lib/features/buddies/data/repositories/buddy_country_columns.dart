import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/geography/country_code.dart';
import 'package:submersion/core/geography/country_code_save.dart';

/// A buddy's country and the ISO code saved beside it (issue #4457),
/// written the same way by every path that stores a buddy row.
///
/// Blank text is stored as none, with no code. Otherwise the code follows
/// the shared site rule ([reconcileCountryCode]), so a copy that changes the
/// country but carries the old code never keeps the old flag.
abstract final class BuddyCountryColumns {
  /// [country] trimmed, or null when it is blank.
  static String? text(String? country) {
    final trimmed = country?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  /// The country columns for a whole-buddy write of [country] and [code].
  /// [before] is the stored row's country and code, null for a new buddy.
  static BuddiesCompanion of({
    required String? country,
    required String? code,
    KnownCountryCode? before,
  }) {
    final stored = text(country);
    return BuddiesCompanion(
      country: Value(stored),
      countryCode: Value(
        stored == null
            ? null
            : reconcileCountryCode(country: stored, code: code, before: before),
      ),
    );
  }

  /// [partial] with its country trimmed and, when it sets the country
  /// without a code, the code read from that country.
  static BuddiesCompanion withDerivedCode(BuddiesCompanion partial) {
    if (!partial.country.present) return partial;
    final stored = text(partial.country.value);
    return partial.copyWith(
      country: Value(stored),
      countryCode: partial.countryCode.present && stored != null
          ? partial.countryCode
          : Value(countryCodeFor(stored)),
    );
  }
}
