import 'package:flutter/material.dart';
import 'package:submersion/core/models/log_entry.dart';

/// A single log entry row in the debug log viewer.
class LogEntryTile extends StatelessWidget {
  final LogEntry entry;

  const LogEntryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity icon
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              _severityIcon(entry.level),
              size: 14,
              color: _severityColor(entry.level, colorScheme),
            ),
          ),
          const SizedBox(width: 6),
          // Category tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: _categoryColor(entry.category).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              entry.category.tag,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _categoryColor(entry.category),
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Timestamp
          Text(
            _formatTimestamp(entry.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(width: 8),
          // Message
          Expanded(
            child: Text(
              entry.message,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTimestamp(DateTime ts) {
    return '${ts.hour.toString().padLeft(2, '0')}:'
        '${ts.minute.toString().padLeft(2, '0')}:'
        '${ts.second.toString().padLeft(2, '0')}.'
        '${ts.millisecond.toString().padLeft(3, '0')}';
  }

  static IconData _severityIcon(LogLevel level) {
    return switch (level) {
      LogLevel.debug => Icons.bug_report_outlined,
      LogLevel.info => Icons.info_outline,
      LogLevel.warning => Icons.warning_amber,
      LogLevel.error => Icons.error_outline,
    };
  }

  static Color _severityColor(LogLevel level, ColorScheme colorScheme) {
    return switch (level) {
      LogLevel.debug => colorScheme.onSurfaceVariant,
      LogLevel.info => Colors.blue,
      LogLevel.warning => Colors.orange,
      LogLevel.error => Colors.red,
    };
  }

  static Color _categoryColor(LogCategory category) {
    return switch (category) {
      LogCategory.app => Colors.blueGrey,
      LogCategory.bluetooth => Colors.indigo,
      LogCategory.serial => Colors.teal,
      LogCategory.libdc => Colors.deepPurple,
      LogCategory.database => Colors.green,
    };
  }
}
