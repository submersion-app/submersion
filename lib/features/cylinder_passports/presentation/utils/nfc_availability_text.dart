import 'package:submersion/features/cylinder_passports/data/services/nfc_tag_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Why NFC actions are off (spec 13.3), or null when they are available or
/// the check has not finished.
String? nfcUnavailableReason(AppLocalizations l10n, NfcSupport? support) =>
    switch (support) {
      NfcSupport.disabled => l10n.passport_nfc_disabled,
      NfcSupport.unsupported => l10n.passport_nfc_unsupported,
      NfcSupport.enabled || null => null,
    };
