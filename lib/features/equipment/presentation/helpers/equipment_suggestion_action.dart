import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/app_version.dart';
import 'package:submersion/features/equipment/domain/services/equipment_suggestion_url.dart';
import 'package:submersion/features/equipment/presentation/helpers/equipment_web_link_launcher.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_suggestion_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/utils/link_open.dart';

/// The gear editor's Suggest a category link (issue #5103): asks for the
/// suggestion, then opens the prefilled issue form in the diver's browser,
/// offering to copy the link when no browser takes it. Nothing is sent from
/// the app.
///
/// [brand] and [model] are the item as currently edited, offered as an
/// example that stays out of the issue unless the diver ticks it.
Future<void> suggestEquipmentCategory(
  BuildContext context,
  WidgetRef ref, {
  required EquipmentType currentType,
  String? brand,
  String? model,
}) async {
  final example = [brand, model]
      .map((part) => part?.trim() ?? '')
      .where((part) => part.isNotEmpty)
      .join(' ');
  final suggestion = await showEquipmentSuggestionDialog(
    context,
    currentType: currentType,
    example: example,
  );
  if (suggestion == null || !context.mounted) return;
  // The language on screen: the stored setting is usually 'system'.
  final locale = Localizations.localeOf(context).toLanguageTag();
  // A version that cannot be read (the web build fetches version.json)
  // must not cost the diver the suggestion they just wrote.
  String appVersion;
  try {
    appVersion = formatAppVersion(await ref.read(packageInfoProvider.future));
  } catch (_) {
    appVersion = 'unknown';
  }
  if (!context.mounted) return;
  final uri = buildEquipmentSuggestionUrl(
    suggestion: suggestion,
    locale: locale,
    appVersion: appVersion,
  );
  await openLinkOrOfferCopy(
    context,
    uri,
    launch: ref.read(equipmentWebLinkLaunchProvider),
  );
}
