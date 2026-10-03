/// Maps a Suunto cloud/app `sml` dive-event -- `DiveEvents.<Subgroup>.Type` as
/// a descriptor string -- to a libdivecomputer-style event-type string
/// (consumed by the dive-computer repository's `_mapEventTypeString`) plus the
/// watch's native `(sub-group << 8) | type` code.
///
/// The string ⇄ code correspondence is Suunto's own descriptor library, as
/// decoded from a Nautic's `/Logbook/byId/<id>/Descriptors` (5 enums under
/// `com.stt.android.domain.sml`: `AlarmMarkType`, `WarningMarkType`,
/// `NotifyMarkType`, `StateMarkType`, `OoamMarkType`).
///
/// A cloud dive-event carries `Active: true` on its begin edge and, on some
/// generations, `Active: false` on the end edge; only the begin edge is a
/// marker. The older `DiveEvents` *object* shape has no `Active` field -- treat
/// it as a begin.
///
/// The native code is stored on `DownloadedEvent.value`, and from there on the
/// event's `value` column; `SuuntoNativeEvent.of` decodes it so the profile
/// marker shows the watch's exact wording (#1523).
library;

/// The libdivecomputer event-type string and native code for one cloud event.
class SuuntoCloudEvent {
  const SuuntoCloudEvent(this.downloadedType, [this.nativeCode]);

  /// A value `_mapEventTypeString` understands. Where libdivecomputer has no
  /// event type precise enough, this names the `ProfileEventType` directly.
  final String downloadedType;

  /// `(sub-group << 8) | type` for the sub-group it was found under, or null
  /// for a legacy string that has no place in the Nautic descriptor.
  final int? nativeCode;
}

const int _alarm = 0x18;
const int _warning = 0x19;
const int _notify = 0x1A;
const int _state = 0x1B;
const int _ooam = 0x1D;

/// `subgroup key` → (`Type` string → mapping). Types deliberately left out
/// (Battery, Sidemount, "... Ahead" predictive states, Recovery time, Setpoint
/// on an OC watch, bearings/stopwatch) resolve to `null` and are not imported.
const Map<String, Map<String, SuuntoCloudEvent>> _table = {
  'Alarm': {
    // libdivecomputer's 'PO2' reads as high ppO2, so the low alarm names its
    // own type.
    'PO2 Low': SuuntoCloudEvent('ppO2Low', (_alarm << 8) | 1),
    'PO2 High': SuuntoCloudEvent('PO2', (_alarm << 8) | 2),
    'Tank Pressure': SuuntoCloudEvent('airtime', (_alarm << 8) | 3),
    'Gas Time': SuuntoCloudEvent('airtime', (_alarm << 8) | 4),
    'Ascent Speed': SuuntoCloudEvent('ascent', (_alarm << 8) | 5),
    'Ascent too fast': SuuntoCloudEvent('ascent', (_alarm << 8) | 5),
    'CNS100%': SuuntoCloudEvent('cnsCritical', (_alarm << 8) | 7),
    'OTU300': SuuntoCloudEvent('cnsCritical', (_alarm << 8) | 8),
    'Deco Stop Broken': SuuntoCloudEvent('ceiling', (_alarm << 8) | 10),
    // 'deepstop' is the stop itself and would read as a stop start; breaking
    // it is a violation.
    'Deep Stop Broken': SuuntoCloudEvent('violation', (_alarm << 8) | 12),
    'Safety Stop Broken': SuuntoCloudEvent('missedStop', (_alarm << 8) | 13),
  },
  'Warning': {
    'User PO2 High': SuuntoCloudEvent('PO2', (_warning << 8) | 6),
    'CNS80%': SuuntoCloudEvent('cnsWarning', (_warning << 8) | 14),
    'OTU250': SuuntoCloudEvent('cnsWarning', (_warning << 8) | 15),
    'NoDecoTime': SuuntoCloudEvent('lowNoDecoTime', (_warning << 8) | 20),
    'User Tank Pressure': SuuntoCloudEvent('airtime', (_warning << 8) | 28),
    'User Gas Time': SuuntoCloudEvent('airtime', (_warning << 8) | 29),
  },
  'State': {
    'Ndl exceeded': SuuntoCloudEvent('decompressionDive', (_state << 8) | 19),
    'At Deco Stop': SuuntoCloudEvent('deco', (_state << 8) | 35),
    'At Deep Stop': SuuntoCloudEvent('deepstop', (_state << 8) | 36),
    'At Safety Stop': SuuntoCloudEvent('safetystop', (_state << 8) | 37),
  },
  'Notify': {
    'Gas Switch': SuuntoCloudEvent('gaschange', (_notify << 8) | 11),
    'User Tank Pressure': SuuntoCloudEvent('airtime', (_notify << 8) | 28),
    'User Gas Time': SuuntoCloudEvent('airtime', (_notify << 8) | 29),
    // An older, non-Nautic string (the Nautic descriptor announces the stop
    // through State "At Safety Stop"); it has no Notify type number, so no
    // native code.
    'Safety Stop': SuuntoCloudEvent('safetystop'),
  },
  'Ooam': {'Ceiling broken': SuuntoCloudEvent('ceiling', (_ooam << 8) | 2)},
};

/// Looks up a cloud dive-event. [subgroup] is the JSON key
/// (`Alarm`/`Warning`/`Notify`/`State`/`Ooam`); [type] is its `Type` string.
/// Returns `null` for an unknown or deliberately-unimported event.
SuuntoCloudEvent? suuntoCloudEvent(String subgroup, String? type) {
  if (type == null) return null;
  return _table[subgroup]?[type];
}

/// Every `(subgroup, Type)` pair [suuntoCloudEvent] recognizes.
Iterable<(String, String)> get suuntoCloudEventKeys => [
  for (final MapEntry(key: subgroup, value: types) in _table.entries)
    for (final type in types.keys) (subgroup, type),
];
