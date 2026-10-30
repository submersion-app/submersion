import 'package:collection/collection.dart';

import 'package:submersion/features/dive_log/domain/bulk_edit/bulk_edit_field_set.dart';
import 'package:submersion/features/rules/domain/site_rule_field.dart';

/// Whether a membership action adds its items or removes them.
enum MembershipMode { add, remove }

/// The dive collections a rule can add to or remove from.
enum DiveCollection { diveTypes, tags, equipment, buddies, courses }

/// The site collections a rule can add to or remove from.
enum SiteCollection { tags, siteTypes }

const _listEq = ListEquality<Object?>();
const _mapEq = DeepCollectionEquality();

/// One thing a logbook rule does to each matching dive or site (#3513).
/// Values are canonical: metric units, enum `.name`, entity ids.
sealed class RuleAction {
  const RuleAction();
}

/// Set one bulk-editable dive field. [values] holds the [BulkScalarInputs]
/// members the field writes, keyed by member name.
class SetDiveFieldAction extends RuleAction {
  const SetDiveFieldAction(this.field, this.values);

  final BulkField field;
  final Map<String, Object?> values;

  @override
  bool operator ==(Object other) =>
      other is SetDiveFieldAction &&
      other.field == field &&
      _mapEq.equals(other.values, values);

  @override
  int get hashCode => Object.hash(field, _mapEq.hash(values));
}

/// Add items to, or remove them from, one dive collection. [buddyRoleId]
/// is the role an added buddy gets.
class DiveMembershipAction extends RuleAction {
  const DiveMembershipAction(
    this.collection,
    this.mode,
    this.ids, {
    this.buddyRoleId,
  });

  final DiveCollection collection;
  final MembershipMode mode;
  final List<String> ids;
  final String? buddyRoleId;

  @override
  bool operator ==(Object other) =>
      other is DiveMembershipAction &&
      other.collection == collection &&
      other.mode == mode &&
      other.buddyRoleId == buddyRoleId &&
      _listEq.equals(other.ids, ids);

  @override
  int get hashCode =>
      Object.hash(collection, mode, buddyRoleId, _listEq.hash(ids));
}

/// Append [text] to a dive's notes, on a new line when notes exist.
class AppendDiveNotesAction extends RuleAction {
  const AppendDiveNotesAction(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is AppendDiveNotesAction && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// Set one site column to [value] (canonical units, enum `.name`).
class SetSiteFieldAction extends RuleAction {
  const SetSiteFieldAction(this.field, this.value);

  final SiteRuleField field;
  final Object value;

  @override
  bool operator ==(Object other) =>
      other is SetSiteFieldAction &&
      other.field == field &&
      other.value == value;

  @override
  int get hashCode => Object.hash(field, value);
}

/// Add items to, or remove them from, one site collection.
class SiteMembershipAction extends RuleAction {
  const SiteMembershipAction(this.collection, this.mode, this.ids);

  final SiteCollection collection;
  final MembershipMode mode;
  final List<String> ids;

  @override
  bool operator ==(Object other) =>
      other is SiteMembershipAction &&
      other.collection == collection &&
      other.mode == mode &&
      _listEq.equals(other.ids, ids);

  @override
  int get hashCode => Object.hash(collection, mode, _listEq.hash(ids));
}

/// Append [text] to a site's description, on a new line when one exists.
class AppendSiteDescriptionAction extends RuleAction {
  const AppendSiteDescriptionAction(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      other is AppendSiteDescriptionAction && other.text == text;

  @override
  int get hashCode => text.hashCode;
}

/// An action kind this version does not know, kept verbatim so saving the
/// rule again does not lose it. A rule holding one never runs.
class UnknownRuleAction extends RuleAction {
  const UnknownRuleAction(this.raw);

  final Map<String, Object?> raw;

  @override
  bool operator ==(Object other) =>
      other is UnknownRuleAction && _mapEq.equals(other.raw, raw);

  @override
  int get hashCode => _mapEq.hash(raw);
}
