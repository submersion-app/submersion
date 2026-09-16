import 'package:flutter/material.dart';

import 'package:submersion/features/buddies/domain/entities/legacy_buddy_conversion.dart';
import 'package:submersion/features/buddies/domain/services/legacy_name_parser.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver pick one of [candidates]; null when dismissed.
Future<MatchCandidate?> showBuddyCandidatePicker(
  BuildContext context, {
  required List<MatchCandidate> candidates,
}) => showModalBottomSheet<MatchCandidate>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => BuddyCandidatePickerSheet(candidates: candidates),
);

class BuddyCandidatePickerSheet extends StatefulWidget {
  const BuddyCandidatePickerSheet({super.key, required this.candidates});

  final List<MatchCandidate> candidates;

  @override
  State<BuddyCandidatePickerSheet> createState() =>
      _BuddyCandidatePickerSheetState();
}

class _BuddyCandidatePickerSheetState extends State<BuddyCandidatePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final key = legacyNameKey(_query);
    final sorted = [...widget.candidates]
      ..sort((a, b) => legacyNameKey(a.name).compareTo(legacyNameKey(b.name)));
    final shown = [
      for (final c in sorted)
        if (key.isEmpty || legacyNameKey(c.name).contains(key)) c,
    ];
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: l10n.buddies_linkText_searchHint,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l10n.buddies_linkText_noBuddiesFound),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: shown.length,
                  itemBuilder: (context, i) => ListTile(
                    title: Text(shown[i].name),
                    subtitle: Text(
                      l10n.buddies_label_diveCount(shown[i].diveCount),
                    ),
                    onTap: () => Navigator.of(context).pop(shown[i]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
