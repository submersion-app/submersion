import 'package:xml/xml.dart';

import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Per-dive buddy roles in UDDF (issue #1737).
///
/// Standard UDDF has one leader field, `<divemaster>`, which holds names,
/// and links every other participant as a plain buddy. Import resolves
/// those names back to people and links them as dive guides. Submersion's
/// own export also writes each person's exact role on each dive to the
/// private `<buddyroles>` block, which import applies on top.
///
/// The dive map keys this produces are consumed by
/// `UddfEntityImporter._linkBuddiesToDive`.
abstract final class UddfBuddyRoles {
  /// Dive map key holding exact roles: a list of
  /// `{'buddyRef': <buddy uddf id>, 'roleId': <dive role id>}`.
  static const roleRefsKey = 'buddyRoleRefs';

  static const _buddyRefsKey = 'buddyRefs';
  static const _guideRefsKey = 'diveGuideRefs';
  static const _guideNamesKey = 'unmatchedDiveGuideNames';

  /// Splits the comma-joined names of a `<divemaster>` element and
  /// resolves each against the people the document declares ([buddies],
  /// keyed by `<buddy id>`), case-insensitively.
  ///
  /// The export joins names with ", " and a name may itself contain a
  /// comma ("Lee, Ann"), so the longest run of fragments naming a declared
  /// person wins. A name repeated in [text] reaches the next declared
  /// person of that name. Names matching nobody are returned once each in
  /// [unmatched].
  static ({List<String> refs, List<String> unmatched}) resolveLeaderNames(
    String text,
    Map<String, Map<String, dynamic>> buddies,
  ) {
    final refsByName = <String, List<String>>{};
    for (final entry in buddies.entries) {
      final name = entry.value['name'];
      if (name is String && name.trim().isNotEmpty) {
        refsByName.putIfAbsent(_normalized(name), () => []).add(entry.key);
      }
    }

    final parts = _fragments(text);
    final refs = <String>[];
    final unmatched = <String>[];
    var i = 0;
    while (i < parts.length) {
      var taken = 1;
      List<String>? candidates;
      for (var end = parts.length; end > i; end--) {
        candidates = refsByName[parts.sublist(i, end).join(', ').toLowerCase()];
        if (candidates != null) {
          taken = end - i;
          break;
        }
      }
      if (candidates == null) {
        final name = parts[i];
        if (!unmatched.any((n) => n.toLowerCase() == name.toLowerCase())) {
          unmatched.add(name);
        }
      } else {
        // Every declared person of this name already taken means the text
        // repeats a leader; there is no one new to link.
        final next = candidates.where((r) => !refs.contains(r)).firstOrNull;
        if (next != null) refs.add(next);
      }
      i += taken;
    }
    return (refs: refs, unmatched: unmatched);
  }

  /// Records the dive's `<divemaster>` [text] on [dive] as dive guide
  /// links: refs to declared people, and names to find or create.
  static void applyLeaderNames(
    Map<String, dynamic> dive,
    String text,
    Map<String, Map<String, dynamic>> buddies,
  ) {
    final leaders = resolveLeaderNames(text, buddies);
    if (leaders.refs.isNotEmpty) dive[_guideRefsKey] = leaders.refs;
    if (leaders.unmatched.isNotEmpty) dive[_guideNamesKey] = leaders.unmatched;
  }

  /// The private `<buddyroles>` block: per dive ref, each person's role.
  static Map<String, List<Map<String, String>>> parse(XmlElement block) => {
    for (final dive in block.findElements('dive'))
      if (dive.getAttribute('ref') case final ref? when ref.isNotEmpty)
        ref: [
          for (final row in dive.findElements('buddy'))
            if ((row.getAttribute('ref'), row.getAttribute('role')) case (
              final buddy?,
              final role?,
            ) when buddy.isNotEmpty && role.isNotEmpty)
              {'buddyRef': buddy, 'roleId': role},
        ],
  };

  /// Records one dive's exact roles ([rows] from [parse]) on [dive].
  ///
  /// A row is used only when its person is declared ([declaredBuddies])
  /// and its role is built in or declared ([declaredRoleIds]); anything
  /// else leaves that person to the standard elements. When a used row is
  /// a leader, the dive's `<divemaster>` text was written from these rows,
  /// so the guides inferred from it are dropped as superseded.
  static void applyExactRoles(
    Map<String, dynamic> dive,
    List<Map<String, String>> rows, {
    required Set<String> declaredBuddies,
    required Set<String> declaredRoleIds,
  }) {
    final usable = [
      for (final row in rows)
        if (declaredBuddies.contains(row['buddyRef']) &&
            (DiveRole.builtInIds.contains(row['roleId']) ||
                declaredRoleIds.contains(row['roleId'])))
          row,
    ];
    if (usable.isEmpty) return;
    dive[roleRefsKey] = usable;
    if (usable.any((row) => DiveRole.leaderIds.contains(row['roleId']))) {
      dive
        ..remove(_guideRefsKey)
        ..remove(_guideNamesKey);
    }
  }

  /// Leaves each person in [dive] holding one role: whoever is linked as
  /// a guide or with an exact role is taken out of the plain buddy links
  /// (Submersion's export links every participant, leaders included).
  ///
  /// Runs once every other step has recorded its links, so no step has to
  /// undo another's removal.
  static void settle(Map<String, dynamic> dive) {
    final buddyRefs = dive[_buddyRefsKey];
    if (buddyRefs is! List) return;
    final elsewhere = <Object?>{
      ...?(dive[_guideRefsKey] as List?),
      for (final row in (dive[roleRefsKey] as List?) ?? const [])
        if (row is Map) row['buddyRef'],
    };
    if (elsewhere.isEmpty) return;
    final kept = <String>[
      for (final ref in buddyRefs)
        if (ref is String && !elsewhere.contains(ref)) ref,
    ];
    if (kept.isEmpty) {
      dive.remove(_buddyRefsKey);
    } else {
      dive[_buddyRefsKey] = kept;
    }
  }

  static List<String> _fragments(String text) => [
    for (final part in text.split(','))
      if (part.trim().isNotEmpty) part.trim(),
  ];

  static String _normalized(String name) =>
      _fragments(name).join(', ').toLowerCase();
}
