/// Normalizes the computer-identity text a cloud import carries, so the
/// Garmin and Suunto adapters agree on what counts as "absent".
///
/// Both adapters read a model/name, a serial and a firmware string off a
/// parsed dive, and all three are nullable strings that may also arrive
/// present-but-blank: Suunto's come straight out of the cloud JSON, and
/// nothing in either adapter's input type rules an empty string out.
///
/// [normalizedIdentityPart] returns null for absent, empty or whitespace-only
/// text, which is what lets a plain `?? 'Garmin'` fallback actually fire.
/// Writing it as `value?.trim() ?? fallback` does not: `''.trim()` is `''`,
/// not null, so the `??` is skipped and the computer is registered with an
/// empty name, or stored with an empty serial that no later lookup matches.
///
/// This mirrors what `DiveComputerRepository.findOrRegisterImportedComputer`
/// already does on the file-import path, so a cloud import and a file import
/// of the same device do not produce two differently-shaped rows.
String? normalizedIdentityPart(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}
