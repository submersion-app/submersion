export 'package:submersion/core/geography/country_code_save.dart'
    show KnownCountryCode, countryCodeOnSave;

import 'package:submersion/core/geography/country_code_save.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The code to store for [site] as it is written (issue #4426), the one
/// place every write through the repository passes: [reconcileCountryCode]
/// with [before] as the row as stored, null for a new site.
String? reconciledCountryCode(DiveSite site, {DiveSite? before}) =>
    reconcileCountryCode(
      country: site.country,
      code: site.countryCode,
      before: before == null
          ? null
          : (country: before.country, code: before.countryCode),
    );
