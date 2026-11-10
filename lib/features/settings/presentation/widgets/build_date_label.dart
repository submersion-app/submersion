import 'package:flutter/widgets.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/build_info.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The day this build was made, from the BUILD_DATE stamp; null for a local
/// or debug build (issue #4365).
///
/// A provider rather than a direct read of [appBuildDate] so tests can stand
/// in a date: the stamp is a compile-time constant they cannot set.
final buildDateProvider = Provider<DateTime?>((ref) => appBuildDate);

/// "Built 9 Nov 2026" in the diver's date format, or null when the build
/// carries no date, in which case the About screen shows no date line.
String? watchBuildDateLabel(BuildContext context, WidgetRef ref) {
  final date = ref.watch(buildDateProvider);
  if (date == null) return null;
  final formatted = ref.watch(unitFormatterProvider).formatDate(date);
  return context.l10n.settings_about_builtOn(formatted);
}
