import 'package:submersion/core/theme/status_colors.dart';
import 'package:submersion/features/certifications/domain/entities/credential_currency.dart';

/// The status swatch a currency severity draws with (issue #2267), mirroring
/// the gear service severity mapping: lapsed is alert, due soon is warn, and
/// a current credential carries no status colour.
StatusSwatch? currencySeveritySwatch(
  StatusColors colors,
  CurrencySeverity severity,
) => switch (severity) {
  CurrencySeverity.lapsed => colors.alert,
  CurrencySeverity.dueSoon => colors.warn,
  CurrencySeverity.current => null,
};
