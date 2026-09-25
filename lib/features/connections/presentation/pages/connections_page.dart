import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class ConnectionsPage extends StatelessWidget {
  const ConnectionsPage({
    super.key,
    this.lensId,
    this.kindAName,
    this.kindBName,
    this.focusWire,
  });

  final String? lensId;
  final String? kindAName;
  final String? kindBName;
  final String? focusWire;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.connections_title)),
      body: const SizedBox.shrink(),
    );
  }
}
