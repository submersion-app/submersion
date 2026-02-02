import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Notification settings for service reminders
class NotificationSettings extends Equatable {
  final bool enabled;
  final List<int> reminderDays; // Days before due date to remind
  final TimeOfDay reminderTime; // Time of day to send reminders

  const NotificationSettings({
    this.enabled = true,
    this.reminderDays = const [7, 14, 30],
    this.reminderTime = const TimeOfDay(hour: 9, minute: 0),
  });

  /// Parse reminder days from JSON string
  static List<int> parseReminderDays(String json) {
    try {
      final List<dynamic> parsed = List<dynamic>.from(
        json.isNotEmpty ? _parseJsonArray(json) : [],
      );
      return parsed.cast<int>();
    } catch (_) {
      return const [7, 14, 30];
    }
  }

  static List<dynamic> _parseJsonArray(String json) {
    // Simple JSON array parser for "[7, 14, 30]" format
    final trimmed = json.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) {
      return [];
    }
    final inner = trimmed.substring(1, trimmed.length - 1);
    if (inner.isEmpty) return [];
    return inner.split(',').map((s) => int.parse(s.trim())).toList();
  }

  /// Parse reminder time from "HH:mm" format
  static TimeOfDay parseReminderTime(String time) {
    try {
      final parts = time.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  /// Convert to JSON string for storage
  String get reminderDaysJson => '[${reminderDays.join(', ')}]';

  /// Convert time to "HH:mm" format
  String get reminderTimeString =>
      '${reminderTime.hour.toString().padLeft(2, '0')}:${reminderTime.minute.toString().padLeft(2, '0')}';

  NotificationSettings copyWith({
    bool? enabled,
    List<int>? reminderDays,
    TimeOfDay? reminderTime,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      reminderDays: reminderDays ?? this.reminderDays,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }

  @override
  List<Object?> get props => [enabled, reminderDays, reminderTime];
}
