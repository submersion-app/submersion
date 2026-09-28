import 'package:flutter/material.dart';
import 'package:submersion/core/icons/mdi_icons.dart';
import 'package:submersion/features/connections/domain/entities/connection_kind.dart';

/// The glyph for a kind, matching its home destination where it has one.
IconData connectionKindIcon(ConnectionKind kind) => switch (kind) {
  ConnectionKind.buddy => Icons.people,
  ConnectionKind.site => Icons.location_on,
  ConnectionKind.trip => Icons.flight,
  ConnectionKind.diveCenter => Icons.store,
  ConnectionKind.equipment => Icons.backpack,
  ConnectionKind.species => MdiIcons.fish,
  ConnectionKind.course => Icons.school,
  ConnectionKind.tag => Icons.label,
  ConnectionKind.diveType => Icons.category,
  ConnectionKind.diveComputer => Icons.watch,
};
