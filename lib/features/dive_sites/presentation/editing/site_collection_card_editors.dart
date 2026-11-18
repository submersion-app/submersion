import 'package:flutter/material.dart';

import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/editing/site_classification_sitting.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/tags/presentation/widgets/tag_form_block.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// The Tags card's editor: the tag input the form uses, limited to site
/// tags (issue #4527, phase 2).
///
/// A tag the diver creates here exists at once and outlives a cancelled
/// sitting; only which tags the site carries is held until Save.
class SiteTagsCardEditor extends StatefulWidget {
  const SiteTagsCardEditor({super.key, required this.session});

  final EditSession<DiveSite> session;

  @override
  State<SiteTagsCardEditor> createState() => _SiteTagsCardEditorState();
}

class _SiteTagsCardEditorState extends State<SiteTagsCardEditor> {
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(SiteTagsCardEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) _load();
  }

  void _load() {
    siteTagsList.load(widget.session).then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => TagFormBlock(
        label: context.l10n.diveSites_edit_typeTags_tagsLabel,
        selectedTags: siteTagsList.current(session) ?? const <Tag>[],
        onTagsChanged: (tags) => siteTagsList.set(session, tags),
        scope: TagScope.sites,
      ),
    );
  }
}
