import 'package:intl/intl.dart';

/// Builds the default name offered when a dive plan is saved for the first
/// time.
///
/// Kept free of Flutter and Riverpod so it can be unit tested without a
/// provider container. Unit conversion happens in the caller: [depthLabel] is
/// already formatted in the diver's depth unit (for example `40m` or `130ft`),
/// which means the generated name freezes that unit into the stored string.
/// That is intentional. The name is a user-editable label, so regenerating it
/// after a unit switch would overwrite names the diver typed deliberately.
///
/// [fallbackLabel] is the localized word for a plan (for example `Dive Plan`)
/// and is used only when neither a site nor a depth is available.
String generateDefaultPlanName({
  String? siteName,
  String? depthLabel,
  required DateTime date,
  required String fallbackLabel,
}) {
  final site = siteName?.trim();
  final depth = depthLabel?.trim();

  final parts = <String>[
    if (site != null && site.isNotEmpty) site,
    if (depth != null && depth.isNotEmpty) depth,
  ];
  if (parts.isEmpty) parts.add(fallbackLabel);

  return '${parts.join(' ')} - ${DateFormat.MMMd().format(date)}';
}
