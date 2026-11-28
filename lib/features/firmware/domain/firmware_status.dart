import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/firmware/domain/firmware_catalogue.dart';

/// A maker or model name reduced to letters and digits, lower case, so
/// "Perdix 2", "perdix2" and "PERDIX-2" compare equal. A `+` names a
/// different model ("Puck Pro+" is not a "Puck Pro"), so it becomes "plus";
/// letters beyond Latin are kept.
String normalizeFirmwareName(String s) => s
    .toLowerCase()
    .replaceAll('+', 'plus')
    .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

/// The catalogue model an item of [type] made by [brand] as [model] is, or
/// null. The maker must match the model's maker or one of its aliases, the
/// model its name or one of its aliases, and the type must be one the entry
/// lists, so a light that shares a computer's name is never matched to it.
FirmwareModel? matchFirmwareModel(
  FirmwareCatalogue catalogue, {
  required EquipmentType type,
  required String? brand,
  required String? model,
}) {
  final b = normalizeFirmwareName(brand ?? '');
  final m = normalizeFirmwareName(model ?? '');
  if (b.isEmpty || m.isEmpty) return null;
  for (final entry in catalogue.models) {
    if (!entry.equipmentTypes.contains(type)) continue;
    final makers = [entry.manufacturer, ...entry.manufacturerAliases];
    if (!makers.any((name) => normalizeFirmwareName(name) == b)) continue;
    final names = [entry.model, ...entry.aliases];
    if (names.any((name) => normalizeFirmwareName(name) == m)) return entry;
  }
  return null;
}

/// A version compared without case, surrounding space, or a leading "v"
/// before a digit: "V95", "v95" and "95" are one release.
String _versionKey(String v) =>
    v.trim().toLowerCase().replaceFirst(RegExp(r'^v(?=\d)'), '');

/// Where [version] sits in [model]'s newest-first releases, by the maker's
/// spelling or any reported one, or null when the list does not have it.
int? releaseIndexOf(FirmwareModel model, String version) {
  final key = _versionKey(version);
  if (key.isEmpty) return null;
  for (var i = 0; i < model.releases.length; i++) {
    final release = model.releases[i];
    if (_versionKey(release.version) == key ||
        release.reportedAs.any((r) => _versionKey(r) == key)) {
      return i;
    }
  }
  return null;
}

/// Whether [a] and [b] name one release: the same text ignoring case and
/// surrounding space, or two spellings [model] lists under one release
/// ("V95" and a device's "95").
bool sameFirmwareRelease(String a, String b, {FirmwareModel? model}) {
  if (_versionKey(a) == _versionKey(b)) return true;
  if (model == null) return false;
  final ia = releaseIndexOf(model, a);
  return ia != null && ia == releaseIndexOf(model, b);
}

/// What the catalogue says about an item's firmware.
sealed class FirmwareStatus extends Equatable {
  const FirmwareStatus();
}

/// A status that found the item's model in the catalogue.
sealed class FirmwareListedStatus extends FirmwareStatus {
  final FirmwareModel model;
  const FirmwareListedStatus(this.model);

  FirmwareRelease get latest => model.releases.first;

  @override
  List<Object?> get props => [model];
}

/// The installed version is the newest release.
final class FirmwareUpToDate extends FirmwareListedStatus {
  const FirmwareUpToDate(super.model);
}

/// The installed version is in the list below [newer], newest first.
final class FirmwareUpdateAvailable extends FirmwareListedStatus {
  final List<FirmwareRelease> newer;
  const FirmwareUpdateAvailable(super.model, this.newer);

  @override
  List<Object?> get props => [model, newer];
}

/// The installed version is not in the list: never claimed as an update.
final class FirmwareUnknownVersion extends FirmwareListedStatus {
  const FirmwareUnknownVersion(super.model);
}

/// The model is listed but the item has no version recorded.
final class FirmwareNoVersion extends FirmwareListedStatus {
  const FirmwareNoVersion(super.model);
}

/// The item matches no catalogue model, or there is no catalogue.
final class FirmwareNotListed extends FirmwareStatus {
  const FirmwareNotListed();

  @override
  List<Object?> get props => const [];
}

/// The firmware status of an item of [type] made by [brand] as [model]
/// running [installedVersion].
FirmwareStatus firmwareStatusFor({
  required FirmwareCatalogue? catalogue,
  required EquipmentType type,
  required String? brand,
  required String? model,
  required String? installedVersion,
}) {
  if (catalogue == null) return const FirmwareNotListed();
  final entry = matchFirmwareModel(
    catalogue,
    type: type,
    brand: brand,
    model: model,
  );
  if (entry == null || entry.releases.isEmpty) {
    return const FirmwareNotListed();
  }
  final installed = installedVersion?.trim() ?? '';
  if (installed.isEmpty) return FirmwareNoVersion(entry);
  final index = releaseIndexOf(entry, installed);
  if (index == null) return FirmwareUnknownVersion(entry);
  if (index == 0) return FirmwareUpToDate(entry);
  return FirmwareUpdateAvailable(entry, entry.releases.sublist(0, index));
}
