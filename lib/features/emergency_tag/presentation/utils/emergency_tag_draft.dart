import 'package:submersion/features/cylinder_passports/domain/services/ndef_fit.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_choices.dart';
import 'package:submersion/features/emergency_tag/domain/entities/emergency_tag_info.dart';
import 'package:submersion/features/emergency_tag/domain/services/emergency_tag_builder.dart';
import 'package:submersion/features/emergency_tag/domain/services/emergency_tag_codec.dart';

/// Everything the emergency tag page shows and writes for one diver under
/// one set of choices: the details, the first record, the text and its size.
class EmergencyTagDraft {
  EmergencyTagDraft._({
    required this.choices,
    required this.available,
    required this.callTargets,
    required this.info,
    required this.callUri,
    required this.labels,
    required this.languageCode,
  });

  /// [choices] resolved against what [diver] has recorded: a call target
  /// with no number moves to the first one with a number, and a call tag
  /// with no number at all falls back to the link.
  factory EmergencyTagDraft.of(
    Diver diver,
    EmergencyTagChoices choices, {
    required DateTime written,
    required EmergencyTagLabels labels,
    required String languageCode,
  }) {
    final targets = EmergencyTagBuilder.callTargets(diver);
    var resolved = choices;
    if (!targets.contains(resolved.callTarget) && targets.isNotEmpty) {
      resolved = resolved.copyWith(callTarget: targets.first);
    }
    if (resolved.primary == EmergencyTagPrimary.call && targets.isEmpty) {
      resolved = resolved.copyWith(primary: EmergencyTagPrimary.link);
    }
    return EmergencyTagDraft._(
      choices: resolved,
      available: EmergencyTagBuilder.availableFields(diver),
      callTargets: targets,
      info: EmergencyTagBuilder.build(diver, resolved, written: written),
      callUri: resolved.primary == EmergencyTagPrimary.call
          ? EmergencyTagBuilder.callUri(diver, resolved.callTarget)
          : null,
      labels: labels,
      languageCode: languageCode,
    );
  }

  final EmergencyTagChoices choices;

  /// The fields the diver has something recorded for.
  final Set<EmergencyTagField> available;

  /// The numbers a call tag can dial, in menu order.
  final List<EmergencyCallTarget> callTargets;

  final EmergencyTagInfo info;

  /// The `tel:` link a call tag starts with; null for a link tag.
  final String? callUri;

  /// Whether the tag carries the text record: the diver's choice on a link
  /// tag, always on a call tag, whose details live only in the text.
  bool get includeText => callUri != null || choices.includeText;

  final EmergencyTagLabels labels;
  final String languageCode;

  /// The first record's link with nothing left off.
  String get firstUri => callUri ?? EmergencyTagCodec.link(info);

  /// The tag's text with nothing left off.
  String get text => EmergencyTagCodec.text(info, labels);

  /// The message for a tag that takes [maxMessageBytes], fields dropped to
  /// fit; null when even the name does not fit.
  EmergencyTagNdefPlan? planFor(int maxMessageBytes) => EmergencyTagCodec.plan(
    info,
    labels: labels,
    languageCode: languageCode,
    firstRecordUri: callUri == null ? null : (_) => callUri!,
    includeText: includeText,
    maxMessageBytes: maxMessageBytes,
  );

  /// Bytes the whole message takes in a tag's memory.
  int get tagBytes => EmergencyTagCodec.tagBytes(planFor(1 << 20)!.message);

  /// The smallest common tag model that holds the whole message, or null
  /// when none of them does.
  String? get smallestTag => switch (tagBytes) {
    <= NdefFit.ntag213Bytes => 'NTAG213',
    <= NdefFit.ntag215Bytes => 'NTAG215',
    <= NdefFit.ntag216Bytes => 'NTAG216',
    _ => null,
  };
}
