import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Represents a single keyboard shortcut entry for the help overlay.
@immutable
class ShortcutEntry {
  const ShortcutEntry({
    required this.label,
    required this.category,
    required this.activator,
    this.isGlobal = false,
  });

  /// Human-readable name (e.g., "New dive").
  final String label;

  /// Category for grouping in help overlay (e.g., "Navigation").
  final String category;

  /// The key combination that triggers this shortcut.
  final SingleActivator activator;

  /// Whether this shortcut is available globally or only on a specific page.
  final bool isGlobal;

  /// Returns a platform-appropriate display string (e.g., "Cmd+N" or "Ctrl+N").
  String displayKey(TargetPlatform platform) {
    final buffer = StringBuffer();
    final isMac = platform == TargetPlatform.macOS;

    if (activator.meta) buffer.write(isMac ? 'Cmd+' : 'Super+');
    if (activator.control) buffer.write(isMac ? 'Ctrl+' : 'Ctrl+');
    if (activator.alt) buffer.write(isMac ? 'Option+' : 'Alt+');
    if (activator.shift) buffer.write('Shift+');

    buffer.write(_keyLabel(activator.trigger));
    return buffer.toString();
  }

  String _keyLabel(LogicalKeyboardKey key) {
    // Map common keys to readable names
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.delete) return 'Delete';
    if (key == LogicalKeyboardKey.backspace) return 'Backspace';
    if (key == LogicalKeyboardKey.enter) return 'Enter';
    if (key == LogicalKeyboardKey.arrowUp) return 'Up';
    if (key == LogicalKeyboardKey.arrowDown) return 'Down';
    if (key == LogicalKeyboardKey.arrowLeft) return 'Left';
    if (key == LogicalKeyboardKey.arrowRight) return 'Right';
    if (key == LogicalKeyboardKey.slash) return '/';
    if (key == LogicalKeyboardKey.question) return '?';
    if (key == LogicalKeyboardKey.comma) return ',';

    // For letter keys, use uppercase
    final label = key.keyLabel;
    if (label.length == 1) return label.toUpperCase();
    return label;
  }
}

/// Central registry of all keyboard shortcuts in the application.
///
/// Used by the shortcuts help overlay to display available shortcuts.
/// Shortcuts are registered by the app shell (global) and individual pages
/// (context-specific).
class ShortcutCatalog {
  ShortcutCatalog._();

  static final ShortcutCatalog instance = ShortcutCatalog._();

  final List<ShortcutEntry> _entries = [];

  /// All registered shortcut entries.
  List<ShortcutEntry> get entries => List.unmodifiable(_entries);

  /// Entries grouped by category, sorted alphabetically.
  Map<String, List<ShortcutEntry>> get byCategory {
    final grouped = <String, List<ShortcutEntry>>{};
    for (final entry in _entries) {
      grouped.putIfAbsent(entry.category, () => []).add(entry);
    }
    // Sort categories: Global categories first, then alphabetical
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        const priority = ['Navigation', 'Search', 'Editing', 'General', 'Help'];
        final aIndex = priority.indexOf(a);
        final bIndex = priority.indexOf(b);
        if (aIndex >= 0 && bIndex >= 0) return aIndex.compareTo(bIndex);
        if (aIndex >= 0) return -1;
        if (bIndex >= 0) return 1;
        return a.compareTo(b);
      });
    return {for (final key in sortedKeys) key: grouped[key]!};
  }

  /// Register a single shortcut entry.
  void register(ShortcutEntry entry) {
    _entries.add(entry);
  }

  /// Register multiple shortcut entries at once.
  void registerAll(List<ShortcutEntry> entries) {
    _entries.addAll(entries);
  }

  /// Remove all entries in the given category.
  void unregisterCategory(String category) {
    _entries.removeWhere((e) => e.category == category);
  }

  /// Remove all registered entries.
  void clear() {
    _entries.clear();
  }
}
