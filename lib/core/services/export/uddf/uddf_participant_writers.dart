import 'package:xml/xml.dart';

import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';

/// Participant elements shared by the full backup and the dives-only
/// export, so the two paths write people the same way.
///
/// A participant is one `dive_buddies` row: a person and their role on the
/// dive. Leaders ([DiveRole.leaderIds]) go into the `<divemaster>` text,
/// every other role except solo is written inline as a plain `<buddy>`,
/// and every row is linked to its `<buddy id>` declaration. The exact role
/// rides in the private `<buddyroles>` block that
/// `UddfExportBuilders.buildApplicationData` writes.
abstract final class UddfParticipantWriters {
  /// The rows whose role leads the dive, in row order.
  static List<BuddyWithRole> leaders(List<BuddyWithRole> rows) => [
    for (final row in rows)
      if (DiveRole.leaderIds.contains(row.role.id)) row,
  ];

  /// The rows written inline as plain buddies: neither a leader nor solo.
  static List<BuddyWithRole> plainBuddies(List<BuddyWithRole> rows) => [
    for (final row in rows)
      if (!DiveRole.leaderIds.contains(row.role.id) &&
          row.role.id != DiveRole.soloId)
        row,
  ];

  /// One `<buddy id="buddy_<id>">` per person in [people].
  ///
  /// [trimmed] leaves out email, phone and notes, for a file meant to be
  /// shared with other people rather than restored by its owner.
  static void writeBuddyDeclarations(
    XmlBuilder builder,
    Iterable<Buddy> people, {
    bool trimmed = false,
  }) {
    for (final buddy in people) {
      builder.element(
        'buddy',
        attributes: {'id': 'buddy_${buddy.id}'},
        nest: () {
          builder.element(
            'personal',
            nest: () {
              _writeName(builder, buddy.name);
              if (!trimmed && buddy.email != null && buddy.email!.isNotEmpty) {
                builder.element('email', nest: buddy.email);
              }
              if (!trimmed && buddy.phone != null && buddy.phone!.isNotEmpty) {
                builder.element('phone', nest: buddy.phone);
              }
            },
          );
          if (buddy.certificationLevel != null ||
              buddy.certificationAgency != null) {
            builder.element(
              'certification',
              nest: () {
                if (buddy.certificationLevel != null) {
                  builder.element(
                    'level',
                    nest: buddy.certificationLevel!.name,
                  );
                }
                if (buddy.certificationAgency != null) {
                  builder.element(
                    'agency',
                    nest: buddy.certificationAgency!.name,
                  );
                }
              },
            );
          }
          if (!trimmed && buddy.notes.isNotEmpty) {
            builder.element('notes', nest: buddy.notes);
          }
        },
      );
    }
  }

  /// The dive's `<divemaster>`: its leaders' names joined with ", ", or the
  /// legacy free-text field when no leader is linked.
  static void writeLeaders(
    XmlBuilder builder,
    Dive dive,
    List<BuddyWithRole> rows,
  ) {
    final leading = leaders(rows);
    if (leading.isNotEmpty) {
      builder.element(
        'divemaster',
        nest: leading.map((row) => row.buddy.name).join(', '),
      );
    } else if (dive.diveMaster != null && dive.diveMaster!.isNotEmpty) {
      builder.element('divemaster', nest: dive.diveMaster);
    }
  }

  /// One `<link ref="buddy_<id>">` per row, leaders and solo included, so
  /// every participant resolves to its declaration on import.
  static void writeLinks(XmlBuilder builder, List<BuddyWithRole> rows) {
    for (final row in rows) {
      builder.element('link', attributes: {'ref': 'buddy_${row.buddy.id}'});
    }
  }

  /// An inline `<buddy><personal>` per plain buddy, for readers that do not
  /// follow links, or the legacy free-text field when there is none.
  static void writeInlineBuddies(
    XmlBuilder builder,
    Dive dive,
    List<BuddyWithRole> rows,
  ) {
    final plain = plainBuddies(rows);
    if (plain.isNotEmpty) {
      for (final row in plain) {
        builder.element(
          'buddy',
          nest: () {
            builder.element(
              'personal',
              nest: () => _writeName(builder, row.buddy.name),
            );
          },
        );
      }
    } else if (dive.buddy != null && dive.buddy!.isNotEmpty) {
      builder.element(
        'buddy',
        nest: () {
          builder.element(
            'personal',
            nest: () {
              builder.element('firstname', nest: dive.buddy);
            },
          );
        },
      );
    }
  }

  static void _writeName(XmlBuilder builder, String name) {
    final parts = name.split(' ');
    builder.element('firstname', nest: parts.first);
    if (parts.length > 1) {
      builder.element('lastname', nest: parts.sublist(1).join(' '));
    }
  }
}
