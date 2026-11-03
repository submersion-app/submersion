import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_tank.dart';

/// The migration finder for cylinders a diver may want to re-role as a twin
/// set (issue #3374). Until the Twin Set role existed, the Tank
/// configuration chart guessed a twin set from a cylinder's name or size;
/// these rules are that guess, kept only so the Gas page can offer to
/// re-role the Back Gas cylinders it used to count. They are not a
/// classification rule: `classifyTankConfiguration` reads the role alone.

/// A single Back Gas cylinder this large looks like a twin set logged as
/// one: common single cylinders top out around 18 L, while 2x10 L, 2xAL80
/// (22.2 L) and 2x12 L all reach it.
const double twinSetMinVolumeLiters = 20.0;

final RegExp _twinWord = RegExp('twin|double|doppel|manifold');
// A twin-outlet valve on a single cylinder ("Doppelventil", "twin valve"):
// the word describes the valve, not the cylinder (issue #3374's report).
final RegExp _valvePhrase = RegExp(r'(twin|double|doppel)\s*(ventil|valve)s?');
// The 2 must start a number: "12x232" is a 12 L single by its pressure.
final RegExp _twinCount = RegExp(r'(?<![0-9.,])2\s*[x×]\s*\d');
final RegExp _twinDCode = RegExp(r'(?<![a-z0-9])d\d{1,2}(?![a-z0-9])');

/// Whether [tank] looks like a twin set logged as one cylinder: its name or
/// preset says so (twin, double, doppel, manifold, 2x12, D12), or it holds
/// [twinSetMinVolumeLiters] or more. A double valve ("Doppelventil", "twin
/// valve") is a valve, not a pair, and does not count. Preset names are
/// stored slugs such as `twin_12`, so an underscore separates words. Reads
/// nothing but the name, the preset and the size; see [isTwinSetCandidate]
/// for the role.
bool looksLikeTwinSet(DiveTank tank) {
  final volume = tank.volume;
  if (volume != null && volume >= twinSetMinVolumeLiters) return true;
  return _namesTwin(tank.name) || _namesTwin(tank.presetName);
}

/// Whether [tank] is one the re-role offer should name: a Back Gas cylinder
/// that [looksLikeTwinSet]. Any other role was a choice, so it stands.
bool isTwinSetCandidate(DiveTank tank) =>
    tank.role == TankRole.backGas && looksLikeTwinSet(tank);

bool _namesTwin(String? raw) {
  if (raw == null) return false;
  final text = raw
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(_valvePhrase, ' ');
  return _twinWord.hasMatch(text) ||
      _twinCount.hasMatch(text) ||
      _twinDCode.hasMatch(text);
}
