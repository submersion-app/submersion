import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';

/// The transmitter key editor's form as the diver sees it (issue #4527,
/// phase 4): texts as typed, choices as picked. [configured] is what Save
/// writes, always true from the form; a downloaded key not yet set up opens
/// on a draft that says false, so confirming it is a change.
typedef TransmitterKeyDraft = ({
  String serial,
  String? computerId,
  String channel,
  TankRole role,
  String? cylinderId,
  String? presetName,
  String volume,
  String pressure,
  TankMaterial? material,
  bool configured,
});

/// The key editor's form with nothing in it: what a new key opens on,
/// before the item's serial and its keys' setup fill it, so those count as
/// a seed (a change).
const TransmitterKeyDraft blankTransmitterKeyDraft = (
  serial: '',
  computerId: null,
  channel: '',
  role: TankRole.backGas,
  cylinderId: null,
  presetName: null,
  volume: '',
  pressure: '',
  material: null,
  configured: true,
);

/// Litres per cubic foot.
const _litersPerCuft = 28.3168;

/// A number the form's validators already accepted; blank is "not set".
double? _number(String text) => switch (readNumber(text)) {
  NumberValue(:final value) => value,
  _ => null,
};

/// The draft's channel, from 1, when it names one with a computer.
int? _channel(TransmitterKeyDraft draft) {
  final channel = _number(draft.channel)?.toInt();
  return draft.computerId != null && channel != null && channel >= 1
      ? channel
      : null;
}

/// Whether [draft] names a key: a serial, or a computer and a channel of 1
/// or more.
bool transmitterDraftNamesKey(TransmitterKeyDraft draft) =>
    draft.serial.trim().isNotEmpty || _channel(draft) != null;

/// The key Save writes for the Transmitter item [itemId]: a new key with
/// [id] when [stored] is null; otherwise [stored], with each field whose
/// draft value differs from [start]'s taken from [draft] and the rest kept
/// as stored, so a value a sync changed meanwhile in a field the diver left
/// alone is not written back over. A [start] of null takes every field from
/// [draft]. Labelled [itemName], the item's name, and configured. Assumes
/// the form has validated.
Transmitter transmitterKeyToSave({
  required TransmitterKeyDraft draft,
  required TransmitterKeyDraft? start,
  required Transmitter? stored,
  required String id,
  required String? diverId,
  required String itemId,
  required String itemName,
  required AppSettings settings,
  required DateTime now,
}) {
  final base = stored;
  final from = base == null ? null : start;
  bool changed(Object? Function(TransmitterKeyDraft d) field) =>
      from == null || field(draft) != field(from);

  final serial = draft.serial.trim();
  final channel = _channel(draft);
  final keyPairChanged =
      changed((d) => d.computerId) || changed((d) => d.channel);

  // In cubic feet the size shown is a capacity at the working pressure, so
  // a new pressure gives a new volume as well.
  final inCuft = settings.volumeUnit == VolumeUnit.cubicFeet;
  final pressureChanged = changed((d) => d.pressure);
  final volumeChanged = changed((d) => d.volume) || (inCuft && pressureChanged);
  final pressureDisplay = _number(draft.pressure);
  final workingPressureBar = pressureChanged || base == null
      ? (pressureDisplay == null
            ? null
            : UnitFormatter(settings).pressureToBar(pressureDisplay))
      : base.workingPressureBar;
  final volumeDisplay = _number(draft.volume);
  final double? volumeL;
  if (!volumeChanged && base != null) {
    volumeL = base.volumeL;
  } else if (volumeDisplay == null) {
    volumeL = null;
  } else {
    // In cubic feet a size with no working pressure is read at the one the
    // app assumes, as it is shown: never as that many litres.
    volumeL = inCuft
        ? volumeDisplay *
              _litersPerCuft /
              (workingPressureBar != null && workingPressureBar > 0
                  ? workingPressureBar
                  : assumedWorkingPressureBar)
        : volumeDisplay;
  }

  return Transmitter(
    id: base?.id ?? id,
    diverId: base?.diverId ?? diverId,
    transmitterSerial: changed((d) => d.serial)
        ? (serial.isEmpty ? null : serial)
        : base!.transmitterSerial,
    diveComputerId: keyPairChanged
        ? (channel == null ? null : draft.computerId)
        : base!.diveComputerId,
    channelIndex: keyPairChanged
        ? (channel == null ? null : channel - 1)
        : base!.channelIndex,
    label: itemName,
    role: changed((d) => d.role) ? draft.role : base!.role,
    volumeL: volumeL,
    workingPressureBar: workingPressureBar,
    material: changed((d) => d.material) ? draft.material : base!.material,
    presetName: changed((d) => d.presetName)
        ? draft.presetName
        : base!.presetName,
    equipmentId: changed((d) => d.cylinderId)
        ? draft.cylinderId
        : base!.equipmentId,
    transmitterEquipmentId: itemId,
    isConfigured: true,
    createdAt: base?.createdAt ?? now,
    updatedAt: now,
  );
}
