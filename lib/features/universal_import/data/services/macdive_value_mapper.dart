import 'package:submersion/core/constants/enums.dart';

/// Static mappings from MacDive's raw XML string values to Submersion's
/// typed domain enums. Used by the MacDive XML parser and will also be
/// used by the MacDive SQLite parser (Milestone 3).
///
/// Mapping strategy: case-insensitive, substring-based. Unknown or empty
/// input returns null so the importer can omit the field rather than
/// write a default that misrepresents the data.
class MacDiveValueMapper {
  const MacDiveValueMapper._();

  static WaterType? waterType(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;
    if (s.contains('salt') || s == 'sea' || s == 'ocean') {
      return WaterType.salt;
    }
    if (s.contains('fresh') || s == 'lake' || s == 'river' || s == 'quarry') {
      return WaterType.fresh;
    }
    if (s.contains('brackish')) {
      return WaterType.brackish;
    }
    return null;
  }

  static EntryMethod? entryType(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;

    if (s == 'shore' || s == 'beach') {
      return EntryMethod.shore;
    }
    if (s.contains('boat') || s.contains('liveaboard')) {
      return EntryMethod.boat;
    }
    if (s.contains('back') && s.contains('roll')) {
      return EntryMethod.backRoll;
    }
    if ((s.contains('front') || s.contains('forward')) && s.contains('roll')) {
      return EntryMethod.frontRoll;
    }
    if (s.contains('giant') && s.contains('stride')) {
      return EntryMethod.giantStride;
    }
    if (s.contains('seated')) {
      return EntryMethod.seatedEntry;
    }
    if (s == 'ladder') {
      return EntryMethod.ladder;
    }
    if (s == 'platform') {
      return EntryMethod.platform;
    }
    if (s.contains('jetty') || s.contains('dock')) {
      return EntryMethod.jetty;
    }

    return null;
  }

  /// Maps a MacDive 0.0-5.0 rating to an integer 0-5. Clamps out-of-range
  /// values. Returns null for null input.
  static int? rating(double? raw) {
    if (raw == null) return null;
    return raw.clamp(0.0, 5.0).round();
  }

  /// Normalizes a MacDive dive-type string to a trimmed canonical form.
  /// MacDive uses arbitrary dive-type labels; Submersion doesn't constrain
  /// to an enum. Callers who need to create DiveTypes entities pass the
  /// result as a tag name.
  static String normalizeDiveType(String raw) => raw.trim();

  /// "Shear" or "shears" as a whole word, for [equipmentType].
  static final _shearWord = RegExp(r'\bshears?\b');

  /// "SCR" as a whole word, allowing the one-letter prefix divers write
  /// (pSCR). As a bare substring "scr" sits inside "prescription", so every
  /// prescription mask read as a rebreather. "CCR" needs no such guard and
  /// stays a substring, so a one-word "JJCCR" still matches.
  static final _scrWord = RegExp(r'\b[a-z]?scrs?\b');

  /// Camera part words (#1997) that are only safe as whole words: "port"
  /// sits inside "transport" and "support", "arm" inside "alarm" and "warm",
  /// and "tray" inside "stray". A float is a camera part only beside an arm
  /// or a collar: on its own, "float" in a dive log is a surface or flag
  /// float.
  static final _cameraFloat = RegExp(
    r'\bfloat\s*(?:arms?|collars?)\b|\b(?:arm|buoyancy)\s*(?:floats?|arms?)\b',
  );
  static final _videoLight = RegExp(r'\bvideo\s*(?:lights?|lamps?)\b');

  /// An arm, but not the forearm kit a diver straps on: an "arm slate" is a
  /// writing slate and "arm warmers" are thermal wear.
  static final _armWord = RegExp(r'\barms?\b(?!\s*(?:slates?|warmers?)\b)');
  static final _trayWord = RegExp(r'\btrays?\b');
  static final _portWord = RegExp(r'\bports?\b');
  static final _lensWord = RegExp(r'\blens(es)?\b');

