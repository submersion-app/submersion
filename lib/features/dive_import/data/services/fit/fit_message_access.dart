import 'package:fit_tool/fit_tool.dart';

/// Raw field access for FIT messages that fit_tool exposes only as a
/// [GenericMessage] (it has no named profile for them, so field values are
/// unscaled — callers apply scales from [FitConstants]).
class FitMessageAccess {
  const FitMessageAccess._();

  /// The unscaled numeric value of field [fieldId] on [message], or null if the
  /// field is absent or non-numeric.
  static num? rawNum(DataMessage message, int fieldId) {
    final value = message.getField(fieldId)?.getValue();
    return value is num ? value : null;
  }

  /// All data messages in [messages] whose FIT global message number equals
  /// [globalId] (e.g. 319 for tank_update, 323 for tank_summary).
  static List<DataMessage> messagesWithGlobalId(
    List<Message> messages,
    int globalId,
  ) {
    return messages
        .whereType<DataMessage>()
        .where((m) => m.globalId == globalId)
        .toList();
  }
}
