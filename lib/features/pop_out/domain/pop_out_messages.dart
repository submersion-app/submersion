import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter/services.dart';

import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';

/// What the main window and its profile pop-out tell each other (#5078).
///
/// Each message travels as one method call on the window channel. Arguments
/// are plain maps of strings, numbers, booleans and lists, the only values a
/// call between two engines can carry.
sealed class PopOutMessage extends Equatable {
  const PopOutMessage();

  String get method;
  Map<String, Object?> get arguments;

  MethodCall toCall() => MethodCall(method, arguments);

  /// The message [call] carries, or null for an unknown method or arguments
  /// of the wrong shape.
  static PopOutMessage? fromCall(MethodCall call) {
    final args = call.arguments;
    final map = args is Map ? args : const <Object?, Object?>{};
    final hasMap = args is Map || args == null;
    if (!hasMap) return null;
    switch (call.method) {
      case ShowDiveMessage.name:
        final id = map['diveId'];
        if (id != null && id is! String) return null;
        return ShowDiveMessage(id as String?);
      case CursorMessage.name:
        final id = map['diveId'];
        final seconds = map['seconds'];
        if (id is! String || (seconds != null && seconds is! int)) return null;
        return CursorMessage(id, seconds as int?);
      case PrefsMessage.name:
        final values = map['values'];
        if (values is! Map) return null;
        return PrefsMessage(_prefValues(values));
      case LockMessage.name:
        final locked = map['locked'];
        if (locked is! bool) return null;
        return LockMessage(locked);
      case FocusRequestMessage.name:
        return const FocusRequestMessage();
      case CloseMessage.name:
        return const CloseMessage();
      case FocusReportMessage.name:
        final focused = map['focused'];
        if (focused is! bool) return null;
        return FocusReportMessage(focused);
      case FrameMessage.name:
        final frame = PopOutFrame.fromMap(map['frame']);
        if (frame == null) return null;
        return FrameMessage(frame);
      case ClosedMessage.name:
        return const ClosedMessage();
    }
    return null;
  }
}

/// Main to pop-out: the dive the main window shows (null for none yet).
final class ShowDiveMessage extends PopOutMessage {
  static const name = 'showDive';
  final String? diveId;
  const ShowDiveMessage(this.diveId);
  @override
  String get method => name;
  @override
  Map<String, Object?> get arguments => {'diveId': diveId};
  @override
  List<Object?> get props => [diveId];
}

/// Either way: the profile cursor for [diveId], in dive seconds, or null
/// when it was cleared.
final class CursorMessage extends PopOutMessage {
  static const name = 'cursor';
  final String diveId;
  final int? seconds;
  const CursorMessage(this.diveId, this.seconds);
  @override
  String get method => name;
  @override
  Map<String, Object?> get arguments => {'diveId': diveId, 'seconds': seconds};
  @override
  List<Object?> get props => [diveId, seconds];
}

/// Main to pop-out: every SharedPreferences value, so the pop-out's
/// in-memory copy matches the main window's (active diver, display zoom,
/// device-local settings).
final class PrefsMessage extends PopOutMessage {
  static const name = 'prefs';
  final Map<String, Object> values;
  const PrefsMessage(this.values);
  @override
  String get method => name;
  @override
  Map<String, Object?> get arguments => {'values': values};
  @override
  List<Object?> get props => [values];
}

/// Main to pop-out: whether App Lock has locked the app.
final class LockMessage extends PopOutMessage {
  static const name = 'lock';
  final bool locked;
  const LockMessage(this.locked);
  @override
  String get method => name;
  @override
  Map<String, Object?> get arguments => {'locked': locked};
  @override
  List<Object?> get props => [locked];
}

/// Main to pop-out: come to the front.
final class FocusRequestMessage extends PopOutMessage {
  static const name = 'focusWindow';
  const FocusRequestMessage();
  @override
  String get method => name;
  @override
  Map<String, Object?> get arguments => const {};
  @override
  List<Object?> get props => const [];
}

