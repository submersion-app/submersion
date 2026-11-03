import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/platform/device_capabilities.dart';
import 'package:submersion/features/settings/presentation/providers/account_group_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Store kinds a browser cannot sign in to at all, each with the reason the
/// connect step shows under a disabled tile (issue #4121): iCloud is only
/// reachable from the apps on Apple devices, and Git hosts refuse requests
/// from a web page. Native builds have none; a kind they lack is simply
/// not offered.
final unavailableAccountKindsProvider =
    Provider<Map<AccountKindOffer, String Function(AppLocalizations)>>((ref) {
      final caps = ref.watch(deviceCapabilitiesProvider);
      if (!caps.isBrowser) return const {};
      return {
        if (!caps.cloudICloud)
          AccountKindOffer.icloud: (l10n) => l10n.web_unavailable_offer_icloud,
        if (!caps.cloudGit)
          AccountKindOffer.git: (l10n) => l10n.web_unavailable_offer_git,
      };
    });
