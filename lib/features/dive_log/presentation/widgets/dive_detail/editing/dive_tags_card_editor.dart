import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Tags card's editor: the same tag input the dive form uses.
///
/// A tag the diver creates here exists at once and outlives a cancelled
/// sitting; only which tags the dive carries is held until Save.
class DiveTagsCardEditor extends StatelessWidget {
  const DiveTagsCardEditor({super.key, required this.session});

  final EditSession<Dive> session;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => TagFormBlock(
        label: context.l10n.diveLog_edit_section_tags,
        selectedTags: session.valueOf(diveTagsField),
        onTagsChanged: (tags) => session.set(diveTagsField, tags),
        scope: TagScope.dives,
      ),
    );
  }
}
