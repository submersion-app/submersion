import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/connections/domain/entities/node_ref.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Overflow-menu value shared by every detail page.
const kOpenInConnectionsAction = 'connections';

/// The "Open in Connections" menu row. The label sits in an Expanded so a
/// long translation wraps instead of overflowing the menu.
PopupMenuItem<String> openInConnectionsMenuItem(BuildContext context) {
  return PopupMenuItem<String>(
    value: kOpenInConnectionsAction,
    child: Row(
      children: [
        const Icon(Icons.hub_outlined),
        const SizedBox(width: 8),
        Expanded(
          child: Text(context.l10n.connections_action_openInConnections),
        ),
      ],
    ),
  );
}

/// Opens the Connections page centred on [ref], on top of the current page.
void openInConnections(BuildContext context, NodeRef ref) =>
    context.push(connectionsAroundLocation(ref));
