import 'package:shared_preferences/shared_preferences.dart';

/// The data sources and dives the transmitter slot backfill has already
/// parsed on this device (issue #4347), so a dive whose parse yields no slot
/// is not parsed again every time the Apply dialog opens. Local and unsynced:
/// another device keeps its own.
abstract interface class TransmitterSlotBackfillMemo {
  Future<Set<String>> load();
  Future<void> add(Iterable<String> keys);
}

/// [TransmitterSlotBackfillMemo] in shared preferences.
class SharedPrefsSlotBackfillMemo implements TransmitterSlotBackfillMemo {
  static const _key = 'transmitter_slot_backfill_done_v1';

  @override
  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return {...?prefs.getStringList(_key)};
  }

  @override
  Future<void> add(Iterable<String> keys) async {
    if (keys.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, [
      ...{...?prefs.getStringList(_key), ...keys},
    ]);
  }
}
