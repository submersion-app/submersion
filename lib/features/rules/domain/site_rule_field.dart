import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/rules/domain/rule_value_kind.dart';

/// A dive site column a rule can set (#3513). Each member names its SQL
/// column and the kind of value it holds; enum columns store `.name`.
enum SiteRuleField {
  waterType('water_type', RuleValueKind.enumName),
  difficulty('difficulty', RuleValueKind.enumName),
  country('country', RuleValueKind.text),
  region('region', RuleValueKind.text),
  city('city', RuleValueKind.text),
  island('island', RuleValueKind.text),
  bodyOfWater('body_of_water', RuleValueKind.text),
  minDepth('min_depth', RuleValueKind.number),
  maxDepth('max_depth', RuleValueKind.number),
  altitude('altitude', RuleValueKind.number),
  entryMethod('entry_method', RuleValueKind.enumName),
  exitMethod('exit_method', RuleValueKind.enumName),
  hazards('hazards', RuleValueKind.text),
  accessNotes('access_notes', RuleValueKind.text),
  mooringNumber('mooring_number', RuleValueKind.text),
  parkingInfo('parking_info', RuleValueKind.text);

  const SiteRuleField(this.column, this.kind);

  final String column;
  final RuleValueKind kind;

  /// The stored names an enum field accepts; empty for other kinds.
  List<String> get enumValues => switch (this) {
    SiteRuleField.waterType => [for (final v in WaterType.values) v.name],
    SiteRuleField.difficulty => [for (final v in SiteDifficulty.values) v.name],
    SiteRuleField.entryMethod ||
    SiteRuleField.exitMethod => [for (final v in EntryMethod.values) v.name],
    _ => const [],
  };
}
