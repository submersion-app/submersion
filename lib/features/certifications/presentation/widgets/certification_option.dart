import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';

/// One row in the certification dropdown: either a selectable certification
/// -- including the explicit "not specified" entry, which carries a null
/// [level] -- or a non-selectable group header.
///
/// Why a wrapper instead of `DropdownButtonFormField<CertificationLevel>`
/// with null-valued disabled headers: `DropdownButton._updateSelectedIndex`
/// only short-circuits a null selection when *no enabled item* matches it,
/// and then asserts that exactly one item carries the selected value. A
/// selectable "Not specified" plus two null-valued headers means three items
/// share `null` and the assert fires. Giving headers their own distinct
/// values keeps every row unique, so the selected value always matches
/// exactly one item.
@immutable
class CertificationOption {
  /// A selectable row. A null [level] is the "not specified" entry.
  const CertificationOption.value(this.level) : headerKey = null;

  /// A non-selectable group header, identified by a stable [headerKey] so
  /// two headers are never equal to each other.
  const CertificationOption.header(String this.headerKey) : level = null;

  final CertificationLevel? level;
  final String? headerKey;

  @override
  bool operator ==(Object other) =>
      other is CertificationOption &&
      other.level == level &&
      other.headerKey == headerKey;

  @override
  int get hashCode => Object.hash(level, headerKey);
}
