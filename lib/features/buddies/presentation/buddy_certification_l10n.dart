import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/certifications/presentation/certification_agency_display.dart';
import 'package:submersion/features/certifications/presentation/certification_level_display.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Locale-aware counterpart of [Buddy.certificationLine] (issue #1303).
///
/// [Buddy.certificationLine] stays English: it feeds the CSV/Excel field
/// extractor and the English buddy PDF, where a stable value is wanted. This
/// renders the level and agency through the active locale for the on-screen
/// buddy list, detail header, picker and summary. The stored "Name on the
/// card" ([Buddy.certificationTitle]) is the diver's own text and is never
/// translated.
String? buddyCertificationLineL10n(Buddy buddy, AppLocalizations l10n) {
  final title =
      buddy.certificationTitle ?? buddy.certificationLevel?.localizedName(l10n);
  final agency = buddy.certificationAgency;
  if (title == null) {
    return agency == null || agency == CertificationAgency.other
        ? null
        : agency.localizedName(l10n);
  }
  if (agency == null || agency == CertificationAgency.other) {
    return title;
  }
  // A stored "Name on the card" often already spells out the agency in its
  // own casing/spacing ("Padi Rescue Diver", "PADI - Rescue Diver"). Compare
  // loosely against both the localized agency name and its English
  // displayName so the suffix is not appended a second time regardless of the
  // locale the name was typed in.
  String loose(String s) => s.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  final looseTitle = loose(title);
  if (looseTitle.contains(loose(agency.localizedName(l10n))) ||
      looseTitle.contains(loose(agency.displayName))) {
    return title;
  }
  return '$title · ${agency.localizedName(l10n)}';
}