  /// A name that ends on "bag", the noun the words before it qualify, for
  /// [equipmentType] (#2952): a "regulator bag" is a bag, not a regulator.
  static final _bagHeadNoun = RegExp(r'\bbags?$');

  /// A trailing note in parentheses ("Fin bag (large)"), set aside before
  /// the bag checks so neither its position nor its words move the head
  /// noun.
  static final _trailingNote = RegExp(r'\s*\([^)]*\)$');

  /// A joining word that hangs a bag off another item ("BCD w/ bag",
  /// "camera with bag"), so the item, not the bag, is what the name lists.
  static final _accessoryJoin = RegExp(r'\b(?:with|and)\b|w/|&|\+');

  /// A bag that lifts rather than carries, for [equipmentType] (#2952).
  /// Spelled as one word ("Liftbag") or hyphenated as often as not. Shared
  /// with the divelogs.de geartype table so the two readers agree.
  static final liftBag = RegExp(r'\b(?:lift|lifting|salvage)[\s-]*bags?\b');

  /// A rebreather counterlung, for [equipmentType] (#2952). Shared with the
  /// divelogs.de geartype table so the two readers agree.
  static final breathingBag = RegExp(r'\bbreathing[\s-]*bags?\b');

  /// Maps MacDive's free-text equipment type onto [EquipmentType].
  ///
  /// MacDive lets the diver type anything into the field, so real libraries
  /// contain values like "BCD - Wing", "Reg - Longhose" and "Octopus" that do
  /// not match an enum name. Without this, `_parseEquipmentType` fell through
  /// to [EquipmentType.other] for nearly every imported item.
  ///
  /// Returns null for empty input so the importer keeps its own default.
  static EquipmentType? equipmentType(String? raw) {
    final s = raw?.trim().toLowerCase();
    if (s == null || s.isEmpty) return null;

    // Bags (#2952) come first, because the item words that name what a bag
    // holds ("Reg bag", "Drysuit bag", "Fin bag") would otherwise claim it.
    // A lift bag is a lift device and files with the SMB. A breathing bag
    // is a rebreather's counterlung, a part with no type of its own, so it
    // stays Other rather than reading as luggage or as the whole unit. A
    // bare "bag" anywhere else in a name is weaker and waits at the bottom.
    if (liftBag.hasMatch(s)) return EquipmentType.smb;
    if (breathingBag.hasMatch(s)) return EquipmentType.other;
    final head = s.replaceFirst(_trailingNote, '');
    if (_bagHeadNoun.hasMatch(head) && !_accessoryJoin.hasMatch(head)) {
      return EquipmentType.bag;
    }

    // Ordered longest-idea-first: "drysuit" must beat "suit", and the
    // regulator family must not swallow "octopus", which is its own type in
    // neither vocabulary but reads as a regulator to divers.
    //
    // The drysuit layers (#1537) come before the suits they go under, but
    // only on words that name the garment outright: a "thermal undersuit"
    // must not be read as a wetsuit, and "dry undersuit" -- a real product
    // name -- must not be read as a drysuit. Fabric words are a weaker
    // signal and are handled further down, below the accessories.
    if (s.contains('undersuit') ||
        s.contains('under suit') ||
        s.contains('undergarment') ||
        s.contains('under garment')) {
      return EquipmentType.undersuit;
    }
    if (s.contains('baselayer') ||
        s.contains('base layer') ||
        s.contains('base-layer')) {
      return EquipmentType.baselayer;
    }
    // Same rule, same place (#1518): these name the garment outright, and
    // neither suit check matches them. Spelled out rather than matching a
    // bare "rash", which is a substring of "trash" -- and a trash bag is
    // ordinary kit on a cleanup dive. The fabric word "lycra" is a weaker
    // signal and waits below, with the thermal ones.
    if (s.contains('rash guard') ||
        s.contains('rashguard') ||
        s.contains('rash-guard') ||
        s.contains('rash vest') ||
        s.contains('rash top') ||
        s.contains('rashie') ||
        s.contains('skin suit')) {
      return EquipmentType.rashGuard;
    }
    // Rig accessories (#1877), which divers had been filing under BCD. Only
    // compound names land here, above the suit, BCD, tank and weight words
    // they contain: a "drysuit thigh pocket" is a pocket and a "tank band" is
    // not a tank. A bare "pocket" is weaker and waits at the very bottom.
    if (s.contains('cam band') ||
        s.contains('cam strap') ||
        s.contains('tank band') ||
        s.contains('tank strap') ||
        s.contains('cylinder band')) {
      return EquipmentType.tankBand;
    }
    if (s.contains('weight pocket') ||
        s.contains('weight pouch') ||
        s.contains('trim pocket') ||
        s.contains('trim pouch')) {
      return EquipmentType.weightPocket;
    }
    if (s.contains('gear pocket') ||
        s.contains('thigh pocket') ||
        s.contains('utility pocket') ||
        s.contains('cargo pocket')) {
      return EquipmentType.gearPocket;
    }
    if (s.contains('drysuit') || s.contains('dry suit')) {
      return EquipmentType.drysuit;
    }
    if (s.contains('wetsuit') || s.contains('wet suit')) {
      return EquipmentType.wetsuit;
    }
    if (s.contains('rebreather') ||
        s.contains('ccr') ||
        _scrWord.hasMatch(s) ||
        s.contains('scrubber')) {
      return EquipmentType.rebreather;
    }
    // Before the light/camera family: a scooter is often logged by brand and
    // model with "DPV" or "Scooter" as the only generic word in the label.
    if (s.contains('dpv') ||
        s.contains('scooter') ||
        s.contains('propulsion')) {
      return EquipmentType.dpv;
    }
    if (s.contains('transmitter') || s.contains('ai ')) {
      return EquipmentType.transmitter;
    }
    if (s.contains('computer') || s.contains('watch')) {
      return EquipmentType.computer;
    }
    // After the computer, so a "console computer" stays a computer, and
    // before the instrument family, because a compass console is carried --
    // and thought of -- as a compass.
    if (s.contains('compass')) return EquipmentType.compass;
    if (s.contains('spg') ||
        s.contains('gauge') ||
        s.contains('console') ||
        s.contains('bottom timer') ||
        s.contains('analyser') ||
        s.contains('analyzer')) {
      return EquipmentType.instrument;
    }
    // Regulator parts (issue #1487). The stage words are more specific than
    // the regulator family and win even beside "reg"; a bare hose word wins
    // only when nothing names the regulator, so "Reg - Longhose", which a
    // real library uses for its whole regulator, stays a regulator.
    if (s.contains('first stage')) return EquipmentType.firstStage;
    if (s.contains('second stage')) return EquipmentType.secondStage;
    if (s.contains('octo') || s.contains('regulator') || s.startsWith('reg')) {
      return EquipmentType.regulator;
    }
    if (s.contains('hose')) return EquipmentType.hose;
    if (s.contains('bcd') || s.contains('bc ') || s == 'bc') {
      return EquipmentType.bcd;
    }
    // Backplate-and-wing parts (issue #1487), after the whole-BCD words so
    // "BCD - Wing" stays a BCD. A plate-and-harness listing is the plate.
    if (s.contains('backplate')) return EquipmentType.backplate;
    if (s.contains('wing')) return EquipmentType.wing;
    if (s.contains('harness')) return EquipmentType.harness;
    if (s.contains('tank') || s.contains('cylinder')) return EquipmentType.tank;
    if (s.contains('weight') || s.contains('ballast')) {
      return EquipmentType.weights;
    }
    if (s.contains('fin')) return EquipmentType.fins;
    if (s.contains('mask') || s.contains('goggle')) return EquipmentType.mask;
    if (s.contains('snorkel')) return EquipmentType.snorkel;
    if (s.contains('hood')) return EquipmentType.hood;
    if (s.contains('glove') || s.contains('mitt')) return EquipmentType.gloves;
    if (s.contains('boot') || s.contains('bootie')) return EquipmentType.boots;
    // The thermal words land here, below every garment they could be printed
    // on. "Thermal" and "wicking" name a fabric rather than a garment, and
    // even the plural noun "thermals" -- which does name the garment on its
    // own -- loses to an accessory word sitting next to it, so "Thermals
    // gloves" is gloves while "Fourth Element Thermals" is a base layer.
    // Explicit "base layer" and the suits are matched far above, so nothing
    // here can steal a label that already named itself.
    // A lycra hood and lycra gloves are real products, and both are caught
    // above, so the fabric only reaches here on a garment nothing else
    // claimed.
    if (s.contains('lycra')) return EquipmentType.rashGuard;
    if (s.contains('thermals')) return EquipmentType.baselayer;
    if ((s.contains('thermal') || s.contains('wicking')) &&
        (s.contains('top') ||
            s.contains('layer') ||
            s.contains('shirt') ||
            s.contains('underwear') ||
            s.contains('leggings') ||
            s.contains('vest'))) {
      return EquipmentType.baselayer;
    }
    // The camera's parts (#1997), above the light and camera words they
    // contain: a "video light" is not a dive light and a "camera tray" is
    // not a camera.
    final cameraPart = cameraPartType(s);
    if (cameraPart != null) return cameraPart;
    if (s.contains('light') || s.contains('torch')) return EquipmentType.light;
    // Photo rig parts (issue #1487) before the camera family.
    if (s.contains('housing')) return EquipmentType.housing;
    if (s.contains('strobe')) return EquipmentType.strobe;
    if (s.contains('camera') || s.contains('gopro')) {
      return EquipmentType.camera;
    }
    if (s.contains('smb') ||
        s.contains('dsmb') ||
        s.contains('buoy') ||
        s.contains('sausage')) {
      return EquipmentType.smb;
    }
    if (s.contains('reel') || s.contains('spool')) return EquipmentType.reel;
    // "Shear" only as a word: as a substring it sits inside "Shearwater",
    // and every Shearwater computer read as a knife (#2299).
    if (s.contains('knife') || _shearWord.hasMatch(s) || s.contains('cutter')) {
      return EquipmentType.knife;
    }
    if (s.contains('tool') ||
        s.contains('wrench') ||
        s.contains('spanner') ||
        s.contains('o-ring') ||
        s.contains('o ring') ||
        s.contains('save a dive') ||
        s.contains('save-a-dive')) {
      return EquipmentType.tool;
    }
    // Last of all: "pocket" is also a size word on real products, so every
    // specific item word wins over it. "Pocket knife" stays a knife, "soft
    // pocket weights" stay lead and "BCD w/ pockets" stays a BCD.
    if (s.contains('pocket')) return EquipmentType.gearPocket;
    if (s.contains('bag') ||
        s.contains('duffel') ||
        s.contains('duffle') ||
        s.contains('luggage') ||
        s.contains('suitcase')) {
      return EquipmentType.bag;
    }
    return EquipmentType.other;
  }

  /// The camera part (#1997) a lower-cased, trimmed name [s] names, or null.
  ///
  /// Shared with the divelogs.de geartype table, as [liftBag] is, so the two
  /// readers agree on every camera word. Callers run it after their mask,
  /// suit and weight checks and before the light and camera words. A float
  /// arm is checked before the arms it is one of, and an arm before the
  /// strobe it carries.
  static EquipmentType? cameraPartType(String s) {
    if (_cameraFloat.hasMatch(s)) return EquipmentType.floatArm;
    if (_armWord.hasMatch(s) || s.contains('clamp')) {
      return EquipmentType.armClamp;
    }
    if (_trayWord.hasMatch(s) || s.contains('pistol grip')) {
      return EquipmentType.trayHandle;
    }
    if (_videoLight.hasMatch(s)) return EquipmentType.videoLight;
    if (_portWord.hasMatch(s)) return EquipmentType.port;
    if (_lensWord.hasMatch(s) || s.contains('diopter')) {
      return EquipmentType.lens;
    }
    return null;
  }
}
