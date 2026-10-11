import 'package:submersion/features/cylinder_passports/presentation/widgets/nfc_write_sheet.dart';
import 'package:submersion/features/gear_passports/domain/entities/gear_tag_payload.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_codec.dart';
import 'package:submersion/features/gear_passports/domain/services/gear_tag_ndef.dart';
import 'package:submersion/features/gear_passports/domain/services/tag_link_codec.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// A readable name for a gear tag key left off a small tag.
String gearTagFieldLabel(AppLocalizations l10n, String key) => switch (key) {
  'ls' => l10n.gearPassport_field_lastService,
  'mo' => l10n.equipment_detail_modelLabel,
  'b' => l10n.equipment_detail_brandLabel,
  'sn' => l10n.equipment_detail_serialNumberLabel,
  'n' => l10n.passport_nfc_fieldName,
  _ => key,
};

TagWriteRequest gearTagWriteRequest(GearTagPayload payload) => TagWriteRequest(
  fullUrl: GearTagCodec.httpsUrl(payload),
  planFor: (max) => planGearMessage(payload, maxMessageBytes: max),
  fieldLabel: gearTagFieldLabel,
);

/// The passport id of a tag link of either kind, or null for anything else.
/// An item's Link an existing tag takes both: the id is the identity, and
/// an item retyped from a tank keeps the cylinder tag on its body.
String? tagPassportIdOf(String text) => TagLinkCodec.passportIdOf(text);