/// Main to pop-out: close now.
final class CloseMessage extends PopOutMessage {
  static const name = 'close';
  const CloseMessage();
  @override
  String get method => name;
  @override
  Map<String, Object?> get arguments => const {};
  @override
  List<Object?> get props => const [];
}

/// Pop-out to main: the pop-out window gained or lost focus.
final class FocusReportMessage extends PopOutMessage {
  static const name = 'focusChanged';
  final bool focused;
  const FocusReportMessage(this.focused);
  @override
  String get method => name;
  @override
  Map<String, Object?> get arguments => {'focused': focused};
  @override
  List<Object?> get props => [focused];
}

/// Pop-out to main: where the pop-out window now is, to remember.
final class FrameMessage extends PopOutMessage {
  static const name = 'frame';
  final PopOutFrame frame;
  const FrameMessage(this.frame);
  @override
  String get method => name;
  @override
  Map<String, Object?> get arguments => {'frame': frame.toMap()};
  @override
  List<Object?> get props => [frame];
}

/// Pop-out to main: the pop-out window is closing.
final class ClosedMessage extends PopOutMessage {
  static const name = 'closed';
  const ClosedMessage();
  @override
  String get method => name;
  @override
  Map<String, Object?> get arguments => const {};
  @override
  List<Object?> get props => const [];
}

/// Keeps the values SharedPreferences can hold, with string lists typed.
Map<String, Object> _prefValues(Map<Object?, Object?> raw) {
  final values = <String, Object>{};
  raw.forEach((key, value) {
    if (key is! String) return;
    if (value is String || value is bool || value is int || value is double) {
      values[key] = value!;
    } else if (value is List && value.every((e) => e is String)) {
      values[key] = List<String>.from(value);
    }
  });
  return values;
}

/// What a pop-out window is opened with: everything it needs before the
/// first message arrives (#5078). Carried as the new engine's arguments.
class PopOutLaunch extends Equatable {
  static const _kind = 'profile';

  /// The window channel this pop-out and the main window talk on. A new
  /// name for each opening: the window plugin pairs two engines per name and
  /// may still hold a closed pop-out's half.
  final String channel;

  final String? diveId;
  final Map<String, Object> prefs;
  final bool locked;
  final PopOutFrame? savedFrame;
  final PopOutFrame mainFrame;

  const PopOutLaunch({
    required this.channel,
    required this.diveId,
    required this.prefs,
    required this.locked,
    required this.savedFrame,
    required this.mainFrame,
  });

  String encode() => jsonEncode({
    'kind': _kind,
    'channel': channel,
    'diveId': diveId,
    'prefs': prefs,
    'locked': locked,
    'savedFrame': savedFrame?.toMap(),
    'mainFrame': mainFrame.toMap(),
  });

  /// The launch [arguments] describe, or null when they describe none (the
  /// main window's engine has empty arguments) or another kind of window.
  static PopOutLaunch? decode(String arguments) {
    if (arguments.isEmpty) return null;
    final Object? json;
    try {
      json = jsonDecode(arguments);
    } on FormatException {
      return null;
    }
    if (json is! Map || json['kind'] != _kind) return null;
    final channel = json['channel'];
    final diveId = json['diveId'];
    final prefs = json['prefs'];
    final locked = json['locked'];
    final mainFrame = PopOutFrame.fromMap(json['mainFrame']);
    if (channel is! String ||
        channel.isEmpty ||
        (diveId != null && diveId is! String) ||
        prefs is! Map ||
        locked is! bool ||
        mainFrame == null) {
      return null;
    }
    return PopOutLaunch(
      channel: channel,
      diveId: diveId as String?,
      prefs: _prefValues(prefs),
      locked: locked,
      savedFrame: PopOutFrame.fromMap(json['savedFrame']),
      mainFrame: mainFrame,
    );
  }

  @override
  List<Object?> get props => [
    channel,
    diveId,
    prefs,
    locked,
    savedFrame,
    mainFrame,
  ];
}
