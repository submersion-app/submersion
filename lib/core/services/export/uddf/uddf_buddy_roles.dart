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

  /// Transient: the raw `<divemaster>` text, held until [settle] can weigh
  /// it against the exact roles. [settle] removes it.
  static const _leaderTextKey = '_leaderText';

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
  ) => _links(_resolve(text, buddies));

  /// Each leader named in [text], in order, with the declared person it
  /// resolves to. A null [ref] on a [declared] name is a repeat with no
  /// declared person of that name left to link.
  static List<({String name, String? ref, bool declared})> _resolve(
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
    final used = <String>{};
    final leaders = <({String name, String? ref, bool declared})>[];
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
      final name = parts.sublist(i, i + taken).join(', ');
      final ref = candidates?.where((r) => !used.contains(r)).firstOrNull;
      if (ref != null) used.add(ref);
      leaders.add((name: name, ref: ref, declared: candidates != null));
      i += taken;
    }
    return leaders;
  }

  static ({List<String> refs, List<String> unmatched}) _links(
    Iterable<({String name, String? ref, bool declared})> leaders,
  ) {
    final refs = <String>[];
    final unmatched = <String>[];
    for (final leader in leaders) {
      if (leader.ref case final ref?) {
        refs.add(ref);
      } else if (!leader.declared &&
          !unmatched.any((n) => _normalized(n) == _normalized(leader.name))) {
        unmatched.add(leader.name);
      }
    }
    return (refs: refs, unmatched: unmatched);
  }

  /// Holds the dive's `<divemaster>` [text] on [dive] for [settle], which
  /// turns it into dive guide links once the exact roles are known.
  static void recordLeaderText(Map<String, dynamic> dive, String text) =>
      dive[_leaderTextKey] = text;

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
  /// else leaves that person to the standard elements.
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
    if (usable.isNotEmpty) dive[roleRefsKey] = usable;
  }

  /// Settles [dive]'s role links once every source has been read.
  ///
  /// The recorded `<divemaster>` text becomes dive guide links, except
  /// for the names the exact roles already cover: Submersion writes that
  /// text from its leader rows, so each leader row with an exact role
  /// accounts for one name, matched by name ([buddies] gives each
  /// person's), since the text may have resolved a namesake instead. Then
  /// whoever holds a guide or exact role leaves the plain buddy links, as
  /// Submersion's export links every participant, leaders included.
  ///
  /// Nothing earlier removes a link, so no step has to undo another's.
  static void settle(
    Map<String, dynamic> dive,
    Map<String, Map<String, dynamic>> buddies,
  ) {
    final leaderText = dive.remove(_leaderTextKey);
    if (leaderText is String) {
      final covered = <String, int>{};
      for (final row in (dive[roleRefsKey] as List?) ?? const []) {
        if (row is! Map || !DiveRole.leaderIds.contains(row['roleId'])) {
          continue;
        }
        final name = buddies[row['buddyRef']]?['name'];
        if (name is String) {
          covered.update(_normalized(name), (n) => n + 1, ifAbsent: () => 1);
        }
      }
      final uncovered = <({String name, String? ref, bool declared})>[];
      for (final leader in _resolve(leaderText, buddies)) {
        final key = _normalized(leader.name);
        final left = covered[key] ?? 0;
        if (left > 0) {
          covered[key] = left - 1;
        } else {
          uncovered.add(leader);
        }
      }
      final links = _links(uncovered);
      if (links.refs.isNotEmpty) dive[_guideRefsKey] = links.refs;
      if (links.unmatched.isNotEmpty) dive[_guideNamesKey] = links.unmatched;
    }

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
