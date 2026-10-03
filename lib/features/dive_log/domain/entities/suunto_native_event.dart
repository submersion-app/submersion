import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';

const int _alarm = 0x18;
const int _warning = 0x19;
const int _notify = 0x1A;
const int _state = 0x1B;
const int _ooam = 0x1D;

/// A Suunto watch's own event, identified by the native
/// `(sub-group << 8) | type` code the import stores on the event's `value`
/// (see `suunto_cloud_event_map.dart`).
///
/// Several of these share one [ProfileEventType] (a tank-pressure alarm and a
/// gas-time warning are both `lowGas`; a deco stop broken and a ceiling broken
/// are both `decoViolation`), so the code is what tells them apart on the
/// profile (#1523).
///
/// Codes whose [ProfileEventType] already names the event exactly (gas switch,
/// low no-deco time, became a deco dive) have no entry here.
enum SuuntoNativeEvent {
  // The cloud import typed this alarm as ppO2High before #1523; its stored
  // code still identifies it, so both types are accepted.
  lowPpo2Alarm((_alarm << 8) | 1, {
    ProfileEventType.ppO2Low,
    ProfileEventType.ppO2High,
  }),
  highPpo2Alarm((_alarm << 8) | 2, {ProfileEventType.ppO2High}),
  tankPressureAlarm((_alarm << 8) | 3, {ProfileEventType.lowGas}),
  gasTimeAlarm((_alarm << 8) | 4, {ProfileEventType.lowGas}),
  ascentRateAlarm((_alarm << 8) | 5, {ProfileEventType.ascentRateWarning}),
  cns100Alarm((_alarm << 8) | 7, {ProfileEventType.cnsCritical}),
  otu300Alarm((_alarm << 8) | 8, {ProfileEventType.cnsCritical}),
  decoStopBroken((_alarm << 8) | 10, {ProfileEventType.decoViolation}),
  // Typed decoStopStart before #1523, decoViolation since.
  deepStopBroken((_alarm << 8) | 12, {
    ProfileEventType.decoViolation,
    ProfileEventType.decoStopStart,
  }),
  safetyStopBroken((_alarm << 8) | 13, {ProfileEventType.missedStop}),
  highPpo2Warning((_warning << 8) | 6, {ProfileEventType.ppO2High}),
  cns80Warning((_warning << 8) | 14, {ProfileEventType.cnsWarning}),
  otu250Warning((_warning << 8) | 15, {ProfileEventType.cnsWarning}),
  tankPressureWarning((_warning << 8) | 28, {ProfileEventType.lowGas}),
  gasTimeWarning((_warning << 8) | 29, {ProfileEventType.lowGas}),
  tankPressureNotification((_notify << 8) | 28, {ProfileEventType.lowGas}),
  gasTimeNotification((_notify << 8) | 29, {ProfileEventType.lowGas}),
  decoStopReached((_state << 8) | 35, {ProfileEventType.decoStopStart}),
  deepStopReached((_state << 8) | 36, {ProfileEventType.decoStopStart}),
  safetyStopReached((_state << 8) | 37, {ProfileEventType.safetyStopStart}),
  ceilingBroken((_ooam << 8) | 2, {ProfileEventType.decoViolation});

  const SuuntoNativeEvent(this.code, this.eventTypes);

  /// The watch's `(sub-group << 8) | type`.
  final int code;

  /// The [ProfileEventType]s an import stores this event as. A stored code is
  /// only trusted when the event's type is one of these.
  final Set<ProfileEventType> eventTypes;

  static final Map<int, SuuntoNativeEvent> _byCode = {
    for (final event in values) event.code: event,
  };

  /// The event with [code], or null for a code with no entry. Runs for every
  /// marker on each chart layout and paint, hence the map.
  static SuuntoNativeEvent? fromCode(int code) => _byCode[code];

  /// The Suunto event [event] records, or null when it is not one: a
  /// computed or user event, an event whose computer is not a Suunto (or is
  /// unknown), a missing or non-integral value, an unknown code, or a code
  /// that does not fit the event's type.
  ///
  /// Every computer's events are stored as imported, and another vendor's
  /// `value` can be any number, so the manufacturer is the gate.
  static SuuntoNativeEvent? of(ProfileEvent event) {
    if (event.source != EventSource.imported) return null;
    if (event.computerManufacturer?.trim().toLowerCase() != 'suunto') {
      return null;
    }
    final value = event.value;
    if (value == null || !value.isFinite || value != value.roundToDouble()) {
      return null;
    }
    final match = fromCode(value.toInt());
    if (match == null || !match.eventTypes.contains(event.eventType)) {
      return null;
    }
    return match;
  }
}
