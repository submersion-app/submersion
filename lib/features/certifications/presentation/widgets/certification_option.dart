import 'package:flutter/foundation.dart';

/// One row in the certification dropdown: either a selectable certification
/// -- including the explicit "not specified" entry, which carries a null
/// [level] -- or a non-selectable group header. [level] is a built-in
/// level's enum name or a custom level id (issue #690).
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

  /// The "Add custom certification..." action row (issue #690). Selectable,
  /// with a key no header uses, so it stays unique too.
  const CertificationOption.addCustom() : level = null, headerKey = _addKey;

  static const _addKey = '__addCustom__';

  bool get isAddCustom => headerKey == _addKey;

  final String? level;
  final String? headerKey;

  @override
  bool operator ==(Object other) =>
      other is CertificationOption &&
      other.level == level &&
      other.headerKey == headerKey;

  @override
  int get hashCode => Object.hash(level, headerKey);
}
