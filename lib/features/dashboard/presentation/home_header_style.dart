import 'package:submersion/features/dashboard/presentation/home_layout.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Which header Home shows: the slim bar with the status lights, or the
/// welcome banner with a row of quick actions and lights under it
/// (issue #5003). [name] is what is stored, so a value is never renamed.
enum HomeHeaderStyle { compact, banner }

/// The style a stored name stands for. Nothing stored, or a name this
/// version does not know, reads as [HomeHeaderStyle.compact].
HomeHeaderStyle homeHeaderStyleFromName(String? name) {
  for (final style in HomeHeaderStyle.values) {
    if (style.name == name) return style;
  }
  return HomeHeaderStyle.compact;
}

/// The header chosen for Home at [tier]: the phone choice at phone width,
/// the wide choice on tablets and desktops. Each is saved on the device.
HomeHeaderStyle homeHeaderStyleFor(AppSettings settings, HomeWidthTier tier) =>
    homeHeaderStyleFromName(
      tier == HomeWidthTier.phone
          ? settings.homeHeaderStylePhone
          : settings.homeHeaderStyleWide,
    );
