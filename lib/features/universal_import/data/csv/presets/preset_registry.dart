import 'package:submersion/features/universal_import/data/csv/models/detection_result.dart';
import 'package:submersion/features/universal_import/data/csv/presets/csv_preset.dart';

/// Manages built-in and user-saved CSV presets.
///
/// Provides detection logic that scores a list of CSV headers against all
/// known presets and returns ranked matches above each preset's threshold.
class PresetRegistry {
  PresetRegistry({required List<CsvPreset> builtInPresets})
    : _builtInPresets = List.unmodifiable(builtInPresets),
      _userPresets = [];

  final List<CsvPreset> _builtInPresets;
  List<CsvPreset> _userPresets;

  /// All presets: built-in first, then user-saved.
  List<CsvPreset> get allPresets => [..._builtInPresets, ..._userPresets];

  /// Returns the preset with the given [id], or null if not found.
  CsvPreset? getPreset(String id) {
    for (final preset in allPresets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  /// Scores [headers] against every preset and returns matches whose score
  /// meets or exceeds the preset's [CsvPreset.matchThreshold], sorted
  /// descending by score.
  List<PresetMatch> detectPreset(List<String> headers) {
    final normalizedHeaders = headers
        .map((h) => h.toLowerCase().trim())
        .toSet();

    final matches = <PresetMatch>[];

    for (final preset in allPresets) {
      if (preset.signatureHeaders.isEmpty) continue;

      var matched = 0;
      for (final sig in preset.signatureHeaders) {
        if (normalizedHeaders.contains(sig.toLowerCase())) {
          matched++;
        }
      }

      final score = matched / preset.signatureHeaders.length;
      if (score >= preset.matchThreshold) {
        matches.add(
          PresetMatch(
            preset: preset,
            score: score,
            matchedHeaders: matched,
            totalSignatureHeaders: preset.signatureHeaders.length,
          ),
        );
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));
    return matches;
  }

  /// For multi-file presets, determines which [PresetFileRole] best matches
  /// the provided [headers].
  ///
  /// Returns the role whose signature headers yield the highest match score,
  /// or null if the preset has no file roles or no role scores above zero.
  PresetFileRole? identifyFileRole(CsvPreset preset, List<String> headers) {
    if (preset.fileRoles.isEmpty) return null;

    final normalizedHeaders = headers
        .map((h) => h.toLowerCase().trim())
        .toSet();

    PresetFileRole? bestRole;
    var bestScore = 0.0;

    for (final role in preset.fileRoles) {
      if (role.signatureHeaders.isEmpty) continue;

      var matched = 0;
      for (final sig in role.signatureHeaders) {
        if (normalizedHeaders.contains(sig.toLowerCase())) {
          matched++;
        }
      }

      final score = matched / role.signatureHeaders.length;
      if (score > bestScore) {
        bestScore = score;
        bestRole = role;
      }
    }

    return bestRole;
  }

  /// Adds a user-saved preset. Replaces any existing user preset with the
  /// same ID.
  void addUserPreset(CsvPreset preset) {
    _userPresets = [..._userPresets.where((p) => p.id != preset.id), preset];
  }

  /// Removes a user-saved preset by [id]. Has no effect if the ID refers
  /// to a built-in preset or does not exist.
  void removeUserPreset(String id) {
    _userPresets = _userPresets.where((p) => p.id != id).toList();
  }
}
