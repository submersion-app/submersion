/// The Dives, Buddies and Trips country flag switches (v396, issue #5001),
/// as the sync wire names them.
const diverSettingsFlagSwitchKeys = [
  'showDiveCountryFlags',
  'showBuddyCountryFlags',
  'showTripCountryFlags',
];

/// Issue #5001. A diver_settings row from a peer older than v396 carries
/// none of [diverSettingsFlagSwitchKeys], only `showCountryFlags`, which on
/// that peer covers every flag. `_withLocalForOmitted` already kept this
/// device's switches for a row it holds; for a row new here, each missing
/// switch takes the payload's own `showCountryFlags` before the column
/// default (on) would fill it, so a diver who turned flags off does not get
/// them back on a newly set up device.
Map<String, dynamic> withDerivedFlagSwitches(
  String entityType,
  Map<String, dynamic> data,
) {
  if (entityType != 'diverSettings') return data;
  final legacy = data['showCountryFlags'];
  if (legacy is! bool) return data;
  final missing = [
    for (final key in diverSettingsFlagSwitchKeys)
      if (data[key] == null) key,
  ];
  if (missing.isEmpty) return data;
  return {...data, for (final key in missing) key: legacy};
}
