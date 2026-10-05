import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/presentation/formatters/visibility_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/settings/presentation/conflicts/conflict_field.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Builds a labeler for an enum stored by name (or by [storedAs]). An unknown
/// stored value yields null so the formatter prints it as stored: a newer
/// peer may write a value this build has never heard of.
ConflictEnumLabeler enumLabeler<T extends Enum>(
  List<T> values,
  String Function(AppLocalizations l10n, T value) label, {
  String Function(T value)? storedAs,
}) {
  final byStored = {for (final v in values) (storedAs?.call(v) ?? v.name): v};
  return (l10n, stored) {
    final value = byStored[stored];
    return value == null ? null : label(l10n, value);
  };
}

final ConflictEnumLabeler entryMethodLabeler = enumLabeler(
  EntryMethod.values,
  (l, v) => v.localizedName(l),
);

/// The pre-v144 visibility bucket, still on dives logged before measured
/// visibility.
final ConflictEnumLabeler visibilityLabeler = enumLabeler(
  Visibility.values,
  (l, v) => visibilityName(v, l),
);

final ConflictEnumLabeler waterTypeLabeler = enumLabeler(
  WaterType.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler currentDirectionLabeler = enumLabeler(
  CurrentDirection.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler currentStrengthLabeler = enumLabeler(
  CurrentStrength.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler cloudCoverLabeler = enumLabeler(
  CloudCover.values,
  (l, v) => v.localizedName(l),
);

final ConflictEnumLabeler precipitationLabeler = enumLabeler(
  Precipitation.values,
  (l, v) => v.localizedName(l),
);
